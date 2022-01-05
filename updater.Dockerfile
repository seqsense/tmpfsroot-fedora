# syntax = docker/dockerfile:1.2
ARG FEDORA_MAJOR
FROM fedora:${FEDORA_MAJOR}

RUN --mount=type=cache,target=/var/cache/dnf \
  dnf install -y --repo fedora --repo updates \
    bash \
    dnf-plugins-core \
    findutils \
    make \
  && dnf clean all \
  && dnf config-manager \
    --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

VOLUME /var/cache/dnf

ARG FEDORA_MIRROR=https://ftp.yz.yamagata-u.ac.jp/pub/linux/fedora-projects/fedora/linux
ARG FEDORA_MAJOR
ENV FEDORA_MAJOR=${FEDORA_MAJOR} \
  FEDORA_MIRROR=${FEDORA_MIRROR}

VOLUME /work
WORKDIR /work

COPY updater.sh /
CMD ["/updater.sh"]
