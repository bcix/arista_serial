Name:           arista-serial
Version:        1.0.0
Release:        1
Summary:        USB serial terminal server helper for Arista EOS
License:        GPL-3.0-or-later
BuildArch:      noarch
Source0:        usbserial.sh
Source1:        LICENSE
Source2:        AristaSerialCli.py
Source3:        arista_serial_cli.yaml

%description
Shell utility for mapping USB serial adapters to stable EOS port numbers,
starting serial multiplexers, and connecting to serial console ports.

%prep

%build

%install
install -D -m 0755 %{SOURCE0} %{buildroot}/mnt/flash/usbserial.sh
install -D -m 0644 %{SOURCE1} %{buildroot}/usr/share/licenses/%{name}/LICENSE
install -D -m 0644 %{SOURCE2} %{buildroot}/usr/share/CliExtension/CliPlugin/AristaSerialCli.py
install -D -m 0644 %{SOURCE3} %{buildroot}/usr/share/CliExtension/arista-serial.yaml

%post
/usr/bin/FastCli -p 15 -c "$(/usr/bin/printf '%%s\n' \
    'enable' \
    'configure' \
    'no alias "serial ([^ ]+)"' \
    'no alias "setserial ([0-9]+) (baud|name) (.*)"' \
    'no alias "sh(ow?)? seri(al?)?"' \
    'end' \
    'write memory')"

%preun
if [ "$1" -eq 0 ]; then
    /usr/bin/FastCli -p 15 -c "$(/usr/bin/printf '%%s\n' \
        'enable' \
        'configure' \
        'no alias "serial ([^ ]+)"' \
        'no alias "setserial ([0-9]+) (baud|name) (.*)"' \
        'no alias "sh(ow?)? seri(al?)?"' \
        'end' \
        'write memory')"
fi

%files
%attr(0755,root,root) /mnt/flash/usbserial.sh
%attr(0644,root,root) /usr/share/CliExtension/CliPlugin/AristaSerialCli.py
%attr(0644,root,root) /usr/share/CliExtension/arista-serial.yaml
%license /usr/share/licenses/%{name}/LICENSE
