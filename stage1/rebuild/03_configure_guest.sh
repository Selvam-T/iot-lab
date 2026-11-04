#!/usr/bin/env bash

# ============================================================
# MILESTONE 3 — Configure reusable Vagrant guest
#
# Purpose:
#   Convert the expanded Ubuntu cloud image into a reusable
#   Vagrant/libvirt guest image.
#
# This milestone configures:
#   - vagrant user
#   - passwordless sudo
#   - Vagrant bootstrap SSH public key
#   - generic DHCP management networking
#   - per-VM SSH host-key generation
#   - machine-id generalization for safe cloning
#
# Important lessons from Stage 0B:
#
# 1. SSH host private keys must NOT be baked into the box.
#    Each clone generates its own keys using ssh-keygen -A.
#
# 2. ssh-keygen must run BEFORE sshd -t. Otherwise sshd
#    validation fails because no host keys exist yet.
#
# 3. /etc/machine-id must be empty in the reusable image.
#    Otherwise cloned VMs can present the same DHCP client ID
#    and receive conflicting management IP addresses.
#
# 4. The generic DHCP NIC is marked optional so a second
#    Vagrant private NIC with DHCP disabled does not cause
#    systemd-networkd-wait-online to delay boot.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00_config.sh"

echo "=== Milestone 3: Configure reusable Vagrant guest ==="

# ------------------------------------------------------------
# Pre-checks
# ------------------------------------------------------------

[[ -f "$WORK_IMAGE" ]] || {
    echo "ERROR: Working image not found."
    echo "Run ./02_prepare_disk.sh first."
    exit 1
}

command -v virt-customize >/dev/null || {
    echo "ERROR: virt-customize is required."
    exit 1
}

# ------------------------------------------------------------
# Locate Vagrant's standard bootstrap public key
#
# Do not copy any private key into the image.
# Vagrant initially authenticates with this public key and,
# because config.ssh.insert_key=true, replaces it with a
# freshly generated key during the first successful boot.
# ------------------------------------------------------------

VAGRANT_PUB_KEY="$(
    find /opt/vagrant/embedded/gems/gems \
        -path '*/keys/vagrant.pub' \
        -type f 2>/dev/null |
    sort -V |
    tail -1
)"

if [[ -z "$VAGRANT_PUB_KEY" || ! -f "$VAGRANT_PUB_KEY" ]]; then
    echo "ERROR: Vagrant bootstrap public key not found."
    exit 1
fi

echo "Vagrant bootstrap key: $VAGRANT_PUB_KEY"

# ------------------------------------------------------------
# Prepare configuration files on L1
# ------------------------------------------------------------

AUTHORIZED_KEYS="$WORK_DIR/vagrant_authorized_keys"
NETPLAN_FILE="$WORK_DIR/90-vagrant-dhcp.yaml"
SSH_DROPIN="$WORK_DIR/10-hostkeys.conf"

cp "$VAGRANT_PUB_KEY" "$AUTHORIZED_KEYS"

cat > "$NETPLAN_FILE" <<'NETPLAN'
network:
  version: 2
  renderer: networkd
  ethernets:
    vagrant-dhcp:
      match:
        name: "en*"
      dhcp4: true
      dhcp6: false
      optional: true
NETPLAN

cat > "$SSH_DROPIN" <<'SSHCONF'
[Service]

# Clear Ubuntu's original ExecStartPre validation order.
ExecStartPre=

# A reusable VM image must not contain cloned SSH host keys.
# Generate missing keys separately inside every new VM.
ExecStartPre=/usr/bin/ssh-keygen -A

# Validate sshd only after the host keys now exist.
ExecStartPre=/usr/sbin/sshd -t
SSHCONF

# ------------------------------------------------------------
# Configure guest filesystem
# ------------------------------------------------------------

echo "Configuring guest..."

sudo virt-customize -a "$WORK_IMAGE" \
    --run-command 'id -u vagrant >/dev/null 2>&1 || useradd --create-home --user-group --shell /bin/bash vagrant' \
    --run-command 'passwd -l vagrant >/dev/null 2>&1 || true' \
    --mkdir '/home/vagrant/.ssh' \
    --upload "$AUTHORIZED_KEYS:/home/vagrant/.ssh/authorized_keys" \
    --run-command 'chown -R vagrant:vagrant /home/vagrant/.ssh' \
    --run-command 'chmod 700 /home/vagrant/.ssh' \
    --run-command 'chmod 600 /home/vagrant/.ssh/authorized_keys' \
    --write '/etc/sudoers.d/vagrant:vagrant ALL=(ALL) NOPASSWD:ALL' \
    --chmod '0440:/etc/sudoers.d/vagrant' \
    --upload "$NETPLAN_FILE:/etc/netplan/90-vagrant-dhcp.yaml" \
    --run-command 'chown root:root /etc/netplan/90-vagrant-dhcp.yaml' \
    --run-command 'chmod 600 /etc/netplan/90-vagrant-dhcp.yaml' \
    --mkdir '/etc/systemd/system/ssh.service.d' \
    --upload "$SSH_DROPIN:/etc/systemd/system/ssh.service.d/10-hostkeys.conf" \
    --run-command 'chown root:root /etc/systemd/system/ssh.service.d/10-hostkeys.conf' \
    --run-command 'chmod 644 /etc/systemd/system/ssh.service.d/10-hostkeys.conf' \
    --run-command 'rm -f /etc/ssh/ssh_host_*' \
    --run-command 'truncate -s 0 /etc/machine-id'

sudo chown "$(id -u):$(id -g)" "$WORK_IMAGE"

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------

echo
echo "=== Verify machine-id ==="

MACHINE_ID_BYTES="$(
    sudo virt-cat -a "$WORK_IMAGE" /etc/machine-id | wc -c
)"

echo "machine-id bytes: $MACHINE_ID_BYTES"

if [[ "$MACHINE_ID_BYTES" -ne 0 ]]; then
    echo "ERROR: machine-id was not generalized."
    exit 1
fi

echo
echo "=== Verify sudo configuration ==="
sudo virt-cat -a "$WORK_IMAGE" /etc/sudoers.d/vagrant

echo
echo "=== Verify Netplan ==="
sudo virt-cat -a "$WORK_IMAGE" /etc/netplan/90-vagrant-dhcp.yaml

echo
echo "=== Verify SSH startup ordering ==="
sudo virt-cat -a "$WORK_IMAGE" \
    /etc/systemd/system/ssh.service.d/10-hostkeys.conf

echo
echo "=== QCOW2 integrity ==="
qemu-img check "$WORK_IMAGE"

echo
echo "Milestone 3 PASSED."
echo "Configured image: $WORK_IMAGE"
