# Vagrant Lab Troubleshooting Guide
## Context: Debian 13 + KVM + CKA Preparation

### Prerequisites Installation
```bash
# After installing vagrant via apt, you MUST install the plugin
# but it requires build tools (not installed by default on Debian)
sudo apt install -y build-essential libvirt-dev pkg-config nfs-kernel-server
vagrant plugin install vagrant-libvirt

# Set default provider to avoid --provider=libvirt flag every time
echo 'export VAGRANT_DEFAULT_PROVIDER=libvirt' &gt;&gt; ~/.bashrc
source ~/.bashrc