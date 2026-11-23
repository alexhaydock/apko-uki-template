#!/usr/bin/env bash
set -euo pipefail

build() {
    podman build -t snpguest -f Containerfile-snpguest .
    podman rm snpguest || true
    podman create --name snpguest localhost/snpguest
    podman cp snpguest:/snpguest config/vendor/usr/bin/snpguest
}

time build
