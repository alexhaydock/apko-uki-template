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
##apko build-cpio --lockfile apko.lock image.yaml ${build_tmp}/initramfs
apko build-cpio image.yaml ${build_tmp}/initramfs

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
