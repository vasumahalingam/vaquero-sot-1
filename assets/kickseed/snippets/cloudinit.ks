{{ define  "cloudinit.ks" }}

%post --log=/root/cloudinit.log

# Disable cloud-init from listening to network for metadata
echo "datasource_list: [ NoCloud, None ]"  >> /etc/cloud/cloud.cfg


cat << EOF  > /etc/cloud/cloud.cfg.d/10-ssh-keys.cfg
#cloud-config

#SSH keys

{{ if index .env.metadata "ssh_authorized_keys" }}
ssh_authorized_keys:
  {{ range $element := .env.metadata.ssh_authorized_keys }}
  - {{ $element}}
  {{ end }}
{{ end }}

EOF



cat << EOF  > /etc/cloud/cloud.cfg.d/20-network-setting.cfg
#cloud-config

#Networking
network:
  version: 1
  config:
    {{- range $device := .host.metadata.network_config }}

    {{- if eq $device.type "team" }}
    - type: bond
    {{- else }}
    - type: {{ $device.type }}
    {{- end }}

      {{- if index $device "name" }}
      name: {{ $device.name }} 
      {{- end }}

      {{- if index $device "mtu" }}
      mtu: {{ $device.mtu }}
      {{- end }}

      {{- if index $device "mac_address" }}
      mac_address: {{ $device.mac_address }}
      {{- end }}

      {{- if index $device "bond_interfaces" }}
      bond_interfaces: 
      {{-  range $int := $device.bond_interfaces }}
        -  {{ $int }}
      {{-  end }}
      {{- end }}

      {{- if index $device "vlan_link" }}
      vlan_link: {{ $device.vlan_link }}
      {{- end }}

      {{- if index $device "vlan_id" }}
      vlan_id: {{ $device.vlan_id }}
      {{- end }}

      {{- if index $device "address" }}
      address: {{ $device.address }}
      {{- end }}

      {{- if index $device "search" }}
      search: {{ $device.search }}
      {{- end }}

      {{- if index $device "params" }} 
      params:
      {{-  range $k, $v := $device.params }}
        {{ $k }}:  {{ $v }}
      {{-  end }}
      {{-  end }}

      {{- if index $device "subnets" }} 
      subnets:
      {{- range $subnet := $device.subnets }} 
        - type: {{ $subnet.type }}
          {{ if index $subnet "address" }}address: {{ $subnet.address }} {{ end }} 
          {{ if index $subnet "netmask" }}netmask: {{ $subnet.netmask }} {{ end }} 
          {{ if index $subnet "gateway" }}gateway: {{ $subnet.gateway }} {{ end }} 
          {{ if index $subnet "dns_nameservers" }}dns_nameservers: {{ $subnet.dns_nameservers }} {{ end }} 
      {{- end }} 
      {{- end }} 

    {{- end }}
EOF

cat << EOF  > /etc/cloud/cloud.cfg.d/30-network-bond2team.cfg
#cloud-config

#Networking
#convert bonds to teams
runcmd:
 {{- range $device := .host.metadata.network_config }}
 {{- if eq $device.type "team" }}
 - [ sh, -c, 'bond2team --master {{ $device.name }} --outputdir /etc/sysconfig/network-scripts ' ]
 {{- end }}
 {{- end }}
 - [ sh, -c, 'hostnamectl set-hostname {{ .host.metadata.name }} ' ]
 - [ sh, -c, 'systemctl restart network ' ]
 - [ sh, -c, 'mkdir /root/cloud.cfg.d && mv /etc/cloud/cloud.cfg.d/* /root/cloud.cfg.d ' ]

EOF

%end

{{ end }}
