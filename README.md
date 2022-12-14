# EMEA Ambassadors: Containerlab Session, Aug 2022

> This repository is a step-by-step guide explaining how to build the demo lab presented on the Arista EMEA Ambassadors session, Aug 2022. The document is only focusing on cEOS use with Containerlab. For additional details please refer to [Containerlab documentation](https://containerlab.dev/quickstart/) or [GitHub repository](https://github.com/srl-labs/containerlab).  
> Appreciation to [Roman Dodin](https://netdevops.me) and other [cLab contributors](https://github.com/srl-labs/containerlab/graphs/contributors) for making the world a bit better place.

- [EMEA Ambassadors: Containerlab Session, Aug 2022](#emea-ambassadors-containerlab-session-aug-2022)
  - [Prerequisites](#prerequisites)
  - [How to Create Ubuntu VM on KVM (Optional)](#how-to-create-ubuntu-vm-on-kvm-optional)
  - [Setup Docker on The Host](#setup-docker-on-the-host)
  - [Import cEOS image](#import-ceos-image)
  - [Install Containerlab](#install-containerlab)
  - [Clone The Lab Repository](#clone-the-lab-repository)
  - [Deploy The Lab](#deploy-the-lab)
  - [Inspect the Lab and Connect to the Containers](#inspect-the-lab-and-connect-to-the-containers)
  - [Investigate Possible Privilege Caveats](#investigate-possible-privilege-caveats)
  - [Destroy the Lab](#destroy-the-lab)
  - [Deploy the Lab with Custom Startup Config](#deploy-the-lab-with-custom-startup-config)
  - [Make Packet Capture](#make-packet-capture)
  - [Containerlab in a Container](#containerlab-in-a-container)
  - [Building a Custom Container with cLab](#building-a-custom-container-with-clab)
  - [Ansible with Containerlab](#ansible-with-containerlab)
  - [Possible Scale Caveats](#possible-scale-caveats)
  - [References](#references)

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
    sudo qemu-img resize $VM_IMAGE_DIR/$VM_NAME/disk1.qcow2 10G
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

7. Confirm that the image was imported successfully:

    ```bash
    clab@ubuntu:~$ docker image ls
    REPOSITORY    TAG         IMAGE ID       CREATED         SIZE
    ceos-lab      4.28.1.1F   646c604b2596   9 hours ago     1.9GB
    ceos-lab      latest      646c604b2596   9 hours ago     1.9GB
    hello-world   latest      feb5d9fea6a5   10 months ago   13.3kB
    ```

## Install Containerlab

It's just a one-liner: `bash -c "$(curl -sL https://get.containerlab.dev)"`  
Refer to the [Containerlab quick start documentation](https://containerlab.dev/quickstart/) for the details.

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
clab@ubuntu:~$ cd emea-ambassadors-containerlab-aug-2022
clab@ubuntu:~/emea-ambassadors-containerlab-aug-2022$
```

## Deploy The Lab

The lab setup diagram:

![lab diagram](media/lab_setup.png)

Inspect `ambassadors_default_cfg.clab.yml` and deploy the lab:

```bash
sudo containerlab deploy --debug --topo ambassadors_default_cfg.clab.yml
```

This command will deploy containerlab with the default EOS configuration provided by containerlab. The `--debug` flag is optional, but provides additional information while Containerlab is starting.

> NOTE: If there is a single `.clab.yml` file in the current directory, it is possible to use `sudo containerlab deploy` command without specifying the topology file. As we have multiple files in the directory, we must specify the topology explicitly.

## Inspect the Lab and Connect to the Containers

Once the lab is ready, you'll see a table with the list of deployed containers, their host names and management IPs:

```text
+---+------------------------------+--------------+-----------------+------+---------+--------------------+--------------+
| # |             Name             | Container ID |      Image      | Kind |  State  |    IPv4 Address    | IPv6 Address |
+---+------------------------------+--------------+-----------------+------+---------+--------------------+--------------+
| 1 | clab-ambassadors_clab-a_host | 436eb12b6ebc | ceos-lab:latest | ceos | running | 192.168.123.100/24 | N/A          |
| 2 | clab-ambassadors_clab-leaf1  | 780403a150a9 | ceos-lab:latest | ceos | running | 192.168.123.21/24  | N/A          |
| 3 | clab-ambassadors_clab-leaf2  | 79dba4526c6b | ceos-lab:latest | ceos | running | 192.168.123.22/24  | N/A          |
| 4 | clab-ambassadors_clab-spine1 | af3b97f141fa | ceos-lab:latest | ceos | running | 192.168.123.11/24  | N/A          |
| 5 | clab-ambassadors_clab-spine2 | 1655913706d5 | ceos-lab:latest | ceos | running | 192.168.123.12/24  | N/A          |
+---+------------------------------+--------------+-----------------+------+---------+--------------------+--------------+
```

You can also list containers using docker command:

```bash
clab@ubuntu:~$ docker container ls
CONTAINER ID   IMAGE             COMMAND                  CREATED             STATUS             PORTS     NAMES
edbc03859477   ceos-lab:latest   "bash -c '/mnt/flash???"   About an hour ago   Up About an hour             clab-ambassadors_clab-spine2
c4cd010b2318   ceos-lab:latest   "bash -c '/mnt/flash???"   About an hour ago   Up About an hour             clab-ambassadors_clab-leaf2
29250cd4881e   ceos-lab:latest   "bash -c '/mnt/flash???"   About an hour ago   Up About an hour             clab-ambassadors_clab-spine1
32c576fcf575   ceos-lab:latest   "bash -c '/mnt/flash???"   About an hour ago   Up About an hour             clab-ambassadors_clab-leaf1
4d25882a1a08   ceos-lab:latest   "bash -c '/mnt/flash???"   About an hour ago   Up About an hour             clab-ambassadors_clab-a_host
```

You can call the table again any time with `sudo clab inspect -t ambassadors_default_cfg.clab.yml`.

Containerlab creates corresponding entries in the `/etc/hosts` file as well:

```bash
clab@ubuntu:~/emea-ambassadors-containerlab-aug-2022$ cat /etc/hosts | grep clab-
###### CLAB-ambassadors_clab-START ######
192.168.123.12  clab-ambassadors_clab-spine2
192.168.123.22  clab-ambassadors_clab-leaf2
192.168.123.11  clab-ambassadors_clab-spine1
192.168.123.21  clab-ambassadors_clab-leaf1
192.168.123.100 clab-ambassadors_clab-a_host
###### CLAB-ambassadors_clab-END ######
```

To access cEOS CLI you can:

1. SSH to the container. For ex.: `ssh admin@clab-ambassadors_clab-leaf1`. The default login is `admin` and password is `admin`
2. Connect to the "console" using Docker command. For ex.: `docker exec -it clab-ambassadors_clab-leaf1 Cli`

> NOTE: `docker exec -it clab-ambassadors_clab-leaf1 bash` allows to connect directly to the switch shell.

Do some lab verification. For example:

- Check the topology with `show lldp neighbors`
- Check running config with `show run`

## Investigate Possible Privilege Caveats

Containerlab requires root privilege to run. That also means that files and directories created by cLab will be owned by root user. This may cause troubles in certain cases.  
Let's investigate a theoretical case and try to commit the changes in the repository together with the directory generated by Containerlab.

Try `git add` for the directory generated by clab:

```bash
clab@ubuntu:~/emea-ambassadors-containerlab-aug-2022$ git add clab-ambassadors_clab/ -f
warning: could not open directory 'clab-ambassadors_clab/spine1/flash/debug/': Permission denied
warning: could not open directory 'clab-ambassadors_clab/spine1/flash/.extensions/': Permission denied
warning: could not open directory 'clab-ambassadors_clab/a_host/flash/debug/': Permission denied
warning: could not open directory 'clab-ambassadors_clab/a_host/flash/.extensions/': Permission denied
warning: could not open directory 'clab-ambassadors_clab/leaf2/flash/debug/': Permission denied
warning: could not open directory 'clab-ambassadors_clab/leaf2/flash/.extensions/': Permission denied
warning: could not open directory 'clab-ambassadors_clab/spine2/flash/debug/': Permission denied
warning: could not open directory 'clab-ambassadors_clab/spine2/flash/.extensions/': Permission denied
warning: could not open directory 'clab-ambassadors_clab/leaf1/flash/debug/': Permission denied
warning: could not open directory 'clab-ambassadors_clab/leaf1/flash/.extensions/': Permission denied
error: open("clab-ambassadors_clab/a_host/flash/persist/messages"): Permission denied
error: unable to index file 'clab-ambassadors_clab/a_host/flash/persist/messages'
fatal: adding files failed
```

It is technically possible to add files with sudo, but that will still cause issues with commit. `chown` is another possibility if the lab is inactive (otherwise it will keep updating files). But it's much better to avoid committing files and keep them in a different directory or add corresponding entries to `.gitignore`. Inspect `.gitignore` file for this repository with: `cat .gitignore | grep clab`

You may encounter similar "permission denied" errors in other cases. So, it's important to understand the root ownership challenge.

## Destroy the Lab

Destroy the lab with `sudo containerlab destroy -t ambassadors_default_cfg.clab.yml`  
This will stop all containers, but will keep the files created by clab for the next run. For example, startup-configs.  
Check the flash content for leaf1 and inspect it's startup config:

```bash
clab@ubuntu:~/emea-ambassadors-containerlab-aug-2022$ ls clab-ambassadors_clab/leaf1/flash/
AsuFastPktTransmit.log  SsuRestore.log        boot-config  fastpkttx.backup  kickstart-config  schedule        system_mac_address
Fossil                  SsuRestoreLegacy.log  debug        if-wait.sh        persist           startup-config
clab@ubuntu:~/emea-ambassadors-containerlab-aug-2022$ cat clab-ambassadors_clab/leaf1/flash/startup-config
```

To remove these files and have a clean environment on the next run, use `sudo containerlab destroy -t ambassadors_default_cfg.clab.yml --cleanup`

## Deploy the Lab with Custom Startup Config

Deploy the lab with the custom configuration:

```bash
sudo containerlab deploy -t ambassadors_custom_cfg.clab.yml --reconfigure
```

> NOTE: `--reconfigure` is required if `--cleanup` flag was not specified in the previous step. Otherwise custom startup configs will be ignored and configs in `clab-ambassadors_clab/` will be used instead.

Custom startup configs are located in the `init-configs` directory and assigned to every node using `startup-config:` key in the `ambassadors_custom_cfg.clab.yml`. This allows creating pre-configured labs. In this case pre-configured MLAG between leaf switches and basic BGP underlay configuration. Host should be able to ping loopbacks of all leaf and spine switches. Connect to the host to confirm that:

```bash
clab@ubuntu:~/emea-ambassadors-containerlab-aug-2022$ ssh admin@clab-ambassadors_clab-a_host
Password:
a_host>en
a_host#bash for i in {1..4}; do ping -c 4 10.${i}.${i}.${i}; done
```

Feel free to do some additional checks on leaf1 for example:

- `show ip bgp summary`
- `show mlag`
- `show port-channel dense`

> NOTE: `ambassadors_custom_cfg.clab.yml` has custom interface mapping defined in `interface_mapping.json` and assigned to cEOS-lab containers as bind mount. This helps to change default Management0 interface to Management1 as on physical switches.

## Make Packet Capture

Every container has it's own namespace. To list all interfaces for leaf1, execute following command on the lab VM:

```bash
sudo ip netns exec clab-ambassadors_clab-leaf1 ip link
```

Run following command and wait a few minutes to capture a BGP packets:

```bash
sudo ip netns exec clab-ambassadors_clab-leaf1 tcpdump -nni eth1_1 port 179 -vvv
```

For additional details about packet capture check [cLab documentation](https://containerlab.dev/manual/wireshark/).

## Containerlab in a Container

Destroy the lab with cleanup flag: `sudo containerlab destroy -t ambassadors_custom_cfg.clab.yml --cleanup`

It is possible to run the containerlab on the host without installing it. For that a Docker container with cLab can be executed on a Docker host.  
This can be helpful to run Containerlab on an Intel-based Mac Book or in some special cases.

Test that by running following command:

```bash
docker run --rm -it --privileged \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/hosts:/etc/hosts \
  --pid="host" \
  -w $(pwd) \
  -v $(pwd):$(pwd) \
  ghcr.io/srl-labs/clab bash
```

This will start the container with cLab interactively. Once inside the container prompt, execute the following command to start the lab:

```bash
containerlab deploy -t ambassadors_custom_cfg.clab.yml --reconfigure
```

Check the lab and destroy it: `containerlab destroy -t ambassadors_custom_cfg.clab.yml --cleanup`  
Exit the container.

The default `ghcr.io/srl-labs/clab` container is making all changes as root. That can cause permissions issues if you are working with your repository from the container prompt. It is better to use `ghcr.io/srl-labs/clab` as non-interactive or craft your own container to map the user ID correctly.

To use the container in non-interactive way execute following command:

```bash
docker run --rm --privileged \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/hosts:/etc/hosts \
  --pid="host" \
  -w $(pwd) \
  -v $(pwd):$(pwd) \
  ghcr.io/srl-labs/clab containerlab deploy -t ambassadors_custom_cfg.clab.yml --reconfigure
```

To destroy the lab:

```bash
docker run --rm --privileged \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/hosts:/etc/hosts \
  --pid="host" \
  -w $(pwd) \
  -v $(pwd):$(pwd) \
  ghcr.io/srl-labs/clab containerlab destroy -t ambassadors_custom_cfg.clab.yml --cleanup
```

## Building a Custom Container with cLab

It is possible to build a custom container with Containerlab installed. We are not going to discuss in detail how to build Docker containers, but required `Dockerfile`, `entrypoint.sh` and `gitconfig` are already present in this repository. There is also `updateUID.Dockerfile` that allows to change user id inside the container to match UID of the VM user. That is not required for our lab, but can a critical requirement in certain cases. For example, CentOS is very strict regarding user IDs.

The custom container has following features:

- ZSH and a nice prompt with a whale. =)
- Number of Linux tools pre-installed.
- Docker (in Docker) and Containerlab installed
- Aliases to start and stop the lab and connect to the lab switches
- Entrypoint
- UID and GID inside the container matching UID and GID outside the container
- Ansible included

Let's build our own container now:

```bash
# build a temp container with UID 1000
docker build --rm --pull --no-cache -f Dockerfile -t ambassadors_temp_image .
# build final container with matching UID
docker build -f updateUID.Dockerfile -t ambassadors_clab:latest --build-arg BASE_IMAGE=ambassadors_temp_image --build-arg REMOTE_USER=clab --build-arg NEW_UID=$(id -u) --build-arg NEW_GID=$(id -g) --build-arg IMAGE_USER=clab .
```

Start the container:

```bash
docker run --rm -it --privileged \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/hosts:/etc/hosts \
  --pid="host" \
  -w $(pwd) \
  -v $(pwd):$(pwd) \
  ambassadors_clab:latest
```

Test container features:

- start the lab: `lab_start`
- connect to leaf1: `leaf1`
- stop the lab: `lab_stop`

Custom container can be very useful if you have special requirements or want to create an environment with all dependencies pre-installed and minimum actions required from the user to start the lab. Example: [avd-quickstart-containerlab](https://github.com/arista-netdevops-community/avd-quickstart-containerlab)

## Ansible with Containerlab

When containerlab starts it automatically creates Ansible inventory that can be used to automate certain tasks in the lab.  
Start `ambassadors_clab:latest` container we have created earlier and deploy the lab.  
Inspect the Ansible inventory: `cat clab-ambassadors_clab/ansible-inventory.yml`  
Ansible is already installed inside the container and ansible.cfg is provided in the repository as well as the playbook `check_the_lab.yml`.
Run the playbook by executing command `ansible-playbook playbooks/check_the_lab.yml`  
This playbook will execute number of show commands on all switches in the lab and present output on the screen.

## Possible Scale Caveats

> WARNING: If you are planning to deploy a high scale lab, test it on a non-production host that you can access and recover any time. Incorrectly deployed Containerlab at scale can bring your host down due to high CPU utilization on start.

Generally, Ubuntu systems have quite low `fs.inotify.max_user_instances` limit by default. Even if it was increased, older cEOS-lab containers can decrease system limit to 1256. That is not sufficient for a high scale lab. The lab may fail to start and even bring your host down due to high CPU.

In reality increasing inotify limit on a modern host with high RAM will not create any disadvantages. If you are planning to deploy older cEOS-lab container, you can increase it manually.

1st, define your inotify limit. You can safely assume that it will not be more than 1256*number of containers. But the required limit is expected to be significantly below that. Newer cEOS-lab images set the limit to 62800, that is a good number for most cLab deployments.

Set your system limit: `sudo sysctl -w fs.inotify.max_user_instances=62800`

Create 99-zceos.conf: `sudo sh -c 'echo "fs.inotify.max_user_instances = 62800" > /etc/sysctl.d/99-zceos.conf'`

Check the limit: `sudo sysctl -a  | grep -i inotify`

Mount the custom 99-zceos.conf to your cEOS-lab containers in the topology file:

```yaml
topology:
  kinds:
    ceos:
      binds:
        - /etc/sysctl.d/99-zceos.conf:/etc/sysctl.d/99-zceos.conf:ro
```

Add `--max-workers` and `--timeout` flags to your containerlab deploy command.

> NOTE: as of 4.28 default cEOS-lab 99-zceos.conf was updated and configures fs.inotify.max_user_instances to 62800. It is recommended to use cEOS-lab 4.28 or higher and Ubuntu 20LTS or higher. Nevertheless, always test your lab environment first, check inotify limits and set `--max-workers` and `--timeout` flags for a high scale deployment.  
> GOOD TO KNOW: inotify is also the main reason why cEOS-lab will not work on M1 Mac.

## References

- [avd-quickstart-containerlab](https://github.com/arista-netdevops-community/avd-quickstart-containerlab)
- [avd-all-in-one-container](https://github.com/arista-netdevops-community/avd-all-in-one-container)
- [avd-cEOS-Lab](https://github.com/arista-netdevops-community/avd-cEOS-Lab)
- [kvm-lab-for-network-engineers](https://github.com/arista-netdevops-community/kvm-lab-for-network-engineers)
- [Containerlab documentation](https://containerlab.dev)
