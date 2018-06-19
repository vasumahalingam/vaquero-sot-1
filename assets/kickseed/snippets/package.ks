{{ define  "package.ks" }}

{{ if index .host.metadata.os_config "repos" }}
{{ range $repo, $value := .host.metadata.os_config.repos }}
repo --name {{ $repo }} --install --baseurl={{ $value.baseurl }}
{{ end }}
{{ end }}

#repo --name thirdparty  --install  --baseurl={{ .env.metadata.thirdparty_url }}

# Install the Base and Core software packages, plus OpenSSH server & client
# This is the bare minimum for a system to run (with remote access via SSH)
%packages
@ ubuntu-server
openssh-server
ftp
build-essential
curl
cloud-init
bridge-utils

{{ if index .host.metadata.os_config "packages" }}
  {{ range $pkg := .host.metadata.os_config.packages }}
{{ $pkg }}
  {{ end }}
{{ end }}

%end

{{ end }}
