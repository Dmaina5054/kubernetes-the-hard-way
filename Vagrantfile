# -*- mode: ruby -*-
#vi set ft=ruby
# CKA Lab - Kubernetes The Hard Way
# Infrastructure: Debian 13 (Trixie) + KVM/QEMU/libvirt
# Storage: LVM bind mount /var/lib/libvirt/images -> /home/vm-storage 

# NFS GOTCHA #1:
  # vagrant-libvirt defaults to NFS for synced folders.
  # This fails without nfs-kernel-server installed.
  # KTHW doesn't need file sharing - disable it entirely.
Vagrant.configure("2") do |config|
    config.vm.box = "debian/bookworm64"
    config.vm.synced_folder ".", "/vagrant", disabled: true
    

    # JUMPBOX (Bastion/Admin node)
    # NETWORK GOTCHA #1:
  # - Use 'ip:' (sets VM static IP), NOT 'libvirt_host_ip' (sets host bridge IP)
  # - First VM must define network params (address, dhcp), others only attach
#-------------------------------------------------------------------#
  # NETWORK GOTCHA #2:
    # libvirt__network_address defines the subnet - required even with static IPs
    # Without it: "nat forwarding requested but no IP address provided for network"
    # CRITICAL: KTHW requires static-only IPs
    #-------------------------------------------------------------------#
    config.vm.define "jumpbox" do |jumpbox|
        jumpbox.vm.hostname = "jumpbox"
        jumpbox.vm.network "private_network", ip: "10.240.0.10", libvirt__network_name: "k8s-network",libvirt__network_address: "10.240.0.0/24", libvirt__dhcp_enabled: false
        jumpbox.vm.provider "libvirt" do |libvirt|
            libvirt.qemu_use_session =  false
            libvirt.cpu_mode = "host-passthrough"
            libvirt.memory = "512"
            libvirt.cpus = "1"
        end
    end

    # CONTROL PLANE
  # NETWORK GOTCHA #3:
  # Do NOT repeat libvirt__network_address or dhcp settings here.
  # Subsequent VMs only need 'ip:' and 'libvirt__network_name' to join.
  #-------------------------------------------------------------------#
    config.vm.define "server" do |server|
        server.vm.hostname = "server"
        server.vm.network "private_network", ip: "10.240.0.11" ,libvirt__network_name: "k8s-network", libvirt__dhcp_enabled: false
        server.vm.provider "libvirt" do |libvirt|
            libvirt.cpu_mode = "host-passthrough"
            libvirt.memory = "2048"
            libvirt.cpus = "1"
        end
    end

    #3. Worker Node0
    config.vm.define "worker-0" do |worker|
        worker.vm.hostname = "worker-0"
        worker.vm.network "private_network", ip: "10.240.0.12", libvirt__network_name: "k8s-network", libvirt__dhcp_enabled: false
        worker.vm.provider "libvirt" do |libvirt|
            libvirt.cpu_mode = "host-passthrough"
            libvirt.memory = "2048"
            libvirt.cpus = "1"
        end
    end

    #4. Worker Node1
    config.vm.define "worker-1" do |worker|
        worker.vm.hostname = "worker-1"
        worker.vm.network "private_network", ip: "10.240.0.13", libvirt__network_name: "k8s-network", libvirt__dhcp_enabled: false
        worker.vm.provider "libvirt" do |libvirt|
            libvirt.cpu_mode = "host-passthrough"
            libvirt.memory = "2048"
            libvirt.cpus = "1"
        end
    end
end
