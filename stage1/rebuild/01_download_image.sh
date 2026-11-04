#!/usr/bin/env bash

# ============================================================
# MILESTONE 1 — Download and verify Ubuntu base image
#
# Purpose:
#   Download the official Ubuntu 24.04 LTS amd64 cloud image
#   and verify it against Ubuntu's published SHA256 checksum.
#
# Output:
#   downloads/ubuntu-24.04-server-cloudimg-amd64.img
#   downloads/SHA256SUMS
#   downloads/base-image.sha256.lock
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00_config.sh"

CHECKSUM_FILE="$DOWNLOAD_DIR/SHA256SUMS"
LOCK_FILE="$DOWNLOAD_DIR/base-image.sha256.lock"

echo "=== Milestone 1: Ubuntu base image ==="

# ------------------------------------------------------------
# Pre-check
# ------------------------------------------------------------

command -v curl >/dev/null || {
    echo "ERROR: curl is required."
    exit 1
}

command -v sha256sum >/dev/null || {
    echo "ERROR: sha256sum is required."
    exit 1
}

# ------------------------------------------------------------
# Download official checksum list
# ------------------------------------------------------------

echo "Downloading Ubuntu SHA256SUMS..."

curl -fL \
    "$SHA256SUMS_URL" \
    -o "$CHECKSUM_FILE"

# Extract the checksum belonging to our amd64 QCOW2 image.
EXPECTED_SHA256="$(
    awk -v name="$BASE_IMAGE_NAME" \
        '$2 == "*"name || $2 == name {print $1}' \
        "$CHECKSUM_FILE"
)"

if [[ -z "$EXPECTED_SHA256" ]]; then
    echo "ERROR: Could not find checksum for $BASE_IMAGE_NAME"
    exit 1
fi

# ------------------------------------------------------------
# Reproducibility lock
# ------------------------------------------------------------

if [[ -f "$LOCK_FILE" ]]; then
    LOCKED_SHA256="$(cat "$LOCK_FILE")"

    if [[ "$EXPECTED_SHA256" != "$LOCKED_SHA256" ]]; then
        echo "ERROR: Ubuntu release image has changed."
        echo "Locked : $LOCKED_SHA256"
        echo "Current: $EXPECTED_SHA256"
        exit 1
    fi
else
    echo "ERROR: Committed SHA256 lock is missing."
    exit 1
fi

# ------------------------------------------------------------
# Download image
# ------------------------------------------------------------

if [[ ! -f "$BASE_IMAGE" ]]; then
    echo "Downloading Ubuntu image..."

    curl -fL \
        "$BASE_IMAGE_URL" \
        -o "$BASE_IMAGE"
else
    echo "Base image already exists; verifying existing file."
fi

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------

ACTUAL_SHA256="$(sha256sum "$BASE_IMAGE" | awk '{print $1}')"

if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "ERROR: SHA256 verification failed."
    echo "Expected: $EXPECTED_SHA256"
    echo "Actual  : $ACTUAL_SHA256"
    exit 1
fi

echo
echo "Ubuntu base image verification PASSED."
echo "Image : $BASE_IMAGE"
echo "SHA256: $ACTUAL_SHA256"
echo "Lock  : $LOCK_FILE"
