#!/bin/bash

set -eu

. ./env.conf


if [ ! -f rpms.lock ]
then
  echo "rpms.lock not found"
fi

if [ ! -f packages.list ]
then
  echo "packages.list not found"
fi

if [ -z ${DISK_DEVS} ] || \
  [ -z ${MAIN_DISK} ] || \
  [ -z ${PARTSIZE_LOG} ] || \
  [ -z ${PARTSIZE_CACHE} ] || \
  [ -z ${PARTSIZE_OPT} ]
then
  echo "Required variables not set" >&2
  echo "required: DISK_DEVS, MAIN_DISK, PARTSIZE_LOG, PARTSIZE_CACHE, PARTSIZE_OPT" >&2
  exit 1
fi


dnf_repos="
	--repofrompath releases-tmp,${FEDORA_MIRROR}/releases/${FEDORA_MAJOR}/Everything/x86_64/os
	--repofrompath updates-tmp,${FEDORA_MIRROR}/updates/${FEDORA_MAJOR}/Everything/x86_64
	--repo releases-tmp
	--repo updates-tmp
	--repo docker-ce-stable"


# Download rpms
mkdir -p downloads
cat rpms.lock | xargs -n256 dnf download \
  ${dnf_repos} \
  --downloaddir=downloads
while read package
do
  if ! grep "^${package%.*.rpm}$" rpms.lock > /dev/null
  then
    rm -fv downloads/${package}
  fi
done < <(cd downloads; ls -1 *.rpm)

rm -rf iso-root/Packages
mkdir -p iso-root/Packages
while read rpm
do
  initial=${rpm:0:1}
  mkdir -p iso-root/Packages/${initial}
  cp ./downloads/${rpm}.*.rpm iso-root/Packages/${initial}/
done < rpms.lock


# Update grub configs
sed -i '/menu default/d' iso-root/isolinux/isolinux.cfg
sed -i '/label linux/e cat boot-label.cfg' iso-root/isolinux/isolinux.cfg
sed -i "/menuentry 'Test this media /e cat efiboot-label.cfg" iso-root/EFI/BOOT/grub.cfg
sed -i "s/^set timeout=.*$/set timeout=10/" iso-root/EFI/BOOT/grub.cfg


# Create custom install files tarball
cp -ar root.override/* root/
tar czf iso-root/custom-files.tar.gz root hooks.d


# Generate kickstart config
sed "s/@@DISK_DEVS@@/${DISK_DEVS}/g
    s/@@MAIN_DISK@@/${MAIN_DISK}/g
    s/@@PARTSIZE_LOG@@/${PARTSIZE_LOG}/g
    s/@@PARTSIZE_CACHE@@/${PARTSIZE_CACHE}/g
    s/@@PARTSIZE_OPT@@/${PARTSIZE_OPT}/g" ks.tpl.cfg > iso-root/ks.cfg
cp ks/ks.*.cfg iso-root


# Create manifest
cat packages.list | xargs -n1 -I{} echo "<packagereq type=\"mandatory\">{}</packagereq>" > packagereqs.xml
sed -e '/<\/packagelist>/e cat packagereqs.xml' comps.tpl.xml > comps.xml
createrepo -g comps.xml iso-root/


# Custom scripts
for script in build-hooks.d/*.sh
do
  ${script}
done


# Generate iso
mkisofs \
  -o /work/output/fedora-custom.iso \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e images/efiboot.img \
  -no-emul-boot \
  -m TRANS.TBL \
  -m .dnf \
  -graft-points \
  -V "${VOLUME_LABEL}" \
  -R -J -v \
  iso-root/
