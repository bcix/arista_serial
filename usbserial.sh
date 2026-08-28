#!/bin/bash 
#
# This file is part of the arista_serial distribution (https://github.com/bcix/arista_serila).
# Copyright (c) 2026 BCIX Management GmbH, André Grüneberg
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# traverse the USB device tree upwards
function usbtree_up() {
        local SPATH="${1}"
        if [ -e "${SPATH}" -a -e "${SPATH}/product" ]; then
                # some device exists, let's check if it's a hub
                read maxchild < "${SPATH}/maxchild"
                if [ "${maxchild}" -gt 0 ]; then
                        # it's a hub, so traverse it upwards
                        base="${SPATH##*/}"
                        usbtree_left "${SPATH}/${base}.$(( maxchild + 1 ))" 0
                else
                        # it's a device
                        echo 1
                fi
        else
                # no device connected to hub port
                echo 1
        fi
}

# traverse the USB device tree to the left
function usbtree_left() {
        local SPBASE="${1%.*}"
        local ID="${1##*.}"
        local allow_down="${2:-1}"
        local num=0

        # going up to neighbors left from us
        for x in `seq 1 $(( ${ID} - 1 ))`; do
                (( num += $(usbtree_up "${SPBASE}.${x}") ))
        done

        # go down the tree to the left -- ensure we only do this once
        parent="${SPBASE%/*}"
        if [ "${allow_down}" = '1' -a -e "${parent}/product" ]; then
                (( num += $(usbtree_left "${parent}" ${allow_down}) ))
        fi
        echo "${num}"   
}

# get the USB port number based on the TTY device
function get_port() {   
        DEVPATH=$(udevadm info "${1}" | grep '^P: ' | sed 's/^P: //')
        USBDPATH="${DEVPATH%%/ttyUSB*}"

        # Get port ID, by traversing USB hub chain:
        # - assume hubs are connected to last port of their parent hub
        SPATH="/sys${USBDPATH%/*}"
        echo $(( $(usbtree_left "${SPATH}") + 1 ))
}

# Get the number of potential USB ports, max. 32
function max_ports() {
	port_count=0
	hub_count=0
	for infile in $(find /sys/bus/usb/devices/1-1/ -name maxchild); do
                read maxchild < "${infile}"
		test "${maxchild}" -gt "0" && (( hub_count++ ))
		(( port_count += "${maxchild}" ))
	done
	sum=$(( ${port_count} - ${hub_count} + 1 ))
	# we do not want to support >32 ports
	test "${sum}" -gt 32 && sum=32
	echo "${sum}"
}

# Called by udev upon hotplug event
function plugin_serial() {
        TTYDEV="/dev/$1"
        if [ ! -c "${TTYDEV}" ]; then
                echo "${TTYDEV} is not a valid character device" >&2
                exit 1  
        fi
        ID=$(get_port "${TTYDEV}")
        PORT=$(( 7000 + $ID ))
        PARAM_NAME="PORT_${ID}"
        PARAMS="${!PARAM_NAME}"
        [ -z "${PARAMS}" ] && PARAMS="${PORT_DEFAULT}"

	# ensure multiplexer is running
        systemctl start "serialMux@${PORT}.service"

	# use socat to connect TTY with multiplexer, replacing current script
        exec socat "${TTYDEV},${PARAMS},raw,echo=0" "TCP6:[::1]:${PORT}"
}

function restart_serial() {
        ID="${1:-0}"
        if [ "${ID}" -lt 1 -o "${ID}" -gt 32 ]; then
                echo "Invalid Port ID ${ID}" >&2
                exit 1  
        fi
        PORT=$(( 7000 + "$1" ))

	# find socat process that connects to multiplexer port
	SOCAT=$(pgrep -af "socat .*:${PORT}\$")
	if [ -z "${SOCAT}" ]; then
		echo "No running socat found for Port ID ${ID}" >&2
		exit 1
	fi

	# extract device name from process command line
	DEV="${SOCAT#* socat /dev/}"

	# restart the 
	sudo systemctl restart "ttyUSB-plugd@${DEV%%,*}.service"
}

function initialize() { 
        echo "Starting" 

        # ensure gpsd does not grab our ttyUSB devices
        rm /lib/udev/rules.d/99-gpsd.rules
        systemctl stop gpsd.socket
        systemctl stop gpsd.service
        systemctl mask gpsd.socket
        systemctl mask gpsd.service

        # create udev rule
        cat > /etc/udev/rules.d/99-bcix.rules <<_EOF_
ACTION=="add", SUBSYSTEM=="tty", ENV{SYSTEMD_WANTS}+="ttyUSB-plugd@%k.service", TAG+="systemd"
_EOF_
        cat > "/etc/systemd/system/ttyUSB-plugd@.service" <<_EOF_
[Unit]
Description=Serial handler for %i

[Service]
Type=simple
ExecStart=/mnt/flash/usbserial.sh plugin %i
_EOF_
        cat > "/etc/systemd/system/serialMux@.service" <<_EOF_
[Unit]
Description=Serial Mux Port %i

[Service]
Type=simple
ExecStart=/usr/bin/ncat -l --broker --keep-open ::1 %i
_EOF_
        systemctl daemon-reload
        udevadm control --reload-rules
        udevadm trigger 

        # load the FTDI module
        modprobe ftdi_sio
}

# Try to get the port id based on device name
function port_by_name() {
	Q="${1}"
	for i in `seq 1 $(max_ports)`; do
		PARAM_NAME="NAME_${i}"
		NAME="${!PARAM_NAME}"
		if [ "${NAME}" = "${Q}" ]; then
			echo "${i}"
			break
		fi
	done
}

# Connect to the multiplexer
function connect() {
        ID="${1:-0}"
	if [ "${ID}" != "${ID//[^0-9]/}" ]; then
		# contains not only numbers, try lookup by name
		NUM=$(port_by_name "${ID}")
		if [ -z "${NUM}" ]; then
			echo "Device named ${ID} not found"
			exit 1
		fi
		ID=$NUM
	elif [ "${ID}" -lt 1 -o "${ID}" -gt 32 ]; then
                echo "Invalid Port ID ${ID}" >&2
                exit 1
        fi
        PORT=$(( 7000 + $ID ))

	# connect to multiplexer port
	echo "Connecting to port ${ID} -- exit with ^]"
        socat "TCP:[::1]:${PORT}" -,raw,echo=0,escape=0x1d
	echo "" # start new line
}

# set baud rate of the port
function set_baud() {
        ID="${1:-0}"
	BAUD="${2}"

        if [ "${ID}" -lt 1 -o "${ID}" -gt 32 ]; then
                echo "Invalid Port ID ${ID}" >&2
                exit 1  
        fi

	# only few baud rates supported
	if [ "${BAUD}" != '9600' -a "${BAUD}" != '19200' -a "${BAUD}" != '38400' -a "${BAUD}" != '57600' -a "${BAUD}" != '115200' ]; then
		echo "Invalid baud rate ${BAUD}" >&2
		exit 1
	fi

	# get current setting
	PARAM_NAME="PORT_${ID}"
	PARAMS="${!PARAM_NAME}"
	[ -z "${PARAMS}" ] && PARAMS="${PORT_DEFAULT}"
	
	if [ "${PARAMS}" = "b${BAUD}" ]; then
		echo "Requested baud rate ${BAUD} already set"
		exit 0
	fi
	
	# remove previous entries and set new value
	test -f "${CFGFILE}" && sed -i "/^${PARAM_NAME}=/ d" "${CFGFILE}"
	echo "${PARAM_NAME}=b${BAUD}" >> "${CFGFILE}"

	# restart port
	restart_serial "${ID}"
}

# set device name for a port
function set_name() {
        ID="${1:-0}"
	NAME="${2}"

        if [ "${ID}" -lt 1 -o "${ID}" -gt 32 ]; then
                echo "Invalid Port ID ${ID}" >&2
                exit 1
        fi

	if [ "${NAME}" != "${NAME//[^0-9a-zA-Z_-]/+}" ]; then
		echo "Only letters, numbers, - and _ allowed in device names"
		exit 1
	fi

	# get current setting
	PARAM_NAME="NAME_${ID}"
	PARAMS="${!PARAM_NAME}"

	if [ "${PARAMS}" = "${NAME}" ]; then
		echo "Requested name ${NAME} already set"
		exit 0
	fi

	# remove previous entries and set new value
	test -f "${CFGFILE}" && sed -i "/^${PARAM_NAME}=/ d" "${CFGFILE}"
	echo "${PARAM_NAME}=${NAME}" >> "${CFGFILE}"
}

# show a list of ports
function list_ports() {
	echo -e 'Port\tActive\tBaudrate\tName'
	for i in `seq 1 $(max_ports)`; do
		PARAM_NAME="PORT_${i}"
		PARAMS="${!PARAM_NAME}"
		[ -z "${PARAMS}" ] && PARAMS="${PORT_DEFAULT}"
		NAME_NAME="NAME_${i}"
		NAME="${!NAME_NAME}"
		# if serial adapter is connected a socat process should exist
		PORT=$(( 7000 + "$i" ))
		SOCAT=$(pgrep -af "socat .*:${PORT}\$")
		test -n "${SOCAT}" && CONN='*' || CONN='-'

		printf "%3s\t%4s\t%8s\t%s\n" "${i}" "${CONN}" "${PARAMS}" "${NAME}"
	done
}

PORT_DEFAULT="b9600"
CFGFILE="${0%.sh}.conf" 
test -f "${CFGFILE}" && source "${CFGFILE}"

CMD="${1}"
shift 1
case "${CMD}" in
	start)
		initialize
		;;
	setbaud)
		set_baud "$@"
		;;
	setname)
		set_name "$@"
		;;
	restart)
		restart_serial "$@"
		;;
	plugin)
		plugin_serial "$@"
		;;
	connect)
		connect "$@"
		;;
	list)
		list_ports
		;;
	*)
		echo "Invalid command: ${CMD}" >&2
		echo "Usage: $0 start|connect|restart|setbaud|setname|list"
		echo "  start                     - initialize script, to be run once as root"
		echo "  connect <port|name>       - connect to the serial console, exit with ^]"
		echo "  restart <port>            - re-initialize connection"
		echo "  setbaud <port> <baudrate> - set the baud rate for a specific port"
		echo "  setname <port> <name>     - provide a name for a specific port"
		echo "  list                      - list serial ports"

		exit 1
		;;
esac
