#!/bin/bash

set -eu

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
  [ -z ${PARTSIZE_DOCKER} ] || \
  [ -z ${PARTSIZE_LOG} ] || \
  [ -z ${PARTSIZE_CACHE} ] || \
  [ -z ${PARTSIZE_OPT} ]
then
  echo "Required variables not set" >&2
  echo "required: DISK_DEVS, MAIN_DISK, PARTSIZE_DOCKER, PARTSIZE_LOG, PARTSIZE_CACHE, PARTSIZE_OPT" >&2
  exit 1
fi


# Download rpms
mkdir -p downloads
cat rpms.lock | xargs -n256 dnf download \
  --skip-broken \
  --arch=x86_64 --arch=noarch \
  --downloaddir=downloads \
  2> >(tee download.err >&2)

# Remove old packages
while read package
do
  if ! grep "^${package%.*.rpm}$" rpms.lock > /dev/null
  then
    rm -fv downloads/${package}
  fi
done < <(cd downloads; ls -1 *.rpm)

# Check missing packages
idDownloaded() {
  if ls downloads/$1.* > /dev/null 2> /dev/null
  then
    return 0
  fi
  return 1
}

while read package
do
  if ! idDownloaded ${package}
  then
    # Error will be printed
    continue
  fi
  line_num=$(grep -n "${package}" rpms.lock | cut -f1 -d:)
  echo "::warning file=rpms.lock,line=${line_num},title=Package ${package} missing from the repositories"
done < <(sed -n 's/^No package \(\S*\) available\.$/\1/p' download.err)

line_num=0
error=false
while read package
do
  if ! idDownloaded ${package}
  then
    echo "::error file=rpms.lock,line=${line_num},title=Package ${package} unavailable"
    error=true
  fi
  (line_num+=1)
done < rpms.lock

if ${error}
then
  echo "Missing packages" >&2
  exit 1
fi

rm -rf iso-root/Packages
mkdir -p iso-root/Packages
while read rpm
do
  initial=${rpm:0:1}
  mkdir -p iso-root/Packages/${initial}
  cp ./downloads/${rpm}.*.rpm iso-root/Packages/${initial}/
done < rpms.lock


# Create custom install files tarball
cp -ar root.override/* root/ || true
tar czf iso-root/custom-files.tar.gz root hooks.d

# Generate kickstart config
mkdir -p ks2
cp ks/ks.*.cfg ks2/
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
  " ks.tpl.cfg > iso-root/ks.cfg


# Create manifest
cat packages.list | grep -v '^-x' | xargs -n1 -I{} echo "<packagereq type=\"mandatory\">{}</packagereq>" > packagereqs.xml
sed -e '/<\/packagelist>/e cat packagereqs.xml' comps.tpl.xml > iso-root/comps.xml
createrepo -g comps.xml iso-root/


# Custom scripts
if [ -d build-hooks.d ]
then
  for script in build-hooks.d/*.sh
  do
    ${script}
  done
fi


# Copy custom iso-root files
if [ -d iso-root.override ]
then
  cp -r iso-root.override/* iso-root/
fi


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
  -graft-points \
  -V tmpfsroot-fedora \
  -R -J -v \
  iso-root/

chmod a+w /work/output/fedora-custom.iso
