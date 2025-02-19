# syntax = docker/dockerfile:1
ARG FEDORA_MAJOR
FROM fedora:${FEDORA_MAJOR}

RUN --mount=type=cache,target=/var/cache/dnf \
  dnf install -y --repo fedora --repo updates \
    bsdtar \
    cpio \
    createrepo \
    dnf-plugins-core \
    dosfstools \
    findutils \
    genisoimage \
    git \
    make \
    mtools \
    pykickstart \
    squashfs-tools \
    wget \
  && dnf clean all \
  && rm /etc/yum.repos.d/*.repo

# Add docker-ce RPM repository:
#   - Fedora <  41: dnf config-manager --add-repo URL
#   - Fedora >= 41: dnf config-manager addrepo --from-repofile=URL
RUN dnf config-manager \
      --add-repo https://download.docker.com/linux/fedora/docker-ce.repo \
  || dnf config-manager addrepo \
      --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

COPY fedora.repo /etc/yum.repos.d/

WORKDIR /work

COPY fedora.pub /
RUN gpg --import /fedora.pub

ARG FEDORA_ISO_MIRROR=https://dl.fedoraproject.org/pub/fedora/linux
ARG FEDORA_ISO_ARCHIVE=https://archives.fedoraproject.org/pub/archive/fedora/linux
ARG FEDORA_VERSION
ARG FEDORA_MAJOR
ARG FEDORA_RELEASE_DIR
ENV FEDORA_VERSION=${FEDORA_VERSION} \
  FEDORA_MAJOR=${FEDORA_MAJOR} \
  FEDORA_RELEASE_DIR=${FEDORA_RELEASE_DIR}

# CHECKSUM URL:
#   - Fedora <  40: Fedora-Server-${FEDORA_VERSION}-x86_64-CHECKSUM
#   - Fedora >= 40: Fedora-Server-iso-${FEDORA_VERSION}-x86_64-CHECKSUM
RUN ( \
    curl --fail -L --remote-name \
        ${FEDORA_ISO_MIRROR}/releases/${FEDORA_RELEASE_DIR}/Server/x86_64/iso/Fedora-Server-${FEDORA_VERSION}-x86_64-CHECKSUM \
    || curl --fail -L --remote-name \
        ${FEDORA_ISO_ARCHIVE}/releases/${FEDORA_RELEASE_DIR}/Server/x86_64/iso/Fedora-Server-${FEDORA_VERSION}-x86_64-CHECKSUM \
    || curl --fail -L --remote-name \
        ${FEDORA_ISO_MIRROR}/releases/${FEDORA_RELEASE_DIR}/Server/x86_64/iso/Fedora-Server-iso-${FEDORA_VERSION}-x86_64-CHECKSUM \
    || curl --fail -L --remote-name \
        ${FEDORA_ISO_ARCHIVE}/releases/${FEDORA_RELEASE_DIR}/Server/x86_64/iso/Fedora-Server-iso-${FEDORA_VERSION}-x86_64-CHECKSUM \
  ) \
  && isofile=Fedora-Server-netinst-x86_64-${FEDORA_VERSION}.iso \
  && ( \
    curl --fail -L --remote-name \
      ${FEDORA_ISO_MIRROR}/releases/${FEDORA_RELEASE_DIR}/Server/x86_64/iso/${isofile} \
    || curl --fail -L --remote-name \
      ${FEDORA_ISO_ARCHIVE}/releases/${FEDORA_RELEASE_DIR}/Server/x86_64/iso/${isofile} \
  ) \
  && gpg --verify *-CHECKSUM \
  && sha256sum --ignore-missing -c *-CHECKSUM \
  && mkdir ./iso-root \
  && bsdtar -xf ${isofile} -C ./iso-root \
  && rm ${isofile}

COPY iso-root ./iso-root
COPY root ./root
COPY ks.tpl.cfg comps.tpl.xml ./
COPY entrypoint.sh /

VOLUME \
  /work/output \
  /work/root.override \
  /work/iso-root.override \
  /work/hooks.d \
  /work/build-hooks.d \
  /work/downloads \
  /work/ks

ENTRYPOINT ["/entrypoint.sh"]
