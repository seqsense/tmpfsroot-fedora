#!/bin/bash

set -eu

required_list=/usr/share/tmpfsroot-fedora/required-services

if [ ! -f ${required_list} ]
then
  echo "${required_list} not found" >&2
  exit 1
fi

required_services="$(echo $(cat ${required_list}))"
echo "checking ${required_services}..."

while true
do
  need_wait=false
  for srv in ${required_services}
  do
    # Check uptime of the service
    . <(systemctl show ${srv} \
          --property=ExecMainStartTimestamp \
          --property=ActiveState \
        | sed 's/^\([^=]*\)=\(.*\)$/\1="\2"/')

    exec_timestamp=$(date --date="$(echo $ExecMainStartTimestamp | cut -d" " -f2-3)" +%s)
    now_timestamp=$(date +%s)
    active_duration=$(expr ${now_timestamp} - ${exec_timestamp})
    if [ "${ActiveState}" != "active" ] \
      || [ ${active_duration} -lt 30 ]
    then
      echo "${srv} is not continuously running" >&2
      need_wait=true
      break
    fi
  done

  if ${need_wait}
  then
    sleep 30
    continue
  fi

  break
done

dev_efi=$(blkid --match-token PARTLABEL="EFI System Partition" -o device)
mnt_efi=$(mktemp -d)

echo " EFI partition: ${dev_efi}"
test -b "${dev_efi}" # detected device must be block special

mount ${dev_efi} ${mnt_efi} -o ro
trap "umount ${dev_efi}" EXIT

. <(cat /etc/default/grub | grep GRUB_DISK_UUID)
. <(grub2-editenv ${mnt_efi}/EFI/fedora/grubenv list | grep saved_entry)
case ${saved_entry} in
  1)
    saved_num=1
    saved_id=${GRUB_DISK_UUID1}
    ;;
  0|*)
    saved_num=0
    saved_id=${GRUB_DISK_UUID0}
    ;;
esac

current_id=$(cat /etc/rootfs-id)

case ${current_id} in
  ${GRUB_DISK_UUID0})
    current_num=0
    ;;
  ${GRUB_DISK_UUID1})
    current_num=1
    ;;
  *)
    echo "Booted from unknown rootfs ${current_id}" >&2
    exit 1
    ;;
esac

echo "current rootfs: ${current_id} (${current_num})"
echo "  saved rootfs: ${saved_id} (${saved_num})"

if [ ${current_id} = ${saved_id} ]
then
  echo "Boot setting is up-to-date"
  exit 0
fi

echo "Setting boot rootfs to ${current_id} (${current_num})"
mount ${dev_efi} ${mnt_efi} -o rw,remount
grub2-editenv ${mnt_efi}/EFI/fedora/grubenv set saved_entry=${current_num}
grub2-editenv ${mnt_efi}/EFI/fedora/grubenv unset next_entry
grub2-editenv ${mnt_efi}/EFI/fedora/grubenv unset prev_saved_entry
