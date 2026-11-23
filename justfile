set ignore-comments

go:
    just config
    just initramfs
    just uki
    just efivars
    just qemu

snpguest:
    sh scripts/snpguest.sh

config:
    podman run --privileged --rm -it -v "$(pwd):/opt" --workdir /opt cgr.dev/chainguard/wolfi-base \
    sh -c \
    'apk --no-cache add melange && \
    sh /opt/scripts/config.sh'

initramfs:
    podman run --privileged --rm -it -v "$(pwd):/opt" --workdir /opt cgr.dev/chainguard/wolfi-base \
    sh -c \
    'apk --no-cache add apko cpio systemd-ukify zstd && \
    sh /opt/scripts/initramfs.sh'

uki:
    podman run --privileged --rm -it -v "$(pwd):/opt" --workdir /opt docker.io/library/alpine \
    sh -c \
    'apk --no-cache add apko sbsigntool ukify && \
    sh /opt/scripts/uki.sh'

efivars:
    podman run --rm -it -v "$(pwd):/opt" --workdir /opt registry.fedoraproject.org/fedora \
    sh -c \
    'dnf install -y edk2-ovmf jq openssl python3-virt-firmware ukify uuidgen xxd && \
    sh /opt/scripts/efivars.sh'

qemu:
    sh scripts/qemu.sh
