# Special Demo Environment Infrastructure
This repository contains the code which will provision the infrastructure for demo environment for the SPECIAL platform. The infrastructure is constructed using (terraform)[https://www.terraform.io].

## Description
The scripts will create a cluster of 3 VMS running docker swarm and a standalone server hosting a docker registry.
* 1 root VM which will also act as a bastion server. This is the node from which we'll bootstrap the swarm cluster.
* 2 master VMs. These are only exposed to the internal network.
* 1 ubuntu VM with an attached disk running a docker registry.

The docker swarm machines all run machines coreos and will install their own operating system updates. Additional machines can be added by changing the `manager_node_count` and `worker_node_count` variables.
A swarm cluster should probably never have more than 5 manager nodes, so initially try added worker nodes.

The script will also install docker swarm mode onto the machines and join them into the existing cluster. The cluster will be mostly fault tolerant, however terraform will get confused if the root machine dies.
It will try to recreate it, but the script that provisions docker swarm will fail as a cluster already exists. So after using this script for the first time, the provisioner exec line should be changed to the same script that provisions a manager.

Because the docker registry is not being run in an HA mode, we do not want to have it reboot randomly (which is how coreos patches servers). Therefore we are running standard ubuntu on this server. Ideally we should move to a docker registry SaaS offering.

Here is a small description of what each of the files in this repositor does:
* **coreos_bootstrap.yml**
This file contains the software configuration of all the VMs. It is responsible for configuring etcd (needed to make the automatic upgrades work), installing SSH keys and configuring docker to expose its socket as a TCP and Unix socket.
It needs to be preprocessed to insert an etcd discovery token and the public SSH key
* **security-groups.tf**
This file defines all the different security groups that can be assigned to VMs. These are not specific to this infrastructure
* **swarm-cluster.tf**
This file contains the description of the VMs and network components. It will also provision a public IP and assign it to the root/bastion server.
* **docker-registry.tf**
This file contains the description of the ubuntu VM which will run the docker registry. Because we can only have one router in our account it is reusing the docker swarm network.
* **registry-cloud-config.yml**
This file contains the post boot configuration of the ubuntu VM. It is responsible for partioning and mounting the attached storage volume and installing all dependencies. We could even have it start the docker registry as an improvement. It serves a similar purpose as `coreos_bootstrap.yml` does for the swarm servers.
* **variables.tf**
This file contains configurable parameters of the stack we are deploying. Here you can change the amount of VMs to create and the image type etc. Non secret parameters of the Openstack provider can also be set in this file. Variables can also be overwritten at runtime by passing in environment variables (see https://www.terraform.io/docs/configuration/environment-variables.html)
* **terraform.tfvars**
This file is not part of the repository, but it can be used to set secret variables (usernames and passwords). It will not be checked in, but it can be more comfortable than always specifying these through environment variables.

## Prerequisites
In order for the scripts to run, a working OpenStack account, along with information about the OpenStack installation needs to be avialable. This information is passed in either as environment variables to the terraform command or in a `terraform.tfvars` file in the project directory.
For more information about the configuration of the terraform openstack provider, look here: https://www.terraform.io/docs/providers/openstack/index.html

## Build
The examples here will assume a linux / unix environment, but the steps should work on every platform.
1.   Download and install terraform from https://www.terraform.io/download.html
2.   Clone this repository and move to it

     ```bash
     git clone https://git.ai.wu.ac.at/specialprivacy/infrastructure.git
     ```

3.   Initialize terraform (downloads providers)

     ```bash
     terraform init
     ```

4.   Download the ct tool

     ```bash
     wget https://github.com/coreos/container-linux-config-transpiler/releases/download/v0.7.0/ct-v0.7.0-aarch64-unknown-linux-gnu
     mv ct-v0.7.0-aarch64-unknown-linux-gnu ct
     chmod +x ct
     ```

5.   Generate a new keypair in the workdirectory. Do not lose this private key as it is necessary to SSH into the bastion server.

     ```bash
     ssh-keygen -t rsa -b 4096 -c "SPECIAL access key"
     ```

6.   Download and unzip the coreos stable image. Because the openstack API cannot unzip it, we have to download it locally, rather than passing in a URL and have the Openstack installation fetch it automatically

     ```bash
     wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_openstack_image.img.bz2
     bunzip2 coreos_production_openstack_image.img.bz2
     ```

7.   Generate the coreos ignition configuration

     ```bash
     cat coreos_bootstrap.yml | sed "s^SSH_TOKEN^$(cat id_rsa.pub)^g" | sed "s^DISCOVERY^$(curl -XGET 'https://discovery.etc.io/new?size=3)'^g" | ./ct -out-file coreos_bootstrap.json -platform openstack-metadata
     ```

8.   Run terraform with the appropriate configuration

     ```bash
     TF_VAR_user_name=<openstack_username> \
     TF_VAR_password=<openstack_password> \
     TF_VAR_auth_url=https://public.tlabs.cloud:5000/v3 \
     TF_VAR_tenant_name=<openstack_project_name> \
     TF_VAR_swarm_public_key=id_rsa.pub \
     TF_VAR_swarm_private_key_file=id_rsa
     terraform apply
     ```

9.   Read the public IP from the terraform output and connect through SSH

     ```bash
     terraform output
     ssh -i id_rsa core@$(terraform output cluster_ip)
     ```

## TODO
* Close port 2375 on the swarm security group by creating and inserting certificates when the VMs are created.
* Split out the root and bastion server for increased robustness (I did not want to sacrifice 1 of the max 4 VMs in the account for a bastion server)
* Ask for an increase in routers and create a seperate network for the docker registry server
* Move the registry to a SaaS offering
