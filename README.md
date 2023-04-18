# tmpfsroot-fedora

Build power-failure-safe linux image based on Fedora for IoT systems

## Basics

### How to protect filesystems from power failure

Write operations during power failure may cause filesystem inconsistency.
On tmpfsroot-fedora,

- copy rootfs contents to tmpfs during boot and unmount original rootfs
- mount persistent data partitions readonly
- wipe and format broken filesystem during boot (for `/var/log`)

to keep the system at least bootable and connected to the network.

### Why based on Fedora

- **Initrd maintainance tools**: custom initrd to achieve rootfs-on-tmpfs and filesystem fault handling should be maintained accross base OS upgrades. `dracut` make it easy and sustainable.
- **Fully with systemd**: we need `init` process to be `systemd` to maintain service dependencies with many hardware devices (from initrd).

## Partition structure

Mount point     | Size                 | Filesystem | Usage
--------------- | -------------------- | ---------- | -----
/boot/efi       |                 200M | fat32      | EFI
/ (A)           |                   2G | ext4       | Readonly rootfs (main/fallback)
/ (B)           |                   2G | ext4       | Readonly rootfs (main/fallback)
/persist        |                 200M | ext4       | Readonly persistent data
/var/log        |    `${PARTSIZE_LOG}` | ext4       | Logs (automatically refreshed on failure)
/opt            |    `${PARTSIZE_OPT}` | btrfs      | User applications
/var/cache      |  `${PARTSIZE_CACHE}` | btrfs      | User cache
/var/lib/docker | `${PARTSIZE_DOCKER}` | btrfs      | Docker

## Example

Specify Fedora major version to be used.
```shell
export FEDORA_MAJOR=37
```

### Generate `rpms.lock`

1. Add required packages to `packages.list`
    ```shell
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
    ```shell
    docker run \
      -i --rm \
      -v $(pwd):/work \
      ghcr.io/seqsense/tmpfsroot-fedora-updater:${FEDORA_MAJOR}
    ```

### Add files and scripts

Directory           | Files                  | Note
------------------- | ---------------------- | ----
`ks`                | `ks.root.cfg`          | \[**Required**\] Kickstart script included to root section
`ks`                | `ks.pre-install.cfg`   | Kickstart script included to `%pre-install` section
`ks`                | `ks.post-nochroot.cfg` | Kickstart script included to `%post --nochroot` section
`ks`                | `ks.post.cfg`          | Kickstart script included to `%post` section
`build-hooks.d`     | `*.sh`                 | Executed before creating ISO
`hooks.d`           | `*.sh`                 | Executed during installation
`iso-root.override` | `**/*`                 | Copied to installer disk root
`root.override`     | `**/*`                 | Copied to installed filesystem root

### Generate installer ISO

```shell
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
  ghcr.io/seqsense/tmpfsroot-fedora-builder:${FEDORA_MAJOR}
```

## References

- [Kickstart](https://pykickstart.readthedocs.io/en/latest/kickstart-docs.html)


## License

Unless otherwise noted, the sources are licensed under [Apache License Version 2.0](./LICENSE).
