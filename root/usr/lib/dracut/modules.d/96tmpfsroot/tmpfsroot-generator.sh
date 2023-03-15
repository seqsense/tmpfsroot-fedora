#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

[ -z "$root" ] && root=$(getarg root=)

getarg tmpfsroot.size= || exit 0
size=$(getarg tmpfsroot.size=)

GENERATOR_DIR="$2"
[ -z "$GENERATOR_DIR" ] && exit 1
[ -d "$GENERATOR_DIR" ] || mkdir "$GENERATOR_DIR"

rootdev="/dev/disk/by-uuid/${root#UUID=}"

cat <<EOS >"$GENERATOR_DIR"/sysroot.mount
[Unit]
Wants=setup-sysroot.service

[Mount]
Where=/sysroot
What=tmpfs
Options=mode=0755,size=$size
Type=tmpfs
EOS

cat <<EOS >"$GENERATOR_DIR"/sysrootro.mount
[Unit]
DefaultDependencies=no

[Mount]
Where=/sysrootro
What=$rootdev
Options=ro,noload
Type=ext4
EOS

cat <<EOS >"$GENERATOR_DIR"/setup-sysroot.service
[Unit]
DefaultDependencies=no
Before=initrd-root-fs.target
After=sysroot.mount

[Service]
ExecStart=/bin/systemctl start sysrootro.mount
ExecStart=/bin/sh -c 'cd /sysrootro; /bin/cp -r -a \$(ls -1 | grep -v "^boot$") /sysroot/'
ExecStart=/bin/sed -i -e "s|^.* / .*$|# \\\\0|g" /sysroot/etc/fstab
ExecStart=/bin/sh -c 'echo "${root#UUID=}" > /sysroot/etc/rootfs-id'
ExecStart=/bin/systemctl stop sysrootro.mount
ExecStop=/bin/true
Type=oneshot
RemainAfterExit=yes
EOS
