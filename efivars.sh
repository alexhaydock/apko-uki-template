#!/usr/bin/env bash
set -euo pipefail

# Generate Secure Boot DB & PCR keys
test -f keys/db-priv.pem || ukify genkey \
    --secureboot-private-key=keys/db-priv.pem \
    --secureboot-certificate=keys/db-cert.pem \
    --pcr-private-key=keys/tpm2-pcr-initrd-priv.pem \
    --pcr-public-key=keys/tpm2-pcr-initrd-cert.pem

# Generate Secure Boot PK key to provide the overall
# root of trust for our firmware. We don't really use
# this directly since we're not singing updates, but we
# need it to switch our firmware out of Setup Mode
test -f keys/db-priv.pem || openssl req -newkey rsa:4096 \
    -nodes -keyout keys/pk-priv.key \
    -new -x509 -sha256 -days 3650 \
    -subj "/CN=NekOS Secure Boot PK/" \
    -out keys/pk-cert.pem

# Build the VARS store that uses our custom Secure Boot keys
virt-fw-vars \
  --output-json OVMF_VARS_CUSTOM.json \
  --set-pk-cert "$(uuidgen)" keys/pk-cert.pem \
  --add-db-cert "$(uuidgen)" keys/db-cert.pem \
  --microsoft-db none \
  --microsoft-kek none \
  --secure-boot

# Inject our custom example directly into the var with jq
jq --rawfile data data.ascii \
  '.variables += [{"name": "ASCIIFun", "guid": "00000000-1111-2222-3333-444444444444", "attr": 7, "data": $data}]' \
  OVMF_VARS_CUSTOM.json > OVMF_VARS_CUSTOM.json.tmp && mv OVMF_VARS_CUSTOM.json.tmp OVMF_VARS_CUSTOM.json
