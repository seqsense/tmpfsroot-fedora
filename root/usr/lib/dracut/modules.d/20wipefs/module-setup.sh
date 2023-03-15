#!/bin/bash

check() {
  return 0
}

depends() {
  echo fs-lib
}

install() {
  inst_binary /usr/sbin/mkfs.ext4
  inst_binary /usr/bin/chmod
  inst_hook pre-mount 20 "$moddir/wipefs.sh"
}
