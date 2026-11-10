#!/usr/bin/env bash
set -euo pipefail

# Calculate output filename based truncated hash of the lockfile
OUTPUT="alpine_$(sha256sum apko.lock | cut -c1-7)"

# Build initramfs and kernel into UKI
ukify build \
    --output "output/${OUTPUT}_uki.efi" \
    --cmdline "rdinit=/sbin/init" \
    --linux "output/vmlinuz-virt" \
    --initrd "output/${OUTPUT}_initramfs.zst" \
    --secureboot-private-key="keys/db-priv.pem" \
    --secureboot-certificate="keys/db-cert.pem" \
    --sign-kernel

# Validate UKI to make sure signing succeeded
sbverify \
    --cert "keys/db-cert.pem" \
    "output/${OUTPUT}_uki.efi"
