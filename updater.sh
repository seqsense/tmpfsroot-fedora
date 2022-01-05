#!/bin/bash

REPOS= \
  --repofrompath releases-tmp,$(FEDORA_MIRROR)/releases/$(FEDORA_MAJOR)/Everything/x86_64/os \
  --repofrompath updates-tmp,$(FEDORA_MIRROR)/updates/$(FEDORA_MAJOR)/Everything/x86_64 \
  --repo releases-tmp \
  --repo updates-tmp \
  --repo docker-ce-stable

(
  dnf repoquery \
    $(REPOS) \
    --arch=x86_64 --arch=noarch \
    --nvr --latest-limit=1 \
    $(shell cat packages.list)
  dnf repoquery \
    $(REPOS) \
    --arch=x86_64 --arch=noarch \
    --nvr --resolve --requires --recursive \
    $(shell cat packages.list)
) \
  | sort \
  | uniq \
  | sed '/langpack-/{/langpack-en/!d};/all-langpacks/d' \
  | sed '/^fedora-release-/{/^fedora-release-common/!{/^fedora-release-identity-basic/!d}}' > rpms.lock
