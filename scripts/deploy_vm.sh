#!/bin/bash
# set env variables
echo ">>>>> 1. Setting env variables"
VM_IMAGE_DIR="/var/lib/libvirt/images"
VM_NAME="ambassadors_clab"
USERNAME="clab"
PASSWORD="clab"
URL_PREFIX="https://cloud-images.ubuntu.com/focal/current"
CLOUDIMG_NAME="focal-server-cloudimg-amd64.img"
TEMP_DIR="temp"
echo "Following env variables were set:"
echo "VM_IMAGE_DIR: $VM_IMAGE_DIR"
echo "VM_NAME: $VM_NAME"
echo "USERNAME: $USERNAME"
echo "PASSWORD: $PASSWORD"
echo "URL_PREFIX: $URL_PREFIX"
echo "CLOUDIMG_NAME: $CLOUDIMG_NAME"
echo "Done!"
# destroy old VM if it was already created
echo ">>>>> 2. Attempting to destroy old VM if it exists"
virsh destroy $VM_NAME && virsh undefine $VM_NAME
sudo rm -rf $VM_IMAGE_DIR/$VM_NAME
echo "Done!"
# check if image exists and download
echo ">>>>> 3. Downloading Ubuntu Cloud Image"
test -d $TEMP_DIR || mkdir $TEMP_DIR
test ! -e $TEMP_DIR/$CLOUDIMG_NAME && wget $URL_PREFIX/$CLOUDIMG_NAME -P $TEMP_DIR
sudo mkdir $VM_IMAGE_DIR/$VM_NAME
echo "Done!"
# create qemu image in VM_IMAGE_DIR and resize it
echo ">>>>> 4. Creating and resizing QEMU image"
sudo qemu-img convert -f qcow2 -O qcow2 $TEMP_DIR/$CLOUDIMG_NAME $VM_IMAGE_DIR/$VM_NAME/disk1.qcow2
sudo qemu-img resize $VM_IMAGE_DIR/$VM_NAME/disk1.qcow2 10G > /dev/null
echo "Done!"
# define cloud config
echo ">>>>> 5. Creating cloud config file: $VM_IMAGE_DIR/$VM_NAME/cloud_init.cfg"
sudo echo "#cloud-config
hostname: $VM_NAME
fqdn: $VM_NAME.lab.net
manage_etc_hosts: True
system_info:
  default_user:
    name: $USERNAME
    home: /home/$USERNAME
password: $PASSWORD
chpasswd:
  expire: False

# allow password auth
ssh_pwauth: True
" | sudo tee $VM_IMAGE_DIR/$VM_NAME/cloud_init.cfg > /dev/null
echo "Done!"
# define network config
echo ">>>>> 6. Creating network config file: $VM_IMAGE_DIR/$VM_NAME/network_static.cfg"
sudo echo """---
network:
  ethernets:
      enp1s0:
          dhcp4: false
          # and address from the default libvirt subnet
          # feel free to assign a different one
          addresses: [ 192.168.122.22/24 ]
          gateway4: 192.168.122.1
          nameservers:
            addresses: [ 8.8.8.8 ]
  version: 2
""" | sudo tee $VM_IMAGE_DIR/$VM_NAME/network_static.cfg > /dev/null
echo "Done!"
# build cdrom image with configs to boot VM
echo ">>>>> 7. Creating CDROM image: $VM_IMAGE_DIR/$VM_NAME/cdrom.iso"
sudo cloud-localds -v --network-config=$VM_IMAGE_DIR/$VM_NAME/network_static.cfg $VM_IMAGE_DIR/$VM_NAME/cdrom.iso $VM_IMAGE_DIR/$VM_NAME/cloud_init.cfg
# create VM
echo ">>>>> 8. Creating VM: $VM_NAME"
sudo virt-install --name $VM_NAME \
    --virt-type kvm --memory 8192 --vcpus 4 \
    --disk path=$VM_IMAGE_DIR/$VM_NAME/disk1.qcow2,device=disk \
    --disk path=$VM_IMAGE_DIR/$VM_NAME/cdrom.iso,device=cdrom \
    --os-type linux --os-variant ubuntu20.04 \
    --graphics none \
    --network network=default,model=virtio \
    --wait 0 \
    --import
echo "Done!"
