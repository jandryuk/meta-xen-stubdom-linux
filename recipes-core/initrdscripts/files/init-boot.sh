#!/bin/sh

set -e
set -x
mount -t devtmpfs none /dev
mount -t sysfs /sys /sys
mount -t proc /proc /proc
mount -t tmpfs -o size=1m,nodev,noexec /tmp /tmp
mount -o remount,ro /

echo 1 > /proc/sys/vm/overcommit_memory

if test -e /sys/class/net/eth0; then
    ip link set eth0 address fe:ff:ff:ff:ff:fe
    ip addr flush eth0
    ip link set eth0 up
    brctl addbr br0
    brctl addif br0 eth0
    ip link set br0 up
    client_ip=$(xenstore-read $(xenstore-read device/vif/0/backend)/ip)
    # use only the first address
    client_ip=${client_ip%% *}
    net_prefix="${client_ip%.*}"
    udhcpd -f -I $net_prefix.1 - <<EOC &
start $client_ip
end $client_ip
max_leases 1

interface br0

lease_file /dev/null

opt dns 10.138.1.1 10.139.1.2
opt subnet 255.255.255.0
opt router $net_prefix.1
EOC
else
    echo "No network interface named eth0."
    ls -l /sys/class/net/
fi

domid=$(/bin/xenstore-read "target")
vm_path=$(xenstore-read "/local/domain/$domid/vm")
dm_args=$(xenstore-read -R "$vm_path/image/dmargs")

mkdir /tmp/qmp
mkdir /tmp/qmp/req
mkdir /tmp/qmp/res

kernel=
if [ -b /dev/xvdd ]; then
    mkdir /tmp/boot
    mount /dev/xvdd /tmp/boot -o ro
    if [ -f /tmp/boot/vmlinuz ]; then
        kernel=$'-kernel\x1b/tmp/boot/vmlinuz'
        if [ -f /tmp/boot/initramfs ]; then
            kernel="$kernel"$'\x1b-initrd\x1b/tmp/boot/initramfs'
        fi
    fi
fi

mkfifo /tmp/qmp/qemu.in /tmp/qmp/qemu.out /tmp/qmp/qemu_res.out

(
set +x
cat /tmp/qmp/qemu.out | tee /tmp/qmp/qemu_res.out | \
while IFS= read -r line; do
    if [ $(echo "\\${line}" | grep -cim1 '"event": "DEVICE_DELETED", "data": {"device": "nic0",') -eq 1 ]; then
        /etc/qemu-ifdown
    fi
done
) &

(
set +x
if [ $(echo "$dm_args" | grep -cim1 "ifname=") -eq 1 ]; then
    VIFNAME=$(echo "$dm_args" | sed -n -e 's/^.*ifname=//p' | sed -n -e 's/,.*$//p')
    while true; do
        if [ $(ip link | grep -cim1 "$VIFNAME") -eq 1 ]; then
            break
        fi
        sleep 0.1
    done
    /etc/qemu-ifup "$VIFNAME"
fi
) &

(
set +x
# Clear kernel log buffer to avoid leaking kaslr layout information
# Messages are still written to xen console
echo "Clearing kmsg buffer..." > /dev/kmsg
while read -r line; do
    if [ $(echo "$line" | grep -cim1 "Clearing kmsg buffer...") -eq 1 ]; then
        break
    fi
done < /proc/kmsg
) &

# $dm_args and $kernel are separated with \x1b to allow for spaces in arguments.
IFS=$'\x1b'
set -f
qemu -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny \
-chardev pipe,path=/tmp/qmp/qemu,id=m -mon chardev=m,mode=control \
    $dm_args $kernel &
set +f
unset IFS

qemu_pid=$!

(
set +x
IFS= read -r line
echo "$line" >&2
echo '{"execute": "qmp_capabilities"}' | tee /proc/self/fd/2
IFS= read -r line
echo "$line" >&2
while true; do
    id=$(ls -t /tmp/qmp/req | head -n 1)
    if [ "$id" = "" ]; then
        inotifywait -e attrib,create,delete,modify,move /tmp/qmp/req 2>&1 | \
            while read -r watch_setup; do
                if [ "$watch_setup" = "Watches established." ]; then
                   if [ -n "$(ls -A /tmp/qmp/req)" ]; then
                       touch /tmp/qmp/req
                   fi
                fi
            done
        continue
    fi

    echo $id >&2
    cat /tmp/qmp/req/$id | tee /proc/self/fd/2
    rm /tmp/qmp/req/$id
    while IFS= read -r line; do
        echo "$line" >&2
        # we can't grep directly because we can't control grep's buffering
        if ! echo "$line" | grep -q '"event"\s*:'; then
            break
        fi
        sleep 0.5
    done
    echo "$line" > /tmp/qmp/new-res
    mv /tmp/qmp/new-res /tmp/qmp/res/$id
done
) >/tmp/qmp/qemu.in </tmp/qmp/qemu_res.out &

qmp_req() {
    local id=$(cat /proc/sys/kernel/random/uuid)
    echo "$1" > /tmp/qmp/new-req_$id
    mv /tmp/qmp/new-req_$id /tmp/qmp/req/$id
    while ! [ -f /tmp/qmp/res/$id ]; do sleep 0.1; done
    cat /tmp/qmp/res/$id
    rm /tmp/qmp/res/$id
}

(
target="$(xenstore-read target)"
device_model="device-model/$target"

while true; do
    xenstore-watch -n 2 "$device_model/command"
    cmd="$(xenstore-read $device_model/command)"
    if [ "$cmd" != "pci-ins" ] && [ "$cmd" != "pci-rem" ]; then
        continue
    fi

    para="$(xenstore-read "$device_model/parameter")"

    # backend pci device id like 0000:01:02.3
    dev="$(printf %s "$para" | cut -b 1-12)"

    qdev_id="xen-pci-pt_$(printf %s "$dev" | tr : -)"

    # handle pci remove request
    if [ "$cmd" = "pci-rem" ]; then
        qmp_req "$(cat <<EOC
{"execute": "device_del", "arguments": {"id": "$qdev_id"}}
EOC
        )" > /dev/null
        xenstore-write "$device_model/state" "pci-removed"
        continue
    fi

    # handle pci add request
    be="$(xenstore-read device/pci/0/backend)"
    devs="$(xenstore-read $be/num_devs)"

    dev_n=
    for i in $(seq 0 $(( devs - 1 ))); do
        if [ "$dev" = "$(xenstore-read "$be/dev-$i" | sed 's/\.0\([0-9]\)$/.\1/')" ]; then
            dev_n=$i
            break
        fi
    done

    if [ -z "$dev_n" ]; then
        echo "could not find backend entry for device $dev"
        exit 1
    fi

    vdev="$(xenstore-read "$be/vdev-$dev_n")"

    addr_arg=
    vdevfn="$(xenstore-read "$be/vdevfn-$dev_n" || true)"
    if [ -n "$vdevfn" ]; then
        addr_arg="\"addr\": \"$(( ($vdevfn >> 3) & 0x1f )).$(( $vdevfn & 0x07 ))\", "
    fi

    permissive=false
    if xenstore-read "$be/opts-$dev_n" | grep -q '\<permissive=1\>'; then
        permissive=true
    fi

    qmp_req "$(cat <<EOC
{"execute": "device_add", "arguments": {"driver": "xen-pci-passthrough", "id": "$qdev_id", "hostaddr": "$vdev", "machine_addr": "$dev",$addr_arg "permissive": $permissive}}
EOC
    )" > /dev/null

    # XXX: use jq?
    slot_func="$(qmp_req '{"execute": "query-pci"}' | sed 's/"qdev_id"/\n\0/g' | sed -n '/"qdev_id": "'"$qdev_id"'"/{s/.*"slot": \([0-9]\+\),.*"function": \([0-9]\+\),.*/\1,\2/;p}')"

    slot="$(printf %s "$slot_func" | cut -d , -f 1)"
    func="$(printf %s "$slot_func" | cut -d , -f 2)"

    vdevfn="$(( (($slot & 0x1f) << 3) | ($func & 0x07) ))"

    xenstore-write "$device_model/parameter" "$(printf '0x%02x' "$vdevfn")"
    xenstore-write "$device_model/state" "pci-inserted"
done
) &

while true; do
    printf '==== Press enter for shell ====\n'
    read
    setsid /bin/cttyhack /bin/sh
done
