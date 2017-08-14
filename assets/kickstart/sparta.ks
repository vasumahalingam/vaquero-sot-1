#version=DEVEL
# System authorization information
auth --enableshadow --passalgo=sha512
# OSTree setup
ostreesetup --osname="rhel-atomic-host" --remote="rhel-atomic-host" --url="http://{{.env.agentURL}}/files/rhel-atomic-install/ostree" --ref="rhel-atomic-host/7/x86_64/standard" --nogpg
# Use text install
text
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use={{.host.metadata.disks.drive_list}}
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
{{range .host.metadata.ksnetworks}}
{{.}}
{{end}}
network --hostname={{.host.metadata.name}}

# Root password
rootpw --iscrypted $6$or5T4vd3vZnOYsOw$Hd5k4d02ilSs7aQygQShy/OmJLj.Axv64cymygqLUcjYfDBPNF7bd5OltuspQQCTXdm4FCC2V4XFRevK65fVP.
# System services
services --disabled="docker,flanneld,kubelet,kube-proxy,manifest-loader,cloud-init,cloud-config,cloud-final,cloud-init-local"
services --enabled="etcd,chronyd"
# System timezone
timezone America/New_York --isUtc
# System bootloader configuration
bootloader --append=" crashkernel=auto ds=nocloud\;" --location=mbr --boot-drive={{.host.metadata.disks.boot_drive}}

#partitioning
autopart --type=lvm

# Partition clearing information
clearpart --all --initlabel --drives={{.host.metadata.disks.drive_list}}

%post --erroronfail
set -exuo pipefail
fn=/etc/ostree/remotes.d/rhel-atomic-host.conf; if test -f ${fn} && grep -q -e '^url=file:///install/ostree' ${fn}$; then rm ${fn}; fi
%end

%post --erroronfail
set -exuo pipefail
rm -f /etc/ostree/remotes.d/*.conf
echo 'unconfigured-state=This system is not registered to Red Hat Subscription Management. You can use subscription-manager to register.' >> $(ostree admin --print-current-dir).origin
%end

%post --erroronfail
set -exuo pipefail

echo "growing the filesystem a bit"
lvextend -L+20G /dev/mapper/rhelah_{{.host.metadata.disks.vg_name}}-root
xfs_growfs /

mkdir -p /var/www/html
curl -fs "{{.env.agentURL}}/files/netboot.tar" -o /var/www/html/netboot.tar
tar xf /var/www/html/netboot.tar -C /var/www/html

echo "copying overlay..."
mkdir -p /root/overlay
cp -r /var/www/html/atomic-install-repo/overlay/* /

echo "updating selinux context labels"
chcon -Rt svirt_sandbox_file_t /var/www/html

# set up users
useradd -m -U admin -G wheel
mkdir -p /var/home/admin/.ssh
chmod 700 /var/home/admin/.ssh
touch /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCU+xQ4whqSubMTHFmGaUvdgiY9AyR+1QMAWdruR4OScM3o/EyL9+yGfbOr6vmItOKRg9xaGUra/Q6wYH4hRjJsZ3fZJNXUysOvBsIbbAhjOpuCVs/kCJ6E30j6P0C9CedsQbqifkwObAIUn8164u0n+fzA9YzWYmVcR3aGl8eQY6TdV3bxDgTjwsULNo0sxIbfdq+mIsLddT1yZIslMlwaDu546G2RJKRGSWmyzH/asCD3iHbAha80CmLK0/UtITu4celTGRoQdvUWcbopXpGFlQL8CQZ7R3Bc0ONSP7NJs5d7k5IGRtlejoc0W98BjOKxJqUxWlXcD9r6rz5zUthay1TXsR5L1ny7Lzua89B38dVofwB/cmgm+fh6XIuCgly9h6lvzqRTRSlALE1s4OZA0hAC+M7VOQO/bWEnAmZn7XjHx2h5G+t/7+eRTWpMZWcCy+wcDFpaND3G6isA2zGoCdrdxqwEaptWjYpOEKjwrviwvkiizmExqSPYbO7pnG3jSy1v5R5CHROvbDHL2T4x+afYMIl5JbJd3UuNAOiYyDZEAnw2zzrQRKi3hDAZY3tb57g9Tf2/uOJBMCisW3as81AA4Pi/qvEwlJLmdbMvvRaeMZu3TLB3QxE0kgmmZD8t94AcKRycF2MlI/EPHfHDVaZbSER6ilSwQHnCv/7tyw== bhouser@cisco.com" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCsbMdFjaz05izsDJrxIbCXpIlZre8LFW2f50oKSjrUmUfw+EM4jgbZ2G+h80Q3LclsnbRcTocl+qXqEQXQVUZkTg/vo2nliD0ff7GieYy6ejotvt4FETWUuto/FJ8r/MlI9iVH2curwXbqbXF3QK3rXxa9n68073erYQ3YN1/EOqKsVr54+K/Z7933nMzQ/AgFVSjc2bnvJv+6ZAaxtmDybfsLAHfL0koDadxq02eEeOI5XhJoN4+MNBnGBCry+JhJDwlgvdGUnTTck/3vntNP9/n7q+iP8KAXncc3lhVlFcQAHincF4mN2DnHQNGEGogDRTHNrxX8Ov756dFibOECWHTpPVxF2nfT9v/q0jvHUeah5VuexndbAPC5vR4UJr+ifv7rlglK4q/28yzBVMkn9JBpgdcJWV32nH8JMGslE7ziiDctTx1u310vCYPrCWudh+7o9G3C7YKrmrXG2HhqTNpVUjQiAY8u3+4UnriYoXu29GU04ZH/hcGjqeawaz1Lr3rd0ZoiM+3HORXAOc4+7fn5HmcpkleuQtWTM7N8oyTM18do46I8GI9Jg0mbWeWJiZugaTr2fBEyrxJnKBocxnKOiiww5LAXzp40kViNuHqZVFkgKefq7XxURbbaoQXEtXETQnuz25Rynf+UdRjfqAuzXfbLZtQNhx8KKEd3Tw== matdietz@cisco.com" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDjeOSxgs6LYlvCnSJJhX4iTXe5QY4YiSZ3H+kGi3HoN0uiIGPTynbFoLK2zR56aQ9xtGMFPN3+72g1NdybaXd0zy1/TtumBQ/f6fYH2gP4Ap3M/Pbet3Zu1eoXZZkaKX9IOZ7k+cK0SI40Wj7t3SpvDrji8Q+PkzqNuQGCYjxZw3FS1Ic3oU1nmFqM8Ub4fsOo8MXPvV4fgzDqWJvpNyoJTqJ2KIa+WEemIPx3Cckn23oR7ZsK0O5zodwv3FEWFXq6YFdvz2k2xmSuuJ4pMqzvNVjaAzfAT7+78hO50qW4UMbjjn+aPhQMCYKIWJLHAg0CbsbqgamfRR2yAE4HmY8U/xnk3MI4lK7VcLy9o4/FFkQaofPL1QOXu5Q7g0PPifl17yYB48ny/jeRbvN86R1RUyVYisfn+sKjXqI9M1Q6HTLbbzuO6uSn7xohOJJjFXDtz/0KztZCR30MJdNfxWODOoLcHaLGjDtOSz6RIgnvYSkJGUWjOyG6kSfguwPyoyBpa5l8JqLgsYQUzPn3/s9jApcmuy2veOyYWQh97wUKA8XFtSAP1Wyj20RFts5n0o5YCUC70YnqAzN/b1nYrYQ+GfQcVJ3Whx+MajokAiKfLhe0WTGirZP/3ICbVYD+S6ZCv8lqjcZXzw4alDOams62KYhdFmwZBWqL1LODBTDJjQ== abmusic@cisco.com" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJvY5Rrf56hQLeVACDDpxsXmdx4VNqXEGU+GumiDbLMeeu+gcNdVYnmiobGUDbC9hpPRnv8EqK0ab62mye4ssAmvoLh49NbLUvRnLFvqnW0YNM/fAtAqKa32qbKxGJeYyzz3lTMva+P36CyqCutIT8xOIUlig2k4pETmuHHC6LsndV6jECaLUuwgqIqTwIahAa6YQPIUOEKpFnYgg5n6zfwmHLmZNv/2veZzz0B+xN5DZZprn9eUnnVTZ83iPYFGgudLBF97frEdZ2Pyk92vOcdianG2gMeRTtx3iv2GqUPJWt4fqNSOB42hU5QXgh3vXbtVGI5jZtxQ4TXw2W0nnH jlothian@JLOTHIAN-M-9018" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7nUuDPYjjt8E4GIVYtGYLuJCriSauys4pZzWtJ8iBsBKoM9bHS47N9gPT4p6OLpfK8mZ/Y7UXUwW3C64JlO9F18GQbo+c/CiVhV5FYyQtSKikw/KzOWeGpQUwVFkBbz/0NwaBYi7AH3HiDzjdutWyQjE3VvpWyD/77lxBCHk4FZeXbsdNAsHt0l9H8PaQZ8lKiuDjg9Wy6kylvrdlbJu5o2VEqaWVc/gD5qBTdMpQnpOJmF5Agc2LOYlVu/DpnHO4vqEXRxsLZZxQ94Pk0cU9n+7LoReNo7tYVvB62DZ7OHOfXeEDa+QL58Nik2q2XS+ZCk3c++TIGX0MBuXb+7xb jmeridth@gmail.com" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDab151F2Y4motYX6M7FOoU2bZfoM0BZirIRwMJKborQq0nu1JIJabb2yIYW0LKkgb/omcNaJVMeGEFzU/M2MS+M9+Zil6+WOwLWHiCbPlH3fqK88ogvmrFX49eTOP6qcN2Xifbi6vaJ5rEk1JOnV0Vwgo0ZeIzF1QpzDPsA/dWuzkb+2IfDFpqRuUlJGfjQCNl7q9eqkMpJMsxpOLD6MXP1dS7pERFZbMYv7YWV15U9pNLhbausyS+mfcnsjc4Leh2Yp5c0Q2FfmDmkhAfSFDEGIcfVKzZHSKiidC/9PsX2XprICz+WYGP81UK6MSXred3iPhewTSQHO9T/Aea9XBxM5TbxGgRrmR0jbnT2E2ejQnWbsU6fdQhX6DrYK2pztyXHDi1jNDcUUodLLOkHZtG2vgmR7lWE348eDpO3Y595rKYzLiGQDtkRJRvwTmNKSkxboNh6tGUZmFjW9wNjKnln6nytHFvceMnWlzbpu4FnnTWtF02n01TP/BEiuwiR6+w7WKMtifdzgIxsB7cXtIFfaXh9Vau1vUJn6WRJRWR4CEd9x570zosw9uqN3vwBBWu5MfOp5eihR5/qu4UTQAkMUO8qifLi6hai4lWs1S8FCWjk3pWOBwjCk/kvdsN6Zu7IXL9n9dnqOVXNQ3f5CXxgXkejvUvHAIPXXMECURutw== mdegerne@cisco.com" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDSded/IzF+BjBI37f03iaGPqEbew2egdUYwl42dRH1PFdbrSsxGe1Q/i7suoImjdjwpsmS3OgADddgjCim8V8dqI+kvUt54gNf/Ew0LkocMdX7SLsGpRAgnaU+LNyAZ4qM4F5WBzSP7vkDyx5kLRft4+J2G3N0fUbadaTeJDPykotzUT6y5rC0I6i6wcIMlHepj+h1ZiYk7fdWitRd6YWVRdbvLlHBaOuy0qQib0x3ZEvYWEXSYUWzjV5L+KJj3HzCHc+g5Uk/W2kD++/6uDu74wbNJZ4ckAGg0dlYclfvp9PJBCqb/yLvSYhlcFC7IqZN0xxos2G+8hkfFeT1dAnfFxK8r+5s0OtCGAUTcV7FPdNyIzo2cnwigHp4TkDJj4x0veoBkMjapfN1NLe17mxnDcgq7oyKlcRXCmZgMOgtEluGuKa5+XMzKOjyxNDDptSR9Vm2oCqEvbNIfLm6DjZdfnHD/rKqCAZsfIiqev0/4FayO/H2xM7iMX04CVtaMA6uSBEWfA3fxdZpzI6vlF8cQ1NGze1Jrx5y7txKgUVYaOb/2rD4jMgsZ04uO/JxDUUV0mdkeNy69KG87OlyTa+0SZyl6TXq0YS1PY8tNkjsCEDVNxfFI7zYD2L5N7cyaltUtmXt1Vp7Du74DEK4SilzLM6Y+ODxVnp3GF17AA45+Q== nibartos@cisco.com" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC3EaZhCqCb81u5JEb6LDeQNGn8CZTDN7ix8KHigGXoLOYEhVnrq+EXJ5S1HgpYNHzgyhFYWFhH7Av+ODMOLsXdY8pdSWOLz6HSkQtN6k46pIFFHLM05sRwaiwbh/VglrX/vtnynMw5gHEo+WbNNyv4RJU4/L+aknmaHldiS8VN9aAvucAmPAdSwINLuQBWtvZOhtE2U0aoEFsGUWZGu9h4QSyTQiN/Emqg8FZsTwM4Dy683Jxwiwnpiuc5KR6BYux6OZyLflI965uX8Y5RhE7f9MVukSLmInTRkWP2T7gDKLMHFDpbv/RXVevCK/7QpctMv8ZUMR8cClMZjIHsV71zWjYm5mRwdnNik/SLkon6m0MukzJVGCZOpw0dL6oTyELVXQ+jDQx7xE5FBzMW28vzFtHaNAmVsRma/QirGQSH8OCT6nF/dhBF0DDvZEPNVFrUP4Iql4nwPXIJzZXu2MuMpSYaod4CGZYwiMytwW+7k8vX67JgQOZ8kwPirKCPBD+2T3arikaH9jznoFTL4MDi/Opknd6DhoT6IT1e6kfV6GZWmamDSEzcg2inv751fiupudOcNAi9B6elEOISfj5IYFmP3lUb24qzjvCu3ikwujJg1eSfdS0FPCpZu5HAjvkt8Qobqutdp8ne6FlNoH5au7bBAJcrdLk54NYrxM0Y9Q== cfattarsi@gmail.com" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDfhY8/HJiGiHrt1yb/YGWKoug1kpG5yBV3DJWolqQ++cS+KvJajt72d9/aBNjz9oPweBLa0ljRKjKETNB6KuOvaYzpryCRLoayHcBWZzSy1pApHg0zxU/abkXmyh/hsbDfgmkJxN4/0+mUTMMzGvAwKrCle/pVOMZzmI/V74uIZuE3EEmBZULO7Aj3T8sXUIf1dv2GWEvgO1orlAIMFkg8rt3tNV/xVm6FICcPcAjsVklkzltshj9d8BIa98p3PQuRIeO1jEO6YMAtsqhMAZIUwo6N4mSjW/qjmUtliOPQCw0gHc98jyQCUYszhQcRls/kEvPoHxKJ0qyEX6AEALxL forrest@Forrests-MacBook-Air.local" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD0RCNmNSHufSN488qu0uOlFyNRP7aYRDceHpZ/3o/smdn5ZUT5xwsoo910ep/3bsqiaqza/ele1BmGcutqRIXhir7cq2CC808j27OSdwnL+0m/YbzK8cLt5SOw7SeTfj+PSyqutFH+djZxqIaNpDB1Y3yLWxKhLUScYx7wfzuc0RxS7Qgxnua0UaTRXNyWIqnXzszPnW0Z0inPDnlTF67EedwUpIHHP43+6q6gy/mRpTRpS8js+XR8aJvREh82yikmV2KH2W6DpEYRObzatZXmY+PwQFctNIviMp0YxEXE3e7JI7fMLsU8WZfyrBuHCFM7aKVgt8rOJpY5BCvKQ4++YiD4gv6x4/SGn0OGOLbdqvwLlKIhXGH9alvSkxlvEk0YJFhBmomTt2GNm3JiWVuVL+TaGp0+flneJGK68/cakm8K58sccfrkJMgvDv5EfqGm4LqlkDrC7Jj6komtYyhM7QXO8y9jH+wlBq+Om6r1mXPbyYA7YdVFWyNfpCzD0ZOZpbLdnx8g5qx7mSAztZ/TYjX6HlFI7LZ3PsDJiW5DaescePV8fl+2WItWJJWD6atK86SkJn9TthrNhkQub2Cf/2fgcm7ml1kfmJRF9bRyFGJ1pB5FCV7O6oMrvf8lQ6OVcGyoCcLW/dbhAZOLzdkDD+02DnzHOvfauZf+iPhrvw== rabadin@cisco.com" >> /var/home/admin/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDLvD/MRhTwis2uKmTIje1gJzAvj1GQyh78tIp0T+Eq4vZmFvqaOU25/XBVctwHUAt8I/Y1C+DvaTCz0XdScMgpFmAzTMRCD/XZRzRouZVNizUIvrkP4D8UwuoU1D/iiFJ8+gkBwuT2e+gh3azpuKq8nQC+xKc5pPB2Z+hw9IIjOXyCZFiUx/TrwbqoT9vrVSLH0n7tgPhVjOvBP7EHAldD0zv0pzY21VJrNjOakBOcrLeIfKgbFfmugRo4lpqdImbNPgJOe/1NR/86fC1/CN+nwpKf1Mt6kxfGgRh4j+QIVN8FhIpLG5pc4p6qqPY+zC71SSvrrJuwI21crIbVp1w0ayRy216qnCoir3V7GClq96/pBNhO0DY0zybUobTz3KOY1g5VN8gGmGJOkfXL0J1XwwM4Xri0uACu8o8O+lWeYnqhHkGvKTWxV1S5jPkYZa88sSv8DtVKFb7yF/yAX6gcAVt3vRdCNrjZUuvKscySO3vFpwhdxmK+edMJuxHQXm/W6oobFHpT6EOqficpZD8Nu5RLFUlquDoFhEDEUbXACxwMFWQO6sG3EEOdZbzHqZ1jyRbbrPgj7M8Lhb7eFLnOK8910cfQKKVEc7SxGSkkWB+DEy9X6NOAEQ/la0iMRHnvQnNF2/FE69/Eb/KiLujgJ9jbl1296isGMCi8/5tqDw== rluckie@cisco.com" >> /var/home/admin/.ssh/authorized_keys
chmod 600 /var/home/admin/.ssh/authorized_keys
chown -R admin:admin /var/home/admin

# make sure our scripts are executable
chmod 755 /var/usrlocal/bin/*

# set up NFS mounts if required
echo "10.10.24.2:/vol_01022017_112922_60/lab1_harmony_demo/proxmox-abmusic /var/lib/sparta nfs vers=3,tcp  0 0" >> /etc/fstab

# let containers access NFS volumes
semanage boolean --modify --on virt_use_nfs

systemctl daemon-reload
systemctl enable sparta-init

# enable bootstrapper on baremetal + ISO installs
{{if eq .env.metadata.env_type "ucs"}}systemctl enable bootstrapper{{end}}

%end

%packages
chrony
kexec-tools

%end

# %addon com_redhat_kdump --enable --reserve-mb='auto'
# %end

# %anaconda
# pwpolicy root --minlen=6 --minquality=50 --notstrict --nochanges --notempty
# pwpolicy user --minlen=6 --minquality=50 --notstrict --nochanges --notempty
# pwpolicy luks --minlen=6 --minquality=50 --notstrict --nochanges --notempty
# %end

reboot --eject --kexec
