#!/bin/sh
VM=someimage
VCPU=1
MEMORY=1024
BRIDGE=bridge0
DISKSIZE=20G
DOMAIN=middleearth

# Create meta-data
cat << EOF > meta-data
instance-id: $VM
local-hostname: $VM
EOF

# Create user-data
cat << EOF > user-data
#cloud-config
preserve_hostname: False
hostname: $VM
fqdn: $VM.$DOMAIN
ssh_authorized_keys:
  - $SSH_PUBLIC_KEY 
output:
  all: ">> /var/log/cloud-init.log"
timezone: Europe/London
runcmd:
  - systemctl stop network && systemctl start network
  - yum -y remove cloud-init
  - yum -y install avahi
  - systemctl enable --now avahi-daemon
EOF

# Create image:
qemu-img create -f qcow2 -o preallocation=metadata $VM.qcow2 $DISKSIZE
virt-resize --expand /dev/sda1 /data/vm_images/CentOS-7-x86_64-GenericCloud.qcow2 $VM.qcow2

# Create cloud-init.iso
mkisofs -o $VM-config.iso -V cidata -J -r user-data meta-data

# Create storage pool
virsh pool-create-as --name $VM --type dir --target /var/lib/libvirt/images/$VM

# Create virtual machine
virt-install --import --name $VM \
--memory $MEMORY --vcpus $VCPU --cpu host \
--disk $VM.qcow2,format=qcow2,bus=virtio \
--disk $VM-config.iso,device=cdrom \
--network bridge=$BRIDGE,model=virtio \
--os-type=linux \
--os-variant=centos7.0 \
--graphics none \
--noautoconsole

