#!/bin/bash

check() {
  return 0
}

depends() {
  echo fs-lib
}

install() {
  inst_script "$moddir/tmpfsroot-generator.sh" $systemdutildir/system-generators/tmpfsroot-generator
}
