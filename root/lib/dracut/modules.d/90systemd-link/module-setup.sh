#!/bin/bash

check() {
    return 0
}

install() {
  inst_binary /usr/bin/realpath
  inst_hook pre-pivot 90 "$moddir/systemd-link.sh"
}
