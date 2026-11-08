#!/usr/bin/env bash
set -euo pipefail

# Generate Secure Boot DB & PCR keys
ukify genkey \
    --secureboot-private-key=/opt/keys/db-priv.pem \
    --secureboot-certificate=/opt/keys/db-cert.pem \
    --pcr-private-key=/opt/keys/tpm2-pcr-initrd-priv.pem \
    --pcr-public-key=/opt/keys/tpm2-pcr-initrd-cert.pem

# Generate Secure Boot PK key to provide the overall
# root of trust for our firmware. We don't really use
# this directly since we're not singing updates, but we
# need it to switch our firmware out of Setup Mode
openssl req -newkey rsa:4096 \
    -nodes -keyout /opt/keys/pk-priv.key \
    -new -x509 -sha256 -days 3650 \
    -subj "/CN=NekOS Secure Boot PK/" \
    -out /opt/keys/pk-cert.pem

# Create a blank JSON VARS store so we have something to
# work with if we don't want Secure Boot validation active
virt-fw-vars \
  --output-json /opt/OVMF_VARS_INSECURE.json

# Create one based on the populated qcow2 VARS store that
# Fedora ship with their native OVMF build
#
# This is lazy and we could do this without relying on the
# Fedora package, but it involves messing around with Microsoft's
# certs ourselves
virt-fw-vars \
  --input /usr/share/edk2/ovmf/OVMF_VARS_4M.secboot.qcow2 \
  --output-json /opt/OVMF_VARS_MS.json

# Build the VARS store that uses our custom Secure Boot keys
virt-fw-vars \
  --output-json /opt/OVMF_VARS_CUSTOM.json \
  --set-pk-cert "$(uuidgen)" /opt/keys/pk-cert.pem \
  --add-db-cert "$(uuidgen)" /opt/keys/db-cert.pem \
  --microsoft-db none \
  --microsoft-kek none \
  --secure-boot
