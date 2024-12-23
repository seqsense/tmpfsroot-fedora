#!/bin/bash

set -eu

arch=${ARCH:-x86_64}

if [ ! -f rpms.lock ]; then
  echo "rpms.lock not found"
fi

if [ ! -f packages.list ]; then
  echo "packages.list not found"
fi

if [ -z ${DISK_DEVS} ] \
  || [ -z ${MAIN_DISK} ] \
  || [ -z ${PARTSIZE_DOCKER} ] \
  || [ -z ${PARTSIZE_LOG} ] \
  || [ -z ${PARTSIZE_CACHE} ] \
  || [ -z ${PARTSIZE_OPT} ]; then
  echo "Required variables not set" >&2
  echo "required: DISK_DEVS, MAIN_DISK, PARTSIZE_DOCKER, PARTSIZE_LOG, PARTSIZE_CACHE, PARTSIZE_OPT" >&2
  exit 1
fi

# Download rpms
download_opts="--skip-broken"
if [ ${FEDORA_MAJOR} -ge 41 ]; then
  # Option for dnf5
  download_opts="--best"
fi
mkdir -p downloads
cat rpms.lock | xargs -n256 dnf download \
  ${download_opts} \
  --arch=${arch} --arch=noarch \
  --downloaddir=downloads \
  2> >(tee download.err >&2)

# Remove old packages
while read package; do
  if ! grep "^${package%.*.rpm}$" rpms.lock >/dev/null; then
    rm -fv downloads/${package}
  fi
done < <(
  cd downloads
  ls -1 *.rpm
)

# Check missing packages and download old packages from kojipkgs
is_downloaded() {
  if ls downloads/$1.* >/dev/null 2>/dev/null; then
    return 0
  fi
  return 1
}
split_package_name() {
  # Example formats:
  # - pkg-name-1.2-9.fc36.8 -> pkg-name 1.2   9.fc36.8
  # - pkg-name-1.2.3-9.fc36 -> pkg-name 1.2.3 9.fc36
  # - pkg-name-1.2-9        -> pkg-name 1.2   9
  echo $1 | sed -n 's/\(\S\+\)-\([0-9a-zA-Z.-_]\+\)-\([0-9]\+\(\.fc[0-9]\+\(\.[0-9]\+\)\?\)\?\)/\1 \2 \3/p'
}
warn_if_not_in_dnf_repo() {
  if grep "^No package $1.* available.$" download.err >/dev/null 2>/dev/null; then
    line_num=$(grep -n "$1" rpms.lock | cut -f1 -d:)
    echo "::warning file=rpms.lock,line=${line_num}::Package $1 missing from the repositories"
  fi
}

line_num=-1
error=false
while read package; do
  (line_num+=1)

  if is_downloaded ${package}; then
    # Warn if not found in dnf repo but in local cache
    warn_if_not_in_dnf_repo ${package}
    continue
  fi

  echo "Downloading ${package} from kojipkgs"

  pkg_fields=$(split_package_name ${package})

  if [ -z "${pkg_fields}" ]; then
    echo "::error file=rpms.lock,line=${line_num}::Failed to parse package name: ${package}"
    error=true
    continue
  fi

  pkg_name=$(echo ${pkg_fields} | cut -f1 -d" ")
  pkg_version=$(echo ${pkg_fields} | cut -f2 -d" ")
  pkg_suffix=$(echo ${pkg_fields} | cut -f3 -d" ")

  pkg_src=$(
    dnf info ${pkg_name} \
      | sed -n 's/^Source\s*:\s*\(\S\+\).src.rpm/\1/p' \
      | head -n1
  )
  src_fields=$(split_package_name ${pkg_src})
  src_name=$(echo ${src_fields} | cut -f1 -d" ")
  for pkg_arch in ${arch} noarch; do
    url="https://kojipkgs.fedoraproject.org/packages/${src_name}/${pkg_version}/${pkg_suffix}/${pkg_arch}/${package}.${pkg_arch}.rpm"
    url_noarch="https://kojipkgs.fedoraproject.org/packages/${src_name}/${pkg_version}/${pkg_suffix}/noarch/${package}.noarch.rpm"
    if wget -q ${url} -O downloads/${package}.${pkg_arch}.rpm; then
      break
    fi
    if wget -q ${url_noarch} -O downloads/${package}.noarch.rpm; then
      break
    fi
    echo "- failed to download ${url}"
    rm -f downloads/${package}.*.rpm
  done

  if is_downloaded ${package}; then
    # Warn if not found in dnf repo and local cache but in kojipkgs
    warn_if_not_in_dnf_repo ${package}
    continue
  fi

  echo "::error file=rpms.lock,line=${line_num}::Package ${package} unavailable"
  error=true
done <rpms.lock

if ${error}; then
  echo "Missing packages" >&2
  exit 1
fi

# Generate iso
rm -rf iso-root/Packages
mkdir -p iso-root/Packages
while read rpm; do
  initial=${rpm:0:1}
  mkdir -p iso-root/Packages/${initial}
  cp ./downloads/${rpm}.*.rpm iso-root/Packages/${initial}/
done <rpms.lock

# Create custom install files tarball
cp -ar root.override/* root/ || true
tar czf iso-root/custom-files.tar.gz root hooks.d

# Generate kickstart config
mkdir -p ks2
cp ks/ks.*.cfg ks2/ || true
(cd ks2 && touch ks.post.cfg ks.post-nochroot.cfg ks.pre.cfg ks.pre-install.cfg ks.root.cfg)
sed "
    s/@@DISK_DEVS@@/${DISK_DEVS}/g
    s/@@MAIN_DISK@@/${MAIN_DISK}/g
    s/@@PARTSIZE_DOCKER@@/${PARTSIZE_DOCKER}/g
    s/@@PARTSIZE_LOG@@/${PARTSIZE_LOG}/g
    s/@@PARTSIZE_CACHE@@/${PARTSIZE_CACHE}/g
    s/@@PARTSIZE_OPT@@/${PARTSIZE_OPT}/g
    /@@KS\.POST\.CFG@@/{
      s/^/# /
      n
      e cat ks2/ks.post.cfg
    }
    /@@KS\.POST-NOCHROOT\.CFG@@/{
      s/^/# /
      n
      e cat ks2/ks.post-nochroot.cfg
    }
    /@@KS\.PRE\.CFG@@/{
      s/^/# /
      n
      e cat ks2/ks.pre.cfg
    }
    /@@KS\.PRE-INSTALL\.CFG@@/{
      s/^/# /
      n
      e cat ks2/ks.pre-install.cfg
    }
    /@@KS\.ROOT\.CFG@@/{
      s/^/# /
      n
      e cat ks2/ks.root.cfg
    }
  " ks.tpl.cfg >iso-root/ks.cfg

# Create manifest
cat packages.list | grep -v '^-x' | while read pkg; do
  name="$(split_package_name ${pkg} | cut -f1 -d" ")"
  if [ -z "${name}" ]; then
    name="${pkg}"
  fi
  echo "<packagereq type=\"mandatory\">${name}</packagereq>"
done >packagereqs.xml
sed -e '/<\/packagelist>/e cat packagereqs.xml' comps.tpl.xml >iso-root/comps.xml
createrepo -g comps.xml iso-root/

# Custom scripts
for script in $(find build-hooks.d -executable -name '*.sh'); do
  ${script}
done

# Copy custom iso-root files
cp -r iso-root.override/* iso-root/ || true

# Copy custom files to product.img
if [ -d installfs.override ]; then
  mksquashfs installfs.override iso-root/images/product.img -noappend -comp xz -Xbcj x86
fi

eltorito_boot=
for img in \
  isolinux/isolinux.bin \
  images/eltorito.img; do
  if [ -f iso-root/${img} ]; then
    eltorito_boot=${img}
  fi
done
efi_boot=images/efiboot.img

if [ -z ${eltorito_boot} ]; then
  echo "El torito boot image not found" >&2
  exit 1
fi

if [ ! -f iso-root/${efi_boot} ]; then
  echo "Generating EFI image"
  # Generate EFI image
  dd \
    if=/dev/zero \
    of=iso-root/${efi_boot} \
    bs=512 \
    count=16384
  mkfs.msdos \
    -F 12 \
    -n EFI \
    iso-root/${efi_boot}
  mmd \
    -i iso-root/${efi_boot} \
    ::EFI
  mmd \
    -i iso-root/${efi_boot} \
    ::EFI/BOOT
  mcopy \
    -i iso-root/${efi_boot} \
    iso-root/EFI/BOOT/BOOTX64.EFI \
    ::EFI/BOOT/BOOTX64.EFI
  mcopy \
    -i iso-root/${efi_boot} \
    iso-root/EFI/BOOT/grubx64.efi \
    ::EFI/BOOT/grubx64.efi
fi

# Generate iso
mkisofs \
  -o /work/output/fedora-custom.iso \
  -eltorito-boot ${eltorito_boot} \
  -eltorito-catalog isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -efi-boot ${efi_boot} \
  -no-emul-boot \
  -graft-points \
  -V tmpfsroot-fedora \
  -R -J -v \
  iso-root/

chmod a+w /work/output/fedora-custom.iso
