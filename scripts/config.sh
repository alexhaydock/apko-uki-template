#!/usr/bin/env bash
set -euo pipefail

(
# Run all of this in a subshell inside the config dir
cd config

# Generate signing key (only if we don't already have one)
test -f melange.rsa || melange keygen && \

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
    --arch amd64 \
    config-overlay.yaml

)
