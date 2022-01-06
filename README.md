# tmpfsroot-fedora

Build power-failure-safe linux image

## Partition structure

Mount point     | Size                 | Filesystem | Usage
--------------- | -------------------- | ---------- | -----
/boot/efi       |                 200M | fat32      | EFI
/ (A)           |                   2G | ext4       | Readonly rootfs (main/fallback)
/ (B)           |                   2G | ext4       | Readonly rootfs (main/fallback)
/var/log        |    `${PARTSIZE_LOG}` | ext4       | Logs (automatically refreshed on failure)
/opt            |    `${PARTSIZE_OPT}` | btrfs      | User applications
/var/cache      |  `${PARTSIZE_CACHE}` | btrfs      | User cache
/var/lib/docker | `${PARTSIZE_DOCKER}` | btrfs      | Docker

## Example

```
export FEDORA_MAJOR=33
```

### Generate `rpms.lock`

1. Add required packages to `packages.list`
    ```
    cat << EOS > packages.list
    audit
    authselect
    basesystem
    bash
    btrfs-progs
    busybox
    chrony
    container-selinux
    containerd.io
    coreutils
    curl
    dhcp-client
    docker-ce
    docker-ce-cli
    docker-compose
    dosfstools
    e2fsprogs
    efibootmgr
    filesystem
    firewalld
    grub2-efi-x64
    iproute
    kernel
    kernel-core
    kernel-modules
    rootfiles
    setup
    shim-x64
    sudo
    systemd
    EOS
    ```
2. Generate `rpms.lock` from `packages.list`
    ```
    docker run \
      -i --rm \
      -v $(pwd):/work \
      tmprootfs-fedora-updater:${FEDORA_MAJOR}
    ```

### Add files and scripts

Directory           | Files                  | Note
------------------- | ---------------------- | ----
`build-hooks.d`     | `*.sh`                 | Executed before creating ISO
`hooks.d`           | `*.sh`                 | Executed during installation
`iso-root.override` | `**/*`                 | Copied to installer disk root
`root.override`     | `**/*`                 | Copied to installed filesystem root
`ks`                | `ks.root.cfg`          | [optional] Kickstart script included to root section
`ks`                | `ks.pre-install.cfg`   | [optional] Kickstart script included to `%pre-install` section
`ks`                | `ks.post-nochroot.cfg` | [optional] Kickstart script included to `%post --nochroot` section
`ks`                | `ks.post.cfg`          | [optional] Kickstart script included to `%post` section

### Generate installer ISO

```
export DISK_DEVS=sda,sdb     # System has /dev/sda and /dev/sdb
export MAIN_DISK=sda         # Install OS to /dev/sda
export PARTSIZE_DOCKER=8192  # 8G
export PARTSIZE_LOG=2048     # 2G
export PARTSIZE_CACHE=4096   # 4G
export PARTSIZE_OPT=2048     # 2G

export CACHE_DIR=${HOME}/.cache/tempfsroot-fedora

docker run -i --rm \
  -v "${CACHE_DIR}/.dnf:/var/cache/dnf" \
  -v "${CACHE_DIR}/downloads:/work/downloads" \
  -v "path/to/build-hooks.d:/work/build-hooks.d:ro" \
  -v "path/to/hooks.d:/work/hooks.d:ro" \
  -v "path/to/iso-root.override:/work/iso-root.override:ro" \
  -v "path/to/root.override:/work/root.override:ro" \
  -v "path/to/ks:/work/ks:ro" \
  -v "path/to/packages.list:/work/packages.list:ro" \
  -v "path/to/rpms.lock:/work/rpms.lock:ro" \
  -v "path/to/output:/work/output" \
  -e DISK_DEVS \
  -e MAIN_DISK \
  -e PARTSIZE_DOCKER \
  -e PARTSIZE_LOG \
  -e PARTSIZE_CACHE \
  -e PARTSIZE_OPT \
  tmprootfs-fedora-builder:${FEDORA_MAJOR}
```

## References
- [Kickstart](https://pykickstart.readthedocs.io/en/latest/kickstart-docs.html)
