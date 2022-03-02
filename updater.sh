#!/bin/bash

repos="
  --repofrompath releases-tmp,${FEDORA_MIRROR}/releases/${FEDORA_MAJOR}/Everything/x86_64/os
  --repofrompath updates-tmp,${FEDORA_MIRROR}/updates/${FEDORA_MAJOR}/Everything/x86_64
  --repo releases-tmp
  --repo updates-tmp
  --repo docker-ce-stable
"

(
  dnf repoquery \
    ${repos} \
    --arch=x86_64 --arch=noarch \
    --nvr --latest-limit=1 \
    $(cat packages.list)
  dnf repoquery \
    ${repos} \
    --arch=x86_64 --arch=noarch \
    --nvr --resolve --requires --recursive \
    $(cat packages.list)
) \
  | sort \
  | uniq \
  | sed '/langpack-/{/langpack-en/!d};/all-langpacks/d' \
  | sed '/^fedora-release-/{/^fedora-release-\(common\|identity-basic\|[0-9]\{1,\}\)/!d}' | tee rpms.lock
