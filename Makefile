NAME  := tmprootfs-fedora-builder
SHELL := /bin/bash

FEDORA_VERSION ?= 33-1.2
FEDORA_MAJOR   := $(shell echo $(FEDORA_VERSION) | cut -f1 -d-)

export DOCKER_BUILDKIT = 1

.PHONY: docker-build
docker-build:
	docker build \
		--secret id=netrc,src=$(HOME)/.netrc \
		--build-arg FEDORA_VERSION=$(FEDORA_VERSION) \
		--build-arg FEDORA_MAJOR=$(FEDORA_MAJOR) \
		-t $(NAME) \
		.
