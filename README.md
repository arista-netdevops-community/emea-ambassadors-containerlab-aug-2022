# EMEA Ambassadors: Containerlab Session, Aug 2022

> This repository is a step-by-step guide explaining how to build the demo lab presented on the Arista EMEA Ambassadors session, Aug 2022.

- [EMEA Ambassadors: Containerlab Session, Aug 2022](#emea-ambassadors-containerlab-session-aug-2022)
  - [Prerequisites](#prerequisites)
  - [How to Create Ubuntu VM on KVM (Optional)](#how-to-create-ubuntu-vm-on-kvm-optional)
  - [Use VSCode Remote Development (Optional)](#use-vscode-remote-development-optional)
  - [Setup Docker on The Host](#setup-docker-on-the-host)
  - [Import cEOS image](#import-ceos-image)
  - [Clone The Lab Repository](#clone-the-lab-repository)

## Prerequisites

To build the lab an Ubuntu LTS VM is required.  We will be using Ubuntu Server 20.04 LTS in this guide.  
You can use a hypervisor of your choice, but this guide will only provide an example of deploying Ubuntu Cloud Image on KVM. The KVM hypervisor setup is not covered in this document. You can check [this repository](https://github.com/arista-netdevops-community/kvm-lab-for-network-engineers) to learn how to build a KVM lab host.

For this lab it is recommended to reserve minimum 8GB RAM and 4 cpu threads/vcpus. Only x86 CPUs are supported.

## How to Create Ubuntu VM on KVM (Optional)

> VMware and other hypervisors are not covered by this document, but can be used as well.

1. Get Ubuntu Cloud Image:

   ```bash
   wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
   ```

2. Set env variables:

    ```bash
    VM_IMAGE_DIR="/var/lib/libvirt/images"
    VM_NAME="ambassadors_clab"
    USERNAME="clab"
    PASSWORD="clab"
    ```

3. Convert image to qcow2 disk (5GB maximum):

    ```bash
    sudo mkdir $VM_IMAGE_DIR/$VM_NAME
    sudo qemu-img convert -f qcow2 -O qcow2 focal-server-cloudimg-amd64.img $VM_IMAGE_DIR/$VM_NAME/disk1.qcow2
    sudo qemu-img resize $VM_IMAGE_DIR/$VM_NAME/disk1.qcow2 5G
    ```

4. Create a file named cloud_init.cfg:

    ```bash
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
    ```

5. Create a file named network_static.cfg:

    ```bash
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
    ```

6. Install cloud image utils: `sudo apt update && sudo apt install cloud-image-utils -y`
7. Generate new image with cloud config: `sudo cloud-localds -v --network-config=$VM_IMAGE_DIR/$VM_NAME/network_static.cfg $VM_IMAGE_DIR/$VM_NAME/cdrom.iso $VM_IMAGE_DIR/$VM_NAME/cloud_init.cfg`
8. Create the VM:

    ```bash
    sudo virt-install --name $VM_NAME \
    --virt-type kvm --memory 8192 --vcpus 4 \
    --disk path=$VM_IMAGE_DIR/$VM_NAME/disk1.qcow2,device=disk \
    --disk path=$VM_IMAGE_DIR/$VM_NAME/cdrom.iso,device=cdrom \
    --os-type linux --os-variant ubuntu20.04 \
    --graphics none \
    --network network=default,model=virtio \
    --wait 0 \
    --import
    ```

9. Connect to the lab VM via console or SSH and execute the steps listed below on this VM.

## Use VSCode Remote Development (Optional)

You can use any terminal to connect to the lab VM via SSH or console. But it is highly recommended to use VSCode remote SSH development for the improved experience.

{{ to be continued if time allows }}

## Setup Docker on The Host

1. Install Docker: `sudo curl -fsSL https://get.docker.com | sh`
2. Add clab user to the docker group: `sudo usermod -aG docker ${USER}`
3. Logout and login again.
4. Check if Docker is installed correctly by running hello-world image: `docker run hello-world`

## Import cEOS image

1. Login to arista.com
2. Go to `Support > Software Download`
3. Select `EOS > Active Releases > 4.28 > EOS-4.28.1.1F > cEOS-lab`
4. Download `cEOS-lab-4.28.1.1F.tar.xz`

![Download cEOS](media/ceos-download.jpg)

5. Upload image to the lab VM. For example: `sftp clab@192.168.122.22:/home/clab <<< $'put cEOS-lab-4.28.1.1F.tar.xz'`
6. Go to the directory with the uploaded image and import the image: `docker import cEOS-lab-4.28.1.1F.tar.xz ceos-lab:4.28.1.1F`

> NOTE: you can also import the image with the tag latest to allow quick "upgrade" of those lab where specific version is not required: `docker tag ceos-lab:4.28.1.1F ceos-lab:latest`

## Clone The Lab Repository

```bash
clab@ubuntu:~$ pwd
/home/clab
clab@ubuntu:~$ git clone https://github.com/arista-netdevops-community/emea-ambassadors-containerlab-aug-2022.git
Cloning into 'emea-ambassadors-containerlab-aug-2022'...
remote: Enumerating objects: 42, done.
remote: Counting objects: 100% (42/42), done.
remote: Compressing objects: 100% (28/28), done.
remote: Total 42 (delta 13), reused 36 (delta 9), pack-reused 0
Unpacking objects: 100% (42/42), 91.41 KiB | 2.61 MiB/s, done.
clab@ubuntu:~$ ls
emea-ambassadors-containerlab-aug-2022
```

The lab setup diagram:

![lab diagram](media/lab_setup.png)
