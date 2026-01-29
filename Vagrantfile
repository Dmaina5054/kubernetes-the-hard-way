# -*- mode: ruby -*-
#vi set ft=ruby

Vagrant.configure("2") do |config|
    config.vm.box = "debian/bookworm64"

    #jumpbox setup
    config.vm.define "jumpbox" do |jumpbox|
        jumpbox.vm.hostname = "jumpbox"
        jumpbox.vm.network "private_network", ip: "10.240.0.10"
        jumpbox.vm.provider "virtualbox" do |vb|
            vb.memory = "512"
            vb.cpus = "1"
        end
    end

    #2. Server Control Plane 
    config.vm.define "server" do |server|
        server.vm.hostname = "server"
        server.vm.network "private_network", ip: "10.240.0.11"
        server.vm.provider "virtualbox" do |vb|
            vb.memory = "2048"
            vb.cpus = "1"
        end
    end

    #3. Worker Node0
    config.vm.define "worker-0" do |worker|
        worker.vm.hostname = "worker-0"
        worker.vm.network "private_network", ip: "10.240.0.12"
        worker.vm.provider "virtualbox" do |vb|
            vb.memory = "2048"
            vb.cpus = "1"
        end
    end

    #4. Worker Node1
    config.vm.define "worker-1" do |worker|
        worker.vm.hostname = "worker-1"
        worker.vm.network "private_network", ip: "10.240.0.13"
        worker.vm.provider "virtualbox" do |vb|
            vb.memory = "2048"
            vb.cpus = "1"
        end
    end
end
