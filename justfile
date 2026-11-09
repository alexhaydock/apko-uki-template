set ignore-comments

# Run a full lock --> build --> boot pipeline
go:
    just config
    just lock
    just efivars
    just initramfs
    just uki
    just qemu-uki

[working-directory: 'config']
config:
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
    podman run --privileged --rm -it -v "$(pwd):/opt" --workdir /opt cgr.dev/chainguard/wolfi-base \
    sh -c \
    'apk --no-cache add melange && \
    test -f melange.rsa || melange keygen && \
    melange build \
    --signing-key melange.rsa \
    --git-commit "unknown" \
    --git-repo-url "https://unknown/unknown/unknown" \
    --arch amd64 config-overlay.yaml'

lock:
    # Create lockfile based on image config
    podman run --privileged --rm -it -v "$(pwd):/opt" --workdir /opt cgr.dev/chainguard/wolfi-base \
    sh -c \
    'apk --no-cache add apko && \
    apko lock --output apko.lock image.yaml'

initramfs:
    podman run --privileged --rm -it -v "$(pwd):/opt" --workdir /opt cgr.dev/chainguard/wolfi-base \
    sh -c \
    'apk --no-cache add apko cpio systemd-ukify zstd && \
    sh /opt/imagebuild.sh'

uki:
    podman run --privileged --rm -it -v "$(pwd):/opt" --workdir /opt docker.io/library/alpine \
    sh -c \
    'apk --no-cache add apko sbsigntool ukify && \
    sh /opt/ukibuild.sh'

efivars:
    podman run --rm -it -v "$(pwd):/opt" --workdir /opt registry.fedoraproject.org/fedora \
    sh -c \
    'dnf install -y edk2-ovmf jq openssl python3-virt-firmware ukify uuidgen && \
    sh /opt/efivars.sh'

qemu-uki:
    #!/usr/bin/env bash
    set -euo pipefail
    # Calculate output filename based truncated hash of the lockfile
    OUTPUT="alpine_$(sha256sum apko.lock | cut -c1-7)"
    # Copy vars to temp location
    OVMF_VARS_TMP="$(mktemp)"
    trap 'rm -f "${OVMF_VARS_TMP}"' EXIT
    cp -fv "OVMF_VARS_CUSTOM.json" "${OVMF_VARS_TMP}"
    # Test in QEMU with UEFI firmware
    qemu-system-x86_64 \
    -name apkotest \
    -m 1G \
    -machine q35,smm=on,vmport=off,accel=kvm \
    -drive if=pflash,format=raw,unit=0,file=/usr/share/edk2/ovmf/OVMF.qemuvars.fd,readonly=on \
    -device uefi-vars-x64,jsonfile="${OVMF_VARS_TMP}" \
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
    cp -fv "OVMF_VARS_CUSTOM.json" "${OVMF_VARS_TMP}"
    # Test in QEMU with UEFI firmware
    qemu-system-x86_64 \
    -name apkotest \
    -m 1G \
    -machine q35,smm=on,vmport=off,accel=kvm \
    -drive if=pflash,format=raw,unit=0,file=/usr/share/edk2/ovmf/OVMF.qemuvars.fd,readonly=on \
    -device uefi-vars-x64,jsonfile="${OVMF_VARS_TMP}" \
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
