{{ define  "raid_disk.ks" }}

%pre --erroronfail

function run_cmd_with_retries {
    local cmd=$1
    local retries=$2
    local delay=$3
    for i in $(seq $retries); do
        eval $cmd && break
        local rc=$?
        echo "Running... $cmd" > /dev/tty
        echo "Attempt #$i return code: $rc" > /dev/tty
        if [[ $i -lt $retries ]]; then
            echo "Sleeping $delay seconds before trying again" > /dev/tty
            sleep $delay
        else
            echo "Max attempts reached, exiting" > /dev/tty
            exit $rc
        fi
    done
}

function wipe_file_system {
    local file_system=$1

    wipefs -af ${file_system}
    # zero out 4M at the beginning and the end
    local bs=$((4 * 1024 * 1024))
    local sz=$(blockdev --getsize64 ${file_system})
    if [[ ${bs} -gt ${sz} ]]; then
        dd if=/dev/zero of=${file_system} bs=${sz} count=1 oflag=direct
    else
        dd if=/dev/zero of=${file_system} bs=${bs} count=1 oflag=direct
        dd if=/dev/zero of=${file_system} bs=${bs} count=1 seek=$((${sz} / ${bs} - 1)) oflag=direct
    fi
    if ! echo ${file_system} | grep -E "part[0-9]+$"; then
        # reread partition table after wipe
        run_cmd_with_retries "blockdev --rereadpt ${disk}" 5 2
    fi
}

# Common drive functions
function determine_drive_type_to_use {
    local num_drive_to_use=$1
    local hdd_count=$2
    local ssd_count=$3

    if [[ $num_drive_to_use -eq 0 ]]; then
        if [[ $ssd_count -gt 0 && $ssd_count -ge $hdd_count ]]; then
            echo "SSD"
        elif [[ $hdd_count -gt 0 ]]; then
            echo "HDD"
        else
            echo "Not enough disks found" > /dev/tty
            sleep infinity
        fi
    elif [[ $ssd_count -ge $num_drive_to_use ]]; then
        echo "SSD"
    elif [[ $hdd_count -ge $num_drive_to_use ]]; then
        echo "HDD"
    else
        echo "Not enough disks found" > /dev/tty
        sleep infinity
    fi
}

# Common MegaRAID controller card functions
function check_megaraid_controller {
    if lsmod 2> /dev/null | grep -Eqw "^megaraid_sas"; then
        local raid_controller=$(/opt/MegaRAID/storcli/storcli64 show ctrlcount 2> /dev/null | sed -nre '/Controller Count\s+=\s+[0-9]+/ s/.*([0-9]+)/\1/p')
        if [[ $raid_controller -ge 1 ]]; then
            echo "true"
        fi
    fi
}

function delete_megaraid_virtual_drive {
    local num_raid10=$(/opt/MegaRAID/storcli/storcli64 /c0 /vall show | grep " RAID10 " | wc -l)
    for idx in $(/opt/MegaRAID/storcli/storcli64 /c0 /vall show | awk '/RAID[0-9]+/ {print $1}' | awk -F '/' '{print $NF}'); do
        /opt/MegaRAID/storcli/storcli64 /c0 flush
        run_cmd_with_retries "/opt/MegaRAID/storcli/storcli64 /c0 /v${idx} del force" 5 2
        udevadm trigger --verbose --type=devices --subsystem-match=scsi_disk && udevadm settle
    done
    # NOTE: For some reason, replacing RAID10 with RAID1 causes virtual drive
    #       to going into "Server Fault" state after installation reboot.
    #       Workaround by performing extra reboot whenever RAID10 is remove.
    if [[ $num_raid10 -gt 0 ]]; then
        reboot
    fi
}

function toggle_megaraid_jbod {
    # $1 is either "on" or "off"
    local status=$1
    # $2 is either "SSD", "HDD", or slot # greater than 0
    local prefer_device=$2

    if [[ $status != "on" && $status != "off" ]]; then
        echo "Invalid JBOD mode specified: $status" > /dev/tty
        sleep infinity
    fi
    if [[ $status == "on" && ! $prefer_device -gt 0 && $prefer_device != "SSD" && $prefer_device != "HDD" ]]; then
        echo "Invalid prefer boot drive type or slot # specified: $prefer_device" > /dev/tty
        sleep infinity
    fi

    /opt/MegaRAID/storcli/storcli64 /c0 flush
    if [[ $(/opt/MegaRAID/storcli/storcli64 /c0 show jbod | awk '/^JBOD/ {print tolower($2)}') != ${status} ]]; then
        /opt/MegaRAID/storcli/storcli64 /c0 set jbod=$status force
    fi
    if [[ $status == "on" ]]; then
        local first_drive="true"
        local search_order="HDD SSD"
        if [[ $prefer_device == "SSD" ]]; then
            local search_order="SSD HDD"
        fi
        for pattern in ${search_order}; do
            for disk in $(/opt/MegaRAID/storcli/storcli64 /c0 /eall /sall show | awk "/${pattern}/ {print \$2,\$1}" | sort -n | awk '{print $2}'); do
                local enclosure=$(echo $disk | awk -F ':' '{print $1}')
                local slot=$(echo $disk | awk -F ':' '{print $2}')
                /opt/MegaRAID/storcli/storcli64 /c0 /e${enclosure} /s${slot} set jbod
                if [[ $first_drive == "true" ]]; then
                    /opt/MegaRAID/storcli/storcli64 /c0 /e${enclosure} /s${slot} set bootdrive=on
                    first_drive="false"
                fi
            done
        done
    fi
    if [[ $prefer_device -gt 0 ]]; then
        /opt/MegaRAID/storcli/storcli64 /c0 /e${enclosure} /s${prefer_device} set bootdrive=on
    fi
    udevadm trigger --verbose --type=devices --subsystem-match=scsi_disk && udevadm settle
}


function create_megaraid_virtual_drive {
    local vd_name=$1
    local drive_type_to_use=$2
    local raid_type_to_use=$3
    local num_drive_to_use=$4
    local num_spare_to_use=$5
    local total_drive_to_use=$((num_drive_to_use+num_spare_to_use))

    if [[ $drive_type_to_use == "" ]]; then
        local hdd_count=$(/opt/MegaRAID/storcli/storcli64 /c0 /eall /sall show | grep UGood | awk '/ HDD / {print $1}' | wc -l)
        local ssd_count=$(/opt/MegaRAID/storcli/storcli64 /c0 /eall /sall show | grep UGood | awk '/ SSD / {print $1}' | wc -l)
    fi
    local raid_disks=($(/opt/MegaRAID/storcli/storcli64 /c0 /eall /sall show | grep UGood | awk "/ ${drive_type_to_use} / {print \$1}"))
    if [[ $num_drive_to_use -gt 0 ]]; then
        # Use rear drives if exist else default to lowest slot number
        if [[ $num_drive_to_use -eq 2 && \
                $(/opt/MegaRAID/storcli/storcli64 /c0 /eall /sall show | grep -E "^[0-9]+:2[56]+ .* ${drive_type_to_use} " | wc -l) -eq 2 ]]; then
            raid_disks=(${raid_disks[@]:(-$num_drive_to_use):$num_drive_to_use})
        elif [[ $num_drive_to_use -le ${#raid_disks[@]} ]]; then
            raid_disks=(${raid_disks[@]:0:$num_drive_to_use})
        else
            echo "Not enough disks found" > /dev/tty
            sleep infinity
        fi
    fi
    /opt/MegaRAID/storcli/storcli64 /c0 flush
    # Create drives list and spares list
    local drives=$(IFS=,; echo "${raid_disks[*]:0:$num_drive_to_use}")
    local spares=$(IFS=,; echo "${raid_disks[*]:$num_drive_to_use:$num_spare_to_use}")
    # Create virtual device
    local raid_cmd="/opt/MegaRAID/storcli/storcli64 /c0 add vd ${raid_type_to_use} name=${vd_name} drives=$drives"
    if [[ -n $spares ]]; then
        ${raid_cmd}+=" spares=$spares"
    fi
    echo "Creating Virtual Drive "  $raid_cmd > /dev/tty
    run_cmd_with_retries "${raid_cmd}" 5 2
    /opt/MegaRAID/storcli/storcli64 /c0/${vd_name} start init force
    # Wait until init finishes
    local max_tries=15
    for i in $(seq ${max_tries}); do
        sleep 2
        if /opt/MegaRAID/storcli/storcli64 /c0/${vd_name} show init | grep "Not in progress"; then
            break
        fi
        if [[ ${i} -eq ${max_tries} ]]; then
            echo "Timeout waiting for hardware RAID virtual drive ${vd_name} to finish initialize" > /dev/tty
            sleep infinity
        fi
    done
    udevadm trigger --verbose --type=devices --subsystem-match=scsi_disk && udevadm settle
}


function clear_megaraid_foreign_config {
    if ! /opt/MegaRAID/storcli/storcli64 /c0 /fall show | grep "Couldn't find any foreign Configuration"; then
        /opt/MegaRAID/storcli/storcli64 /c0 /fall delete
    fi
}



# Start
wget -P /run/install/repo/Packages {{ .env.metadata.thirdparty_url }}/{{  .env.metadata.storcli_rpm }}
if [[ -f /run/install/repo/Packages/{{ .env.metadata.storcli_rpm }} ]]; then
    rpm -Uvh --nodeps --replacepkgs /run/install/repo/Packages/{{ .env.metadata.storcli_rpm }}
    echo enable > /tmp/hw_raid
fi

# make sure drives are discovered
run_cmd_with_retries "udevadm trigger && udevadm settle" 5 15

# output for debugging purpose
ls -l /dev/disk/by-path/*

# remove existing volume groups and their logical volumes
for vg in $(vgdisplay | grep "VG Name" | awk '{print $3}') ; do
    vgremove --force ${vg}
done

# remove existing physical volume
for pv in $(pvdisplay | grep "PV Name" | awk '{print $3}') ; do
    pvremove --force ${pv}
done

# Stop all software RAID arrays with retries in case of error
for md in $(ls /dev | grep -e 'md[0-9]\+$'); do
    run_cmd_with_retries "mdadm --stop /dev/${md}" 5 15
done


# Prepare drives for hardware or software RAID
for disk in $(ls /dev/disk/by-id/wwn* | sort -r); do
    wipe_file_system ${disk}
done

install_disks=()
# If MegaRAID controller exist
if [[ $(check_megaraid_controller) == "true" ]]; then
    clear_megaraid_foreign_config
    delete_megaraid_virtual_drive
    toggle_megaraid_jbod "off" "HDD"
    toggle_megaraid_jbod "off" "SSD"

    #create the VDs defined by user
    {{ if index .host.metadata.disk_config "virtual_disks" }}
      {{ range $vd := .host.metadata.disk_config.virtual_disks }}
          create_megaraid_virtual_drive {{ $vd.name }} {{ $vd.type }} {{ $vd.raid }}  {{ $vd.num_disk }} {{ $vd.num_spare }}
      {{ end }}
    #create default mirror for OS
    {{ else }}
          create_megaraid_virtual_drive v0 "HDD" raid1 2 0
    {{ end }}

    echo "Setting boot drive: v0"  > /dev/tty 
    /opt/MegaRAID/storcli/storcli64 /c0 /v0 set bootdrive=on
    #echo "Setting remaining disks to JBOD"  > /dev/tty 
    /opt/MegaRAID/storcli/storcli64 /c0 set jbod=on
fi
%end

{{ end }}
