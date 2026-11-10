#!/usr/bin/env bash
set -euo pipefail

apko lock \
    --output apko.lock \
    --arch amd64 \
    image.yaml
