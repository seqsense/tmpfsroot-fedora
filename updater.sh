#!/bin/bash

set -eu

raw_rpms=$(mktemp)

queryformat='--nvr'
resolve_args='--resolve --requires --recursive'
if [ ${FEDORA_MAJOR} -ge 41 ]; then
  # Option for dnf5
  queryformat='--queryformat=%{name}-%{version}-%{release}\n'
  resolve_args='--recursive --providers-of=requires'
fi

dnf repoquery \
  ${queryformat} \
  --arch=x86_64 --arch=noarch \
  --latest-limit=1 \
  $(cat packages.list) >>${raw_rpms}
dnf repoquery \
  ${queryformat} \
  --arch=x86_64 --arch=noarch \
  ${resolve_args} \
  $(cat packages.list) >>${raw_rpms}

cat ${raw_rpms} \
  | sort \
  | uniq \
  | sed '/langpack-/{/langpack-en/!d};/all-langpacks/d' \
  | sed '/^fedora-release-/{/^fedora-release-\(common\|identity-basic\|[0-9]\{1,\}\)/!d}' | tee rpms.lock
