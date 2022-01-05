SHELL := /bin/bash

FEDORA_VERSION ?= 33-1.2
FEDORA_MAJOR   := $(shell echo $(FEDORA_VERSION) | cut -f1 -d-)

ifeq ($(shell cat /etc/timezone),Asia/Tokyo)
FEDORA_MIRROR := https://ftp.yz.yamagata-u.ac.jp/pub/linux/fedora-projects/fedora/linux
else
FEDORA_MIRROR := https://dl.fedoraproject.org/pub/fedora/linux
endif

BUILDER_IMAGE := tmprootfs-fedora-builder:$(FEDORA_MAJOR)
UPDATER_IMAGE := tmprootfs-fedora-updater:$(FEDORA_MAJOR)

export DOCKER_BUILDKIT = 1

.PHONY: builder
builder:
	docker build \
		--secret id=netrc,src=$(HOME)/.netrc \
		--build-arg FEDORA_VERSION=$(FEDORA_VERSION) \
		--build-arg FEDORA_MAJOR=$(FEDORA_MAJOR) \
		--build-arg FEDORA_MIRROR=$(FEDORA_MIRROR) \
		-t $(BUILDER_IMAGE) \
		.

.PHONY: updater
updater:
	docker build \
		-f updater.Dockerfile \
		--build-arg FEDORA_MAJOR=$(FEDORA_MAJOR) \
		--build-arg FEDORA_MIRROR=$(FEDORA_MIRROR) \
		-t $(UPDATER_IMAGE) \
		.
