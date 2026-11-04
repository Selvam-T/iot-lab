#!/usr/bin/env bash

# ============================================================
# STAGE 0B — Complete reproducible Vagrant box rebuild
#
# Purpose:
#   Execute every validated Stage 0B build milestone in order.
#
# Milestones:
#   0. Load shared configuration
#   1. Download + SHA256 verify Ubuntu base image
#   2. Create + expand 16 GiB working QCOW2
#   3. Configure reusable Vagrant guest
#   4. Package libvirt Vagrant box
#   5. Register rebuilt box
#   6. Verify with two fresh Vagrant clones
#
# sudo:
#   libguestfs operations require elevated privileges in this
#   L1 environment. sudo -v authenticates once before the
#   build begins so individual milestones normally do not
#   repeatedly prompt for the password.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================================"
echo " Stage 0B — Reproducible Vagrant Box Build"
echo "============================================================"
echo

echo "This build requires sudo for libguestfs operations."
sudo -v

echo
echo ">>> Milestone 0 — Configuration"
./00_config.sh

echo
echo ">>> Milestone 1 — Download and verify Ubuntu image"
./01_download_image.sh

echo
echo ">>> Milestone 2 — Prepare working disk"
./02_prepare_disk.sh

echo
echo ">>> Milestone 3 — Configure reusable guest"
./03_configure_guest.sh

echo
echo ">>> Milestone 4 — Package Vagrant box"
./04_package_box.sh

echo
echo ">>> Milestone 5 — Register Vagrant box"
./05_register_box.sh

echo
echo ">>> Milestone 6 — Verify fresh clones"
./06_verify_box.sh

echo
echo "============================================================"
echo " STAGE 0B REPRODUCIBLE BUILD PASSED"
echo "============================================================"
