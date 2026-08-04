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

You will need to replace `<port>` with a number between 1 and 32.

To simplify this, you may define a command alias:

```
configure
alias "serial (\w+)"
   20 bash /mnt/flash/usbserial.sh connect %1
```

To exit your session, you may press the escape sequence ^] ("Ctrl" + "]").

## Setting baud rates

The default settings for serial ports is 9600 baud with 8 data bits,
no parity and 1 stop bit (aka 8N1).

This can be changed by using a configuration file `/mnt/flash/usbserial.conf`.
This file may contain lines like `PORT_<port>=<setting>` or
`PORT_DEFAULT=<settings>`. You may use any kind of parameter supported by
`socat`.

To simplify operations, one can set the baud rate for a port by using:

```
bash /mnt/flash/usbserial.sh setbaud <port> <baud rate>
```

This will restart the respective port.
