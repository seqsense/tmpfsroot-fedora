#!/bin/sh

uuid=ff9691f9-7c97-4411-8f44-12685ee4a006
dev=/dev/sda3

if ! fsck.ext4 -n ${dev}; then
  mkfs.ext4 ${dev} -U ${uuid}

  mkdir -p /mnt/${uuid}
  mount ${dev} /mnt/${uuid}

  for dir in audit sssd; do
    mkdir -p /mnt/${uuid}/${dir}
    chmod 700 /mnt/${uuid}/${dir}
  done

  umount /mnt/${uuid}
  rm -rf /mnt/${uuid}
fi
