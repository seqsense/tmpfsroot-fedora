#!/bin/bash

(
  dnf repoquery \
    --arch=x86_64 --arch=noarch \
    --nvr --latest-limit=1 \
    $(cat packages.list)
  dnf repoquery \
    --arch=x86_64 --arch=noarch \
    --nvr --resolve --requires --recursive \
    $(cat packages.list)
) \
  | sort \
  | uniq \
  | sed '/langpack-/{/langpack-en/!d};/all-langpacks/d' \
  | sed '/^fedora-release-/{/^fedora-release-\(common\|identity-basic\|[0-9]\{1,\}\)/!d}' | tee rpms.lock
