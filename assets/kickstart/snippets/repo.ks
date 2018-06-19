{{ define  "repo.ks" }}

{{- if index .host.metadata.os_config.repos }}
{{- range $repo := .host.metadata.os_config.repos }}
repo --name {{ $repo }} --install --baseurl={{ $repo.baseurl }}
{{- end }}
{{- end }}

repo --name thirdparty --baseurl={{ .env.metadata.thirdparty_url }}

{{ end }}
