#!/usr/bin/env bash

# ============================================================
# MILESTONE 2 — Prepare and expand working disk
#
# Purpose:
#   Create a new 16 GiB QCOW2 working image from the verified
#   Ubuntu cloud image and expand its root partition.
#
# Source:
#   downloads/ubuntu-24.04-server-cloudimg-amd64.img
#
# Output:
#   work/ubuntu-24.04-vagrant.qcow2
#
# Important:
#   The original downloaded cloud image is never modified.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00_config.sh"

echo "=== Milestone 2: Prepare working disk ==="

# ------------------------------------------------------------
# Pre-checks
# ------------------------------------------------------------

[[ -f "$BASE_IMAGE" ]] || {
    echo "ERROR: Base image not found."
    echo "Run ./01_download_image.sh first."
    exit 1
}

command -v qemu-img >/dev/null || {
    echo "ERROR: qemu-img is required."
    exit 1
}

command -v virt-resize >/dev/null || {
    echo "ERROR: virt-resize is required."
    exit 1
}

command -v virt-filesystems >/dev/null || {
    echo "ERROR: virt-filesystems is required."
    exit 1
}

# ------------------------------------------------------------
# Detect the Ubuntu root partition
#
# Do NOT hardcode /dev/sda1, /dev/sda4, etc.
#
# Ubuntu cloud-image partition layouts can change between image
# revisions. During earlier Stage 0B testing the root partition
# was /dev/sda4, while the currently verified Ubuntu image uses
# /dev/sda1.
#
# The stable identifier is the filesystem label:
#     cloudimg-rootfs
#
# Detecting the partition by label makes this build process more
# reproducible and prevents a future image-layout change from
# silently expanding the wrong partition.
# ------------------------------------------------------------

echo "Detecting Ubuntu root partition..."

ROOT_PARTITION="$(
    sudo virt-filesystems \
        --filesystems \
        --long \
        -a "$BASE_IMAGE" |
    awk '$2 == "filesystem" && $4 == "cloudimg-rootfs" {print $1; exit}'
)"

if [[ -z "$ROOT_PARTITION" ]]; then
    echo "ERROR: Could not locate filesystem labelled cloudimg-rootfs."
    exit 1
fi

echo "Detected root partition: $ROOT_PARTITION"

# ------------------------------------------------------------
# Create clean destination image
# ------------------------------------------------------------

echo "Creating fresh $DISK_SIZE working image..."

rm -f "$WORK_IMAGE"

qemu-img create \
    -f qcow2 \
    "$WORK_IMAGE" \
    "$DISK_SIZE"

# ------------------------------------------------------------
# Copy source image and expand detected root partition
# ------------------------------------------------------------

echo "Expanding root partition $ROOT_PARTITION..."

sudo virt-resize \
    --expand "$ROOT_PARTITION" \
    "$BASE_IMAGE" \
    "$WORK_IMAGE"

sudo chown "$(id -u):$(id -g)" "$WORK_IMAGE"

# ------------------------------------------------------------
# Integrity verification
# ------------------------------------------------------------

echo
echo "Checking QCOW2 integrity..."

qemu-img check "$WORK_IMAGE"

echo
echo "=== Working image information ==="
qemu-img info "$WORK_IMAGE"

echo
echo "Milestone 2 PASSED."
echo "Root partition: $ROOT_PARTITION"
echo "Working image : $WORK_IMAGE"
