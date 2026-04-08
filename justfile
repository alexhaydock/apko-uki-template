set ignore-comments

# Run a full lock --> build --> boot pipeline
go:
    just config
    just lock
    just image
    just qemu-raw

lock:
    # Create lockfile based on image config
    apko lock --output apko.lock image.yaml

[working-directory: 'config']
config:
    test -f melange.rsa || melange keygen
    # Build config package
    #
    # Here we override some git variables that melange would
    # otherwise autodiscover from our local .git directory
    # and which might change without our actual config changing
    #
    # We do this because these values end up in the SPDX file
    # embedded in the APK package and change any time HEAD's
    # hash changes, even if the package contents stay the same,
    # which breaks reproducibility
    # 
    # We override these to the values the upstream apko code
    # defaults to using when run in a directory that isn't
    # a git repo
    melange build \
    --signing-key melange.rsa \
    --git-commit "unknown" \
    --git-repo-url "https://unknown/unknown/unknown" \
    --arch amd64 config-overlay.yaml

image:
    #!/usr/bin/env bash
    set -euo pipefail
    # Calculate output filename based truncated hash of the lockfile
    OUTPUT="alpine_$(sha256sum apko.lock | cut -c1-7)"
    # Create build and rebuild tempdirs
    build_tmp="$(mktemp -d)"
    # Ensure cleanup if the process exits
    trap 'rm -rf "${build_tmp}"' EXIT
    # DEBUG: echo status
    echo "Build dir: ${build_tmp}"
    # Build cpio file
    #
    # I previously used build-minirootfs here to build a tar-based
    # minirootfs and then unpacked-and-repacked it for the final
    # image, but there's an undocumented `build-cpio` command in
    # apko that we can use to do this more robustly:
    # https://github.com/chainguard-dev/apko/pull/1177
    apko build-cpio --lockfile apko.lock image.yaml ${build_tmp}/initramfs
    # Extract just the kernel from image so we can build it into UKI
    cpio -D ${build_tmp} -id "boot/vmlinuz-virt" < ${build_tmp}/initramfs
    cp -f ${build_tmp}/boot/vmlinuz-virt output/vmlinuz-virt
    # Compress initramfs with_initramfs.zstd
    # (Without doing this we seemingly can't boot the UKI in QEMU using
    # the -kernel argument)
    zstd -f -19 "${build_tmp}/initramfs" -o "output/${OUTPUT}_initramfs.zst"
    # Build initramfs and kernel into UKI
    ukify build \
    --output "output/${OUTPUT}_uki.efi" \
    --cmdline "rdinit=/sbin/init" \
    --linux "output/vmlinuz-virt" \
    --initrd "output/${OUTPUT}_initramfs.zst"

qemu-uki:
    #!/usr/bin/env bash
    set -euo pipefail
    # Calculate output filename based truncated hash of the lockfile
    OUTPUT="alpine_$(sha256sum apko.lock | cut -c1-7)"
    # Copy vars to temp location
    OVMF_VARS_TMP="$(mktemp)"
    trap 'rm -f "${OVMF_VARS_TMP}"' EXIT
    cp -fv "${OVMF_VARS}" "${OVMF_VARS_TMP}"
    # Test in QEMU with UEFI firmware
    qemu-system-x86_64 \
    -name apkotest \
    -m 1G \
    -machine q35,smm=on,vmport=off,accel=kvm \
    -drive if=pflash,format=raw,unit=0,file=${OVMF_FIRMWARE},readonly=on \
    -drive if=pflash,format=raw,unit=1,file=${OVMF_VARS_TMP} \
    -device virtio-net-pci,netdev=nic \
    -netdev user,hostname=apko,hostfwd=tcp::2223-:22,id=nic \
    -kernel output/${OUTPUT}_uki.efi

qemu-raw:
    #!/usr/bin/env bash
    set -euo pipefail
    # Calculate output filename based truncated hash of the lockfile
    OUTPUT="alpine_$(sha256sum apko.lock | cut -c1-7)"
    # Copy vars to temp location
    OVMF_VARS_TMP="$(mktemp)"
    trap 'rm -f "${OVMF_VARS_TMP}"' EXIT
    cp -fv "${OVMF_VARS}" "${OVMF_VARS_TMP}"
    # Test in QEMU with UEFI firmware
    qemu-system-x86_64 \
    -name apkotest \
    -m 1G \
    -machine q35,smm=on,vmport=off,accel=kvm \
    -drive if=pflash,format=raw,unit=0,file=${OVMF_FIRMWARE},readonly=on \
    -drive if=pflash,format=raw,unit=1,file=${OVMF_VARS_TMP} \
    -device virtio-net-pci,netdev=nic \
    -netdev user,hostname=apko,hostfwd=tcp::2223-:22,id=nic \
    -kernel output/vmlinuz-virt \
    -initrd output/${OUTPUT}_initramfs.zst \
    -append "rdinit=/sbin/init"

# TODO: Fix networking
microvm:
    #!/usr/bin/env bash
    set -euo pipefail
    # Calculate output filename based truncated hash of the lockfile
    OUTPUT="alpine_$(sha256sum apko.lock | cut -c1-7)"
    # Test in QEMU as microVM
    qemu-system-x86_64 \
    -name apkotest \
    -m 1G \
    -machine microvm \
    -netdev tap,id=tap0,script=no,downscript=no \
    -device virtio-net-device,netdev=tap0 \
    -kernel output/vmlinuz-virt \
    -initrd output/${OUTPUT}_initramfs.zst \
    -append "rdinit=/sbin/init console=ttyS0" \
    -nographic

# Requires corresponding ~/.ssh/config entry
ssh:
    ssh apkotest

# Requires corresponding ~/.ssh/config entry
# TODO: Fix, as not yet working
waypipe:
    waypipe ssh apkotest swayimg
