{{ define  "os.ks" }}

# Enable the firewall and open port 22 for SSH remote administration
firewall --enabled --port=22:tcp

# Set the timezone
{{ if index .env.metadata "time_zone" }}
timezone --utc {{ .env.metadata.time_zone }}
{{ else }}
timezone --utc UTC
{{ end }}

%post --log=/root/kickstart_os.log

{{ if index .host.metadata.os_config "sysctl" }}
cat <<EOF >/etc/sysctl.d/10-system.conf
{{ range $key, $value := .host.metadata.os_config.sysctl }}
{{ $key }}={{ $value }}
{{ end }}
EOF
{{ end }}

{{ if index .host.metadata.os_config "kernel" }}
{{ range $key, $value := .host.metadata.os_config.kernel }}
grubby --update-kernel=ALL --args={{ $key }}={{ $value }}
{{ end }}
{{ end }}

%end

{{ end }}
