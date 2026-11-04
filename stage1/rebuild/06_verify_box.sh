#!/usr/bin/env bash

# ============================================================
# MILESTONE 6 — Verify rebuilt Vagrant box with two fresh VMs
#
# Purpose:
#   Prove that the reproducibly built box works when cloned
#   into two independent Vagrant/libvirt machines.
#
# Verification covers:
#   - Vagrant-managed VM creation
#   - subject-oriented resources: 1 CPU / 1024 MB RAM
#   - successful SSH bootstrap and Vagrant key replacement
#   - passwordless sudo
#   - unique machine identities
#   - unique NAT-management IP addresses
#   - dedicated private IPs:
#         verify-a = 192.168.56.10
#         verify-b = 192.168.56.11
#   - bidirectional VM-to-VM communication
#
# On success:
#   Both disposable verification VMs are destroyed.
#
# On failure:
#   VMs are intentionally preserved for troubleshooting.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00_config.sh"

VERIFY_DIR="$WORK_DIR/verify"
VAGRANTFILE="$VERIFY_DIR/Vagrantfile"

echo "=== Milestone 6: Verify rebuilt Vagrant box ==="

# ------------------------------------------------------------
# Pre-checks
# ------------------------------------------------------------

command -v vagrant >/dev/null || {
    echo "ERROR: vagrant is required."
    exit 1
}

command -v virsh >/dev/null || {
    echo "ERROR: virsh is required."
    exit 1
}

[[ -f "$OVMF_CODE" ]] || {
    echo "ERROR: OVMF firmware not found: $OVMF_CODE"
    exit 1
}

[[ -f "$OVMF_VARS_TEMPLATE" ]] || {
    echo "ERROR: OVMF VARS template not found."
    exit 1
}

# ------------------------------------------------------------
# Remove leftovers from an interrupted previous verification.
#
# A failed verification may exit before Vagrant reaches its
# normal cleanup step. Because these domains are disposable,
# remove only the two known verification domains before
# starting a fresh test.
# ------------------------------------------------------------

for DOMAIN in verify_verify-a verify_verify-b; do
    if virsh -c qemu:///system dominfo "$DOMAIN" >/dev/null 2>&1; then
        echo "Removing leftover verification domain: $DOMAIN"

        virsh -c qemu:///system destroy "$DOMAIN" \
            >/dev/null 2>&1 || true

        virsh -c qemu:///system undefine "$DOMAIN" \
            --nvram \
            --remove-all-storage \
            >/dev/null 2>&1 || true
    fi
done

# ------------------------------------------------------------
# Prepare a completely fresh verification environment
# ------------------------------------------------------------

rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"

cp "$OVMF_VARS_TEMPLATE" "$VERIFY_DIR/verify-a_VARS.fd"
cp "$OVMF_VARS_TEMPLATE" "$VERIFY_DIR/verify-b_VARS.fd"

# ------------------------------------------------------------
# Build temporary multi-machine Vagrantfile
#
# Both VMs have:
#   NIC 1 -> libvirt default NAT management network
#   NIC 2 -> isolated iot-private network
#
# Management IPs are obtained through DHCP.
# Private workload IPs are fixed and independent of DHCP.
# ------------------------------------------------------------

cat > "$VAGRANTFILE" <<VAGRANT
Vagrant.configure("2") do |config|
  config.vm.box = "$BOX_NAME"

  config.ssh.username = "vagrant"
  config.ssh.insert_key = true
  config.vm.boot_timeout = 900

  config.vm.define "verify-a" do |node|
    node.vm.hostname = "iot-verify-a"

    node.vm.network "private_network",
      ip: "$TEST_PRIVATE_IP",
      libvirt__network_name: "iot-private",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false

    node.vm.provider "libvirt" do |libvirt|
      libvirt.qemu_use_session = false
      libvirt.storage_pool_name = "stage1"

      libvirt.cpus = $VM_CPUS
      libvirt.memory = $VM_MEMORY_MB

      libvirt.management_network_name = "default"
      libvirt.management_network_address = "192.168.122.0/24"
      libvirt.management_network_keep = true

      libvirt.machine_type = "pc-q35-noble"
      libvirt.loader = "$OVMF_CODE"
      libvirt.nvram = File.expand_path("verify-a_VARS.fd", __dir__)
    end
  end

  config.vm.define "verify-b" do |node|
    node.vm.hostname = "iot-verify-b"

    node.vm.network "private_network",
      ip: "$PEER_PRIVATE_IP",
      libvirt__network_name: "iot-private",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false

    node.vm.provider "libvirt" do |libvirt|
      libvirt.qemu_use_session = false
      libvirt.storage_pool_name = "stage1"

      libvirt.cpus = $VM_CPUS
      libvirt.memory = $VM_MEMORY_MB

      libvirt.management_network_name = "default"
      libvirt.management_network_address = "192.168.122.0/24"
      libvirt.management_network_keep = true

      libvirt.machine_type = "pc-q35-noble"
      libvirt.loader = "$OVMF_CODE"
      libvirt.nvram = File.expand_path("verify-b_VARS.fd", __dir__)
    end
  end
end
VAGRANT

cd "$VERIFY_DIR"

# ------------------------------------------------------------
# Validate Vagrant configuration before creating VMs
# ------------------------------------------------------------

vagrant validate

# ------------------------------------------------------------
# Boot two completely fresh clones
# ------------------------------------------------------------

echo
echo "Starting verification VMs..."

vagrant up --provider=libvirt

# ------------------------------------------------------------
# Verify SSH and passwordless sudo
# ------------------------------------------------------------

echo
echo "=== SSH / sudo verification ==="

echo "verify-a:"
vagrant ssh verify-a -c '
    test "$(whoami)" = "vagrant"
    test "$(sudo -n whoami)" = "root"
    echo "SSH user: vagrant"
    echo "sudo user: root"
'

echo

echo "verify-b:"
vagrant ssh verify-b -c '
    test "$(whoami)" = "vagrant"
    test "$(sudo -n whoami)" = "root"
    echo "SSH user: vagrant"
    echo "sudo user: root"
'

# ------------------------------------------------------------
# Verify machine identities are unique
#
# This specifically protects against the cloned machine-id
# problem discovered during Stage 0B, where multiple VMs
# received the same DHCP client identity.
# ------------------------------------------------------------

A_MACHINE_ID="$(vagrant ssh verify-a -c 'cat /etc/machine-id' | tr -d '\r')"
B_MACHINE_ID="$(vagrant ssh verify-b -c 'cat /etc/machine-id' | tr -d '\r')"

echo
echo "=== Machine identities ==="
echo "verify-a: $A_MACHINE_ID"
echo "verify-b: $B_MACHINE_ID"

if [[ -z "$A_MACHINE_ID" || -z "$B_MACHINE_ID" ]]; then
    echo "ERROR: A runtime machine-id is empty."
    exit 1
fi

if [[ "$A_MACHINE_ID" == "$B_MACHINE_ID" ]]; then
    echo "ERROR: Cloned VMs have identical machine-id values."
    exit 1
fi

# ------------------------------------------------------------
# Verify private interface addresses
# ------------------------------------------------------------

echo
echo "=== Private IP verification ==="

A_PRIVATE="$(vagrant ssh verify-a -c \
    "ip -4 -o addr show | awk '\$4 ~ /^192\\.168\\.56\\./ {print \$4}'" |
    tr -d '\r')"

B_PRIVATE="$(vagrant ssh verify-b -c \
    "ip -4 -o addr show | awk '\$4 ~ /^192\\.168\\.56\\./ {print \$4}'" |
    tr -d '\r')"

echo "verify-a: $A_PRIVATE"
echo "verify-b: $B_PRIVATE"

[[ "$A_PRIVATE" == "$TEST_PRIVATE_IP/24" ]] || {
    echo "ERROR: verify-a private IP is incorrect."
    exit 1
}

[[ "$B_PRIVATE" == "$PEER_PRIVATE_IP/24" ]] || {
    echo "ERROR: verify-b private IP is incorrect."
    exit 1
}

# ------------------------------------------------------------
# Verify unique management IP addresses
# ------------------------------------------------------------

A_MGMT="$(vagrant ssh verify-a -c \
    "ip -4 -o addr show | awk '\$4 ~ /^192\\.168\\.122\\./ {print \$4}'" |
    tr -d '\r')"

B_MGMT="$(vagrant ssh verify-b -c \
    "ip -4 -o addr show | awk '\$4 ~ /^192\\.168\\.122\\./ {print \$4}'" |
    tr -d '\r')"

echo
echo "=== Management IP verification ==="
echo "verify-a: $A_MGMT"
echo "verify-b: $B_MGMT"

if [[ -z "$A_MGMT" || -z "$B_MGMT" ]]; then
    echo "ERROR: Missing management IP."
    exit 1
fi

if [[ "$A_MGMT" == "$B_MGMT" ]]; then
    echo "ERROR: Management IP collision detected."
    exit 1
fi

# ------------------------------------------------------------
# Verify VM-to-VM communication on private network
# ------------------------------------------------------------

echo
echo "=== Private network communication ==="

vagrant ssh verify-a -c "ping -c 3 $PEER_PRIVATE_IP"
vagrant ssh verify-b -c "ping -c 3 $TEST_PRIVATE_IP"

# ------------------------------------------------------------
# Success
# ------------------------------------------------------------

echo
echo "Milestone 6 PASSED."
echo "Two fresh Vagrant clones verified successfully."

# These VMs exist only to prove reproducibility.
echo
echo "Destroying disposable verification VMs..."
vagrant destroy -f
