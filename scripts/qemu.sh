#!/usr/bin/env bash
set -euo pipefail

# Calculate output filename based truncated hash of the lockfile
OUTPUT="alpine_$(sha256sum apko.lock | cut -c1-7)"

# Copy vars to temp location
OVMF_VARS_TMP="$(mktemp)"
trap 'rm -f "${OVMF_VARS_TMP}"' EXIT

cp -fv "OVMF_VARS_CUSTOM.json" "${OVMF_VARS_TMP}"

# Test in QEMU with UEFI firmware that supports PV vars
qemu-system-x86_64 \
    -name apkotest \
    -m 1G \
    -machine q35,smm=on,vmport=off,accel=kvm \
    -drive if=pflash,format=raw,unit=0,file=/usr/share/edk2/ovmf/OVMF.qemuvars.fd,readonly=on \
    -device uefi-vars-x64,jsonfile="${OVMF_VARS_TMP}" \
    -device virtio-net-pci,netdev=nic \
    -netdev user,hostname=apko,hostfwd=tcp::2223-:22,id=nic \
    -kernel output/${OUTPUT}_uki.efi
