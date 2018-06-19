{{ define  "package.ks" }}

repo --name thirdparty  --install  --baseurl={{ .env.metadata.thirdparty_url }}

{{ if index .host.metadata.os_config "repos" }}
{{ range $repo, $value := .host.metadata.os_config.repos }}
repo --name {{ $repo }} --install --baseurl={{ $value.baseurl }}
{{ end }}
{{ end }}


# Install the Base and Core software packages, plus OpenSSH server & client
# This is the bare minimum for a system to run (with remote access via SSH)
%packages
@ Core
@ Base
openssh-clients
openssh-server
curl
grubby
cloud-init
bridge-utils

{{ if index .host.metadata.os_config "packages" }}
  {{ range $pkg := .host.metadata.os_config.packages }}
{{ $pkg }}
  {{ end }}
{{ end }}

%end

{{ end }}
