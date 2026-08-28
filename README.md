# arista_serial
Implementation of serial terminal server on Arista EOS based switches

## Installation

The script shall be uploaded to the device's `/mnt/flash` folder. You will
need to make it executable by using:

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

To simplify operations, you may wish to have some EOS CLI aliases.

We are using the following set of aliases:

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
