#!/usr/bin/env bash

# ============================================================
# MILESTONE 4 — Package reusable libvirt Vagrant box
#
# Purpose:
#   Package the configured QCOW2 working image into the
#   .box archive format expected by vagrant-libvirt.
#
# Input:
#   work/ubuntu-24.04-vagrant.qcow2
#
# Output:
#   output/ubuntu-24.04-libvirt.box
#   output/ubuntu-24.04-libvirt.box.sha256
#
# Package contents:
#   metadata.json
#   box.img
#
# Important:
#   box.img is initially represented by a symbolic link to the
#   working QCOW2 image. tar --dereference stores the actual
#   image contents inside the final .box archive rather than
#   storing the symbolic link itself.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00_config.sh"

echo "=== Milestone 4: Package Vagrant box ==="

# ------------------------------------------------------------
# Pre-checks
# ------------------------------------------------------------

[[ -f "$WORK_IMAGE" ]] || {
    echo "ERROR: Configured working image not found."
    echo "Run ./03_configure_guest.sh first."
    exit 1
}

command -v tar >/dev/null || {
    echo "ERROR: tar is required."
    exit 1
}

command -v sha256sum >/dev/null || {
    echo "ERROR: sha256sum is required."
    exit 1
}

# ------------------------------------------------------------
# Prepare clean packaging directory
# ------------------------------------------------------------

rm -rf "$BOX_BUILD_DIR"
mkdir -p "$BOX_BUILD_DIR"

VIRTUAL_SIZE_GB="${DISK_SIZE%G}"

# ------------------------------------------------------------
# Create Vagrant box metadata
# ------------------------------------------------------------

cat > "$BOX_BUILD_DIR/metadata.json" <<METADATA
{"provider":"libvirt","format":"qcow2","virtual_size":$VIRTUAL_SIZE_GB}
METADATA

# ------------------------------------------------------------
# Reference the configured QCOW2 as box.img
#
# The final tar command uses --dereference, so the resulting
# .box archive contains the QCOW2 data itself.
# ------------------------------------------------------------

ln -s "$WORK_IMAGE" "$BOX_BUILD_DIR/box.img"

# ------------------------------------------------------------
# Build final .box archive
# ------------------------------------------------------------

rm -f "$BOX_FILE"
rm -f "$BOX_FILE.sha256"

echo "Creating Vagrant box..."

tar \
    --dereference \
    -C "$BOX_BUILD_DIR" \
    -cvf "$BOX_FILE" \
    metadata.json \
    box.img

# ------------------------------------------------------------
# Verify archive structure
# ------------------------------------------------------------

echo
echo "=== Box archive contents ==="

BOX_CONTENTS="$(tar -tf "$BOX_FILE")"
printf '%s\n' "$BOX_CONTENTS"

EXPECTED_CONTENTS=$'metadata.json\nbox.img'

if [[ "$BOX_CONTENTS" != "$EXPECTED_CONTENTS" ]]; then
    echo "ERROR: Unexpected files found in Vagrant box."
    exit 1
fi

# ------------------------------------------------------------
# Create reproducibility checksum
# ------------------------------------------------------------

sha256sum "$BOX_FILE" > "$BOX_FILE.sha256"

echo
echo "=== Box metadata ==="
cat "$BOX_BUILD_DIR/metadata.json"

echo
echo "=== Box checksum ==="
cat "$BOX_FILE.sha256"

echo
echo "Milestone 4 PASSED."
echo "Box      : $BOX_FILE"
echo "Checksum : $BOX_FILE.sha256"
