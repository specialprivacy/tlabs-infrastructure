# Special Demo Environment Infrastructure
This repository contains the code which will provision the infrastructure for demo environment for the SPECIAL platform. The infrastructure is constructed using (terraform)[https://www.terraform.io].

## Description
The scripts will create a cluster of 3 VMS:
* 1 root VM which will also act as a bastion server. This is the node from which we'll bootstrap the swarm cluster.
* 2 master VMs. These are only exposed to the internal network.

All machines run coreos and will install their own operating system updates. Additional machines can be added by changing the count of their type in the terraform files.
A swarm cluster should probably never have more than 5 manager nodes, so initially try added worker nodes.

The script will also install docker swarm mode onto the machines and join them into the existing cluster. The cluster will be mostly fault tolerant, however terraform will get confused if the root machine dies.
It will try to recreate it, but the script that provisions docker swarm will fail as a cluster already exists. So after using this script for the first time, the provisioner exec line should be changed to the same script that provisions a manager.

## Prerequisites
In order for the scripts to run, a working OpenStack account, along with information about the OpenStack installation needs to be avialable. This information is passed in either as environment variables to the terraform command or in a `terraform.tfvars` file in the project directory.
For more information about the configuration of the terraform openstack provider, look here: https://www.terraform.io/docs/providers/openstack/index.html

## Build
The examples here will assume a linux / unix environment, but the steps should work on every platform.
1. Download and install terraform from https://www.terraform.io/download.html
2. Clone this repository and move to it
```bash
git clone https://git.ai.wu.ac.at/specialprivacy/infrastructure.git
```
3. Initialize terraform (downloads providers)
```bash
terraform init
```
4. Download the ct tool
```bash
wget https://github.com/coreos/container-linux-config-transpiler/releases/download/v0.7.0/ct-v0.7.0-aarch64-unknown-linux-gnu
mv ct-v0.7.0-aarch64-unknown-linux-gnu ct
chmod +x ct
```
5. Generate a new keypair in the workdirectory. Do not lose this private key as it is necessary to SSH into the bastion server.
```bash
ssh-keygen -t rsa -b 4096 -c "SPECIAL access key"
```
6. Generate the coreos ignition configuration
```bash
cat coreos_bootstrap.yml | sed "s^SSH_TOKEN^$(cat id_rsa.pub)^g" | sed "s^DISCOVERY^$(curl -XGET 'https://discovery.etc.io/new?size=3)'^g" | ./ct -out-file coreos_bootstrap.json -platform openstack-metadata
```
7. Run terraform with the appropriate configuration
```bash
TF_user_name=<openstack_username> \
TF_password=<openstack_password> \
TF_auth_url=https://public.tlabs.cloud:5000/v3 \
TF_tenant_name=<openstack_project_name> \
TF_swarm_public_key=id_rsa.pub \
TF_swarm_private_key_file=id_rsa
terraform apply
```

## TODO
* Close port 2375 on the swarm security group by creating and inserting certificates when the VMs are created.
