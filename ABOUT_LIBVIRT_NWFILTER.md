Played with libvirt network filters.

Goal 1: Test if i can actually lock myself out from ssh-ing into a vm using the nwfilter chains specifically the cleantraffic

Initial steps:
Get the vm's network xml. Notice in my Vagrant i specified the network name as k8s-network
<code>
sudo virsh dumpxml k8s-network > k8s-network.xml
</code>
I noticed that inside the xml there is a section called <filterref>
<code>
<interface type='network'>
  <!-- ... mac address, etc ... -->
  <filterref filter='clean-traffic'>
    <!-- This helps the filter know which IP to ALLOW -->
    <parameter name='IP' value='10.240.0.12'/>
  </filterref>
</interface>
</code>
 
I went further to actually modify the vm's xml for the specific node i targeted(worker-0) to test if i can actually lock myself out from ssh-ing into it.
For this to happen, i needed to know a couple of things:

1. The vm's name. I got this from <code>sudo virsh list --all</code> output was kubernetes-the-hard-way_worker-0 notice the way the folder name is part of the vm name
2. The vm's ip address. I got this from <code>sudo virsh domifaddr kubernetes-the-hard-way_worker-0</code>


Test1: Modify the vm's xml and use the ip parameter to actually see if i can spoof the ip address of the vm and lock myself out from ssh-ing into it.

<code>
sudo virsh edit kubernetes-the-hard-way_worker-0
</code>

Add the following line inside the <interface> section:
<code>
    <ip address='10.240.0.12' prefix='24'/>
</code>

Save and exit.

I used virsh to reboot the vm:
<code>
sudo virsh destroy kubernetes-the-hard-way_worker-0 
sudo virsh start kubernetes-the-hard-way_worker-0
</code>

I tried to ssh into the vm using the private key in the .vagrant folder but i was locked out. My ssh command was <code>ssh -i .vagrant/machines/worker-0/libvirt/private_key vagrant@10.240.0.12</code>

Confirmation part. 
To actually confirm that the nwfilter was responsible for the failed ssh session, i did the same process defined in step 1 but now used the ip from the  results of <code>sudo virsh domifaddr kubernetes-the-hard-way_worker-0</code> and added it to the vm's xml
This way, i matched the Host's expectations with the VM's reality- My worker-0 node was assigned 192.168.121.40 by the Vagrant/libirt DHCP server on the management interface(eth0). 

I tried  to ssh into my vm again and this time it worked. My ssh command was <code>ssh -i .vagrant/machines/worker-0/libvirt/private_key vagrant@192.168.121.40</code>

The previour failure: When i set the XML to 10.240.0.12, the libvirt clean-traffic droped all packets from the VM since theur source ip(192.168.121.40) did not match the ip in the XML(10.240.0.12)

Note on Vagrant-Libvirt Networking Layers
• Management Plane (eth0): The "hidden" interface. Used by Vagrant for SSH and provisioning. Usually on the `192.168.121.x` subnet.

• Data Plane (eth1): The "custom" interface. Defined in the `Vagrantfile`. This is the IP (e.g., `10.240.0.x`) i used for Kubernetes cluster traffic. I will bind this later to the kubernetes service(--apiserver-advertise-address) to keep management and cluster traffic isolated.

Separating the Management Plane from the Data Plane is a standard SRE practice. It ensures that even if a misconfigured Kubernetes CNI or a network loop crashes the "Data" network, you still have a dedicated "Management" backdoor to SSH into the node and fix it. This isolation prevents a "self-lockout" scenario and keeps maintenance traffic from interfering with production/cluster performance.