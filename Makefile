SHELL := /bin/bash

FEDORA_VERSION ?= 35-1.2
FEDORA_MAJOR   := $(shell echo $(FEDORA_VERSION) | cut -f1 -d-)

ifeq ($(shell cat /etc/timezone),Asia/Tokyo)
BUILD_OPTS := --build-arg FEDORA_ISO_MIRROR=https://ftp.yz.yamagata-u.ac.jp/pub/linux/fedora-projects/fedora/linux
endif

BUILDER_IMAGE := tmpfsroot-fedora-builder:$(FEDORA_MAJOR)
UPDATER_IMAGE := tmpfsroot-fedora-updater:$(FEDORA_MAJOR)

export DOCKER_BUILDKIT = 1

.PHONY: builder
builder:
	docker build \
		$(BUILD_OPTS) \
		--build-arg FEDORA_VERSION=$(FEDORA_VERSION) \
		--build-arg FEDORA_MAJOR=$(FEDORA_MAJOR) \
		-t $(BUILDER_IMAGE) \
		.

.PHONY: updater
updater:
	docker build \
		-f updater.Dockerfile \
		--build-arg FEDORA_MAJOR=$(FEDORA_MAJOR) \
		-t $(UPDATER_IMAGE) \
		.

.PHONY: show-fedora-major
show-fedora-major:
	@echo $(FEDORA_MAJOR)

.PHONY: fmt
fmt:
	# Install shfmt by `go install mvdan.cc/sh/v3/cmd/shfmt@latest`
	shfmt -i 2 -ci -bn -l -w .
