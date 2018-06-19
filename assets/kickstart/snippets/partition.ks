{{ define  "partition.ks" }}

# Wipe all partitions and build them with the info below
zerombr
{{ if index .host.metadata.disk_config "devices" }}
clearpart --all  --initlabel  --drives={{ .host.metadata.disk_config.devices }}
{{ else }}
clearpart --all  --initlabel  --drives=sda
{{ end }}

# Create the bootloader in the MBR with drive sda being the drive to install it on
bootloader --location=mbr --boot-drive=sda

# Regular partitions
{{ if index .host.metadata.disk_config "partitions" }}
  {{ range $partition := .host.metadata.disk_config.partitions }}
  part {{ $partition.name }} --asprimary  ''
  {{- if index $partition "disk" -}}
   --ondisk={{ $partition.disk }}
  {{- else -}}
   --ondisk=sda
  {{- end -}}
  {{- if index $partition "type" -}}
''  --fstype={{ $partition.type }}
  {{- end -}}
  {{- if index $partition "size" -}} 
''  --size={{ printf "%.0f" $partition.size }}
  {{- end -}}
  {{ end }}
{{ end }}

#LVM partitions
{{ if index .host.metadata.disk_config "lvm" }}
{{ if index .host.metadata.disk_config.lvm "vg" }}
  {{ range $vg := .host.metadata.disk_config.lvm.vg }}
  volgroup {{ $vg.name }}  {{ $vg.pv }}
  {{ end }}
{{ end }}
{{ if index .host.metadata.disk_config.lvm "lv" }}
  {{ range $lv := .host.metadata.disk_config.lvm.lv }}
  logvol {{ $lv.mount }}  --vgname={{ $lv.vg }} --fstype={{ $lv.fstype }} --size={{ printf "%.0f" $lv.size }}  --name={{ $lv.name }}
  {{ end }}
{{ end }}
{{ end }}

{{ end }}
