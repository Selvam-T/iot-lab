#!/usr/bin/env bash

# ============================================================
# MILESTONE 0 — Shared reproducible-build configuration
#
# Purpose:
#   Define all paths, names, versions and reusable constants
#   used by the Stage 0B Vagrant/libvirt image build.
#
# This file performs no destructive actions.
# Other milestone scripts source this file.
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# Project locations
# ------------------------------------------------------------

REBUILD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE_ROOT="$(dirname "$REBUILD_ROOT")"

DOWNLOAD_DIR="$REBUILD_ROOT/downloads"
WORK_DIR="$REBUILD_ROOT/work"
OUTPUT_DIR="$REBUILD_ROOT/output"

mkdir -p "$DOWNLOAD_DIR" "$WORK_DIR" "$OUTPUT_DIR"

# ------------------------------------------------------------
# Base Ubuntu image
# ------------------------------------------------------------

UBUNTU_RELEASE="24.04"
BASE_IMAGE_NAME="ubuntu-24.04-server-cloudimg-amd64.img"

BASE_IMAGE="$DOWNLOAD_DIR/$BASE_IMAGE_NAME"

# The official source URL and checksum will be locked down
# in Milestone 1 before automated download is enabled.
BASE_IMAGE_URL="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
SHA256SUMS_URL="https://cloud-images.ubuntu.com/releases/24.04/release/SHA256SUMS"

# ------------------------------------------------------------
# Working image
# ------------------------------------------------------------

WORK_IMAGE="$WORK_DIR/ubuntu-24.04-vagrant.qcow2"

# CPU/RAM
VM_CPUS="1"
VM_MEMORY_MB="1024"

# Final virtual disk capacity used during Stage 0B validation.
DISK_SIZE="16G"

# ------------------------------------------------------------
# Vagrant/libvirt box
# ------------------------------------------------------------

BOX_NAME="iot-ubuntu-2404-lab"
BOX_FILE="$OUTPUT_DIR/ubuntu-24.04-libvirt.box"

BOX_BUILD_DIR="$WORK_DIR/box-build"

# ------------------------------------------------------------
# Guest configuration
# ------------------------------------------------------------

VAGRANT_USER="vagrant"

# Private workload network used by Stage 0B validation.
PRIVATE_NETWORK="192.168.56.0/24"

TEST_PRIVATE_IP="192.168.56.10"
PEER_PRIVATE_IP="192.168.56.11"

# ------------------------------------------------------------
# Firmware
# ------------------------------------------------------------

OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
OVMF_VARS_TEMPLATE="/usr/share/OVMF/OVMF_VARS_4M.ms.fd"

# ------------------------------------------------------------
# Display configuration
# ------------------------------------------------------------

echo "Stage 0B reproducible-build configuration loaded."
echo "Stage root : $STAGE_ROOT"
echo "Build root : $REBUILD_ROOT"
echo "Box name   : $BOX_NAME"
echo "Disk size  : $DISK_SIZE"
