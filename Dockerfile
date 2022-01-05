# syntax = docker/dockerfile:1.2
ARG FEDORA_MAJOR
FROM fedora:${FEDORA_MAJOR}

RUN --mount=type=cache,target=/var/cache/dnf \
  dnf install -y --repo fedora --repo updates \
    bsdtar \
    cpio \
    createrepo \
    dnf-plugins-core \
    findutils \
    genisoimage \
    git \
    make \
    pykickstart \
    wget \
  && dnf clean all \
  && dnf config-manager \
    --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

WORKDIR /work

RUN curl --fail https://getfedora.org/static/fedora.gpg | gpg --import

ARG FEDORA_MIRROR=https://ftp.yz.yamagata-u.ac.jp/pub/linux/fedora-projects/fedora/linux
ARG FEDORA_VERSION
ARG FEDORA_MAJOR
ENV FEDORA_VERSION=${FEDORA_VERSION} \
  FEDORA_MIRROR=${FEDORA_MIRROR} \
  FEDORA_MAJOR=${FEDORA_MAJOR}
RUN curl --fail -L --remote-name \
    ${FEDORA_MIRROR}/releases/${FEDORA_MAJOR}/Server/x86_64/iso/Fedora-Server-${FEDORA_VERSION}-x86_64-CHECKSUM \
  && curl --fail -L --remote-name \
    ${FEDORA_MIRROR}/releases/${FEDORA_MAJOR}/Server/x86_64/iso/Fedora-Server-netinst-x86_64-${FEDORA_VERSION}.iso \
  && gpg --verify *-CHECKSUM \
  && sha256sum --ignore-missing -c *-CHECKSUM \
  && echo "VOLUME_LABEL=$(isoinfo -d -i fedora.iso | sed -n 's/Volume id: //p;s/ /\\x20/g')" >> env.conf \
  && mkdir ./iso-root \
  && bsdtar -xf Fedora-Server-netinst-x86_64-${FEDORA_VERSION}.iso -C ./iso-root \
  && rm Fedora-Server-netinst-x86_64-${FEDORA_VERSION}.iso

RUN . ./env.conf \
  && echo -e "label kickstart\n\
    menu label ^Install customized fedora with tmpfsroot\n\
    menu default\n\
    kernel vmlinuz\n\
    append initrd=initrd.img inst.stage2=hd:LABEL=${VOLUME_LABEL} inst.ks=cdrom:/ks.cfg nouveau.modeset=0" > boot-label.cfg \
  && echo -e "menuentry 'Install customized fedora with tmpfsroot' --class fedora --class gnu-linux --class gnu --class os {\n\
    linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=${VOLUME_LABEL} inst.ks=cdrom:/ks.cfg\n\
    initrdefi /images/pxeboot/initrd.img \n\
  }" > efiboot-label.cfg

COPY iso-root ./iso-root
COPY root ./root
COPY ks.tpl.cfg comps.tpl.xml ./

ARG TMPFSROOT_VERSION=v0.0.2
RUN --mount=type=secret,id=netrc,target=/root/.netrc \
  git clone --depth=1 -b ${TMPFSROOT_VERSION} https://github.com/seqsense/tmpfsroot /tmp/tmpfsroot \
  && pwd; ls -l ./ \
  && mv /tmp/tmpfsroot/96tmpfsroot ./root/lib/dracut/modules.d/ \
  && rm -rf /tmp/tmpfsroot

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
