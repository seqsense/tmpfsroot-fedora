#!/bin/sh

mkdir -vp /sysroot/run
mount --bind /run /sysroot/run

fallback=false

if ! (mount | grep 'on /sysroot/opt ')
then
  echo "/opt is not mounted" >&2
  fallback=true
elif [ ! -x /sysroot/opt/sq-edge-host-agent/bin/sq-edge-host-agent ] \
  || [ ! -f /sysroot/opt/systemd/system/sq-edge-host-agent.service ] \
  || [ ! -L  /sysroot/opt/systemd/system/multi-user.target.wants/sq-edge-host-agent.service ]
then
  echo "sq-edge-host-agent is missing" >&2
  umount /sysroot/opt
  fallback=true
fi

if ${fallback}
then
  echo "Falling back to /fallback/opt" >&2
  mount -t tmpfs tmpfs /sysroot/opt -o size=64m
  cp -var /sysroot/fallback/opt/* /sysroot/opt/
fi

mkdir -vp /sysroot/opt/systemd/system /sysroot/opt/udev/rules.d
mkdir -vp /sysroot/run/systemd/system /sysroot/run/udev/rules.d
mount --bind /sysroot/opt/systemd/system /sysroot/run/systemd/system
mount --bind /sysroot/opt/udev/rules.d /sysroot/run/udev/rules.d
