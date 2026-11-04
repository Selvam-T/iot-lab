#!/usr/bin/env bash

# ============================================================
# MILESTONE 5 — Register rebuilt Vagrant box
#
# Purpose:
#   Replace any previously registered local copy of the lab box
#   with the newly rebuilt and verified .box artifact.
#
# This ensures subsequent tests use the reproducible build
# output rather than an older manually prepared box.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00_config.sh"

echo "=== Milestone 5: Register rebuilt Vagrant box ==="

# ------------------------------------------------------------
# Pre-check
# ------------------------------------------------------------

[[ -f "$BOX_FILE" ]] || {
    echo "ERROR: Vagrant box artifact not found."
    echo "Run ./04_package_box.sh first."
    exit 1
}

command -v vagrant >/dev/null || {
    echo "ERROR: vagrant is required."
    exit 1
}

# ------------------------------------------------------------
# Remove previous local registration
#
# The command may return non-zero if the box does not currently
# exist, so that condition is intentionally tolerated.
# ------------------------------------------------------------

echo "Removing previous local registration if present..."

vagrant box remove \
    --force \
    "$BOX_NAME" \
    --provider libvirt \
    2>/dev/null || true

# ------------------------------------------------------------
# Register newly rebuilt box
# ------------------------------------------------------------

echo "Registering rebuilt box..."

vagrant box add \
    --name "$BOX_NAME" \
    "$BOX_FILE"

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------

echo
echo "=== Registered boxes ==="

BOX_LIST="$(vagrant box list)"
printf '%s\n' "$BOX_LIST"

if ! grep -Fq "$BOX_NAME" <<< "$BOX_LIST"; then
    echo "ERROR: $BOX_NAME was not registered."
    exit 1
fi

if ! grep -F "$BOX_NAME" <<< "$BOX_LIST" | grep -Fq "libvirt"; then
    echo "ERROR: $BOX_NAME is not registered for libvirt."
    exit 1
fi

echo
echo "Milestone 5 PASSED."
echo "Registered box: $BOX_NAME"
