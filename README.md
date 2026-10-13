# arista_serial
Implementation of serial terminal server on Arista EOS based switches

## EOS extension package

The repository includes a build recipe for an EOS SWIX extension. It installs
`usbserial.sh` to `/mnt/flash/usbserial.sh`, preserving the paths used by the
commands below.

The builder needs Docker and network access to download its Linux build tools.
From the repository root, run:

```
packaging/build-docker.sh
```

The extension is written to `dist/arista-serial-1.0.0.swix`. The SWIX manifest
targets EOS 4.x. Copy it to the switch and install it with the EOS CLI:

```text
copy scp:<user>@<host>:<path>/arista-serial-1.0.0.swix vrf MGMT extension:
extension arista-serial-1.0.0.swix
```

To install it automatically at boot, add the SWIX to the boot-extension list:

```text
configure
boot extension arista-serial-1.0.0.swix
end
write memory
```

Check `show extensions` to confirm installation. The package installs an EOS
CLI extension with `serial <port>`, `setserial <port> baud <rate>`,
`setserial <port> name <name>`, and `show serial`. Port completion lists
numeric IDs 1–32 while `serial` also accepts configured names. Baud completion
offers 9600, 19200, 38400, 57600, and 115200. The package removes aliases left
by earlier package versions. The SWIX manifest restarts ConfigAgent so
the commands load; if installed with `delay-restart-agents`, run
`extension restart-agents` later. Initialize the script's udev and systemd
configuration after installation and after each reboot with the `start`
command shown below. To run initialization on every boot, add the event
handler described below.

The script can also be called directly:

```
bash /mnt/flash/usbserial.sh list
bash /mnt/flash/usbserial.sh connect 1
```

The script expects `socat`, `ncat`, `udevadm`, systemd, and the `ftdi_sio`
kernel module to be available on the switch.

## Manual installation from source

If installing the script without the extension package, upload it to the
device's `/mnt/flash` folder and make it executable:

```
bash
chmod +x /mnt/flash/usbserial.sh
```

The script needs to initialize a few things (after each reboot of the device).
You can do this manually:

```
bash sudo /mnt/flash/usbserial.sh start
```

You may also add an on-boot trigger:

```
configure
event-handler usbserial_init
   trigger on-boot
   action bash sudo /mnt/flash/usbserial.sh start
```

## Connecting to a serial port

First of all, you'll need to connect a USB-serial adapter to your Arista
device. You may use USB hubs. Without restarting everything, you should
add additional USB hubs only on the last port.

Afterwards you can connect (with multiple sessions) to the serial port
by using:

```
bash /mnt/flash/usbserial.sh connect <port>
```

You will need to replace `<port>` with a number between 1 and 32 (or a
device name, see below).

To exit your session, you may press the escape sequence ^] ("Ctrl" + "]").

## Port aliases / device names

Remembering which device is connected to which port may be challenging,
so it may be sensible to use an alias (e.g. device name) instead.

You can define those aliases by using:

```
bash sudo /mnt/flash/usbserial.sh setname <port> <name>
```

Afterwards you can alternatively use the device name instead of the port
number to connect to the serial port.

## Setting baud rates

The default settings for serial ports is 9600 baud with 8 data bits,
no parity and 1 stop bit (aka 8N1).

This can be changed by using a configuration file `/mnt/flash/usbserial.conf`.
This file may contain lines like `PORT_<port>=<setting>` or
`PORT_DEFAULT=<settings>`. You may use any kind of parameter supported by
`socat`.

To simplify operations, one can set the baud rate for a port by using:

```
bash sudo /mnt/flash/usbserial.sh setbaud <port> <baud rate>
```

This will restart the respective port (thus `sudo` is required).

## Listing all serial ports

After configuring your serial ports, you may be interested in the current
state of affairs. This can be done like this:

```
bash /mnt/flash/usbserial.sh list
```

## Aliases

The extension installs these aliases automatically. For a manual script
installation, add the `serial`, `setserial`, and `show serial` shortcuts to the
EOS CLI by entering these statements in configuration mode:

```
alias "serial ([^ ]+)"
   10 bash /mnt/flash/usbserial.sh connect %1

alias "setserial ([0-9]+) (baud|name) (.*)"
   10 bash sudo /mnt/flash/usbserial.sh set%2 %1 %3

alias "sh(ow?)? seri(al?)?"
   10 bash /mnt/flash/usbserial.sh list
```

Note: to enter ? characters in the CLI, you need to press Ctrl-V before.

## FAQ

### Why so much code for mapping ports?

First of all: We wanted stable linear port IDs. USB is a device tree. Our
first version was really simple -- it worked until we connected a 16-port
USB-C hub. This hub actually consists of 5x 4-port hubs, in a rather weird
topology.

### Why Bash and not Python?

While Python is native to Arista EOS, we saw little advantage, because we
have to interact with sysfs, systemd and processes. Bash offered
everything we needed.

### Why does input look multiplied if I connect with multiple terminals?

Many serial terminal servers only allow one user/terminal to connect to
each serial port. If you want to see what others see, you usually need
some external multiplexing (e.g. screen sharing).

We wanted to avoid any locking issues and implemented all active session
multiplexing.  This also allows the terminals to run as non-root users.

If you connect to one serial port from multiple terminals, you can see the
output in all terminals. Unfortunately this means you see the input of
others twice. So far we haven't found an easy way around that.
