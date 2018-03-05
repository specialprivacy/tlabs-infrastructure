resource "openstack_compute_instance_v2" "root" {
  name        = "root"
  image_id    = "${openstack_images_image_v2.coreos_stable.id}"
  flavor_name = "${var.instance_flavor}"
  key_pair    = "${openstack_compute_keypair_v2.swarm_keypair.name}"

  security_groups = ["${openstack_networking_secgroup_v2.public_ssh.name}", "${openstack_networking_secgroup_v2.swarm_mode.name}", "${openstack_networking_secgroup_v2.coreos.name}", "${openstack_networking_secgroup_v2.docker_tcp.name}"]
  user_data       = "${file("coreos_bootstrap.json")}"

  metadata {
    role    = "root"
    project = "${var.project_name}"
  }

  network {
    uuid           = "${openstack_networking_network_v2.swarm_network.id}"
    access_network = true
  }
}

resource "openstack_compute_instance_v2" "master" {
  count       = 2
  name        = "master-${count.index}"
  image_id    = "${openstack_images_image_v2.coreos_stable.id}"
  flavor_name = "${var.instance_flavor}"
  key_pair    = "${openstack_compute_keypair_v2.swarm_keypair.name}"

  security_groups = ["${openstack_networking_secgroup_v2.private_ssh.name}", "${openstack_networking_secgroup_v2.swarm_mode.name}", "${openstack_networking_secgroup_v2.coreos.name}", "${openstack_networking_secgroup_v2.docker_tcp.name}"]
  user_data       = "${file("coreos_bootstrap.json")}"
  depends_on      = ["openstack_compute_floatingip_associate_v2.cluster_ip_assoc"]

  metadata {
    role    = "master"
    project = "${var.project_name}"
  }

  network {
    uuid = "${openstack_networking_network_v2.swarm_network.id}"
  }

  provisioner "remote-exec" {
    inline = ["docker swarm join ${lookup(openstack_compute_instance_v2.root.network[0], "fixed_ip_v4")} --token $(docker -H ${lookup(openstack_compute_instance_v2.root.network[0], "fixed_ip_v4")} swarm join-token -q manager)"]

    connection {
      user         = "core"
      private_key  = "${file("${var.swarm_private_key_file}")}"
      timeout      = "30m"
      agent        = false
      bastion_host = "${openstack_networking_floatingip_v2.cluster_ip.address}"
    }
  }
}

resource "openstack_compute_instance_v2" "worker" {
  count       = 0
  name        = "worker-${count.index}"
  image_id    = "${openstack_images_image_v2.coreos_stable.id}"
  flavor_name = "${var.instance_flavor}"
  key_pair    = "${openstack_compute_keypair_v2.swarm_keypair.name}"

  security_groups = ["${openstack_networking_secgroup_v2.private_ssh.name}", "${openstack_networking_secgroup_v2.swarm_mode.name}", "${openstack_networking_secgroup_v2.coreos.name}", "${openstack_networking_secgroup_v2.docker_tcp.name}"]
  user_data       = "${file("coreos_bootstrap.json")}"
  depends_on      = ["openstack_compute_floatingip_associate_v2.cluster_ip_assoc"]

  metadata {
    role    = "worker"
    project = "${var.project_name}"
  }

  network {
    uuid = "${openstack_networking_network_v2.swarm_network.id}"
  }

  provisioner "remote-exec" {
    inline = ["docker swarm join ${lookup(openstack_compute_instance_v2.root.network[0], "fixed_ip_v4")} --token $(docker -H ${lookup(openstack_compute_instance_v2.root.network[0], "fixed_ip_v4")} swarm join-token -q worker)"]

    connection {
      user         = "core"
      private_key  = "${file("${var.swarm_private_key_file}")}"
      timeout      = "30m"
      agent        = false
      bastion_host = "${openstack_networking_floatingip_v2.cluster_ip.address}"
    }
  }
}

resource "openstack_compute_keypair_v2" "swarm_keypair" {
  name       = "swarm_keypair"
  public_key = "${file("${var.swarm_public_key_file}")}"
}

resource "openstack_images_image_v2" "coreos_stable" {
  name            = "CoreOS Stable"
  local_file_path = "coreos_production_openstack_image.img"

  # image_source_url = "https://stable.release.core-os.net/amd64-usr/current/coreos_production_openstack_image.img.bz2"
  container_format = "bare"
  disk_format      = "qcow2"
}

resource "openstack_networking_network_v2" "swarm_network" {
  name           = "swarm_network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "swarm_subnet_1" {
  name            = "swarm_subnet_1"
  network_id      = "${openstack_networking_network_v2.swarm_network.id}"
  cidr            = "192.168.10.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

data "openstack_networking_network_v2" "external_network" {
  name = "public"
}

resource "openstack_networking_router_v2" "swarm_router" {
  name                = "swarm_router"
  admin_state_up      = true
  external_network_id = "${data.openstack_networking_network_v2.external_network.id}"
}

resource "openstack_networking_router_interface_v2" "swarm_router_interface" {
  router_id = "${openstack_networking_router_v2.swarm_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.swarm_subnet_1.id}"
}

resource "openstack_networking_floatingip_v2" "cluster_ip" {
  pool = "public"
}

resource "openstack_compute_floatingip_associate_v2" "cluster_ip_assoc" {
  floating_ip = "${openstack_networking_floatingip_v2.cluster_ip.address}"
  instance_id = "${openstack_compute_instance_v2.root.id}"

  provisioner "remote-exec" {
    inline = ["docker swarm init"]

    connection {
      type        = "ssh"
      user        = "core"
      private_key = "${file("${var.swarm_private_key_file}")}"
      timeout     = "30m"
      agent       = false
      host        = "${openstack_networking_floatingip_v2.cluster_ip.address}"
    }
  }
}

resource "openstack_networking_secgroup_v2" "allow_all_temp" {
  name        = "allow_all_temp"
  description = "Openstack seems to have issues provisioning vms with our current security group setup. This group allows all traffic and is supposed to be used during VM creation. The security groups can then later be swapped out for the proper ones."
}

resource "openstack_networking_secgroup_rule_v2" "allow_all" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.allow_all_temp.id}"
}

resource "openstack_networking_secgroup_v2" "public_ssh" {
  name        = "public_ssh"
  description = "Allows access on port 22 from any address"
}

resource "openstack_networking_secgroup_rule_v2" "public_ssh_22" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.public_ssh.id}"
}

resource "openstack_networking_secgroup_rule_v2" "public_ssh_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.public_ssh.id}"
}

resource "openstack_networking_secgroup_v2" "private_ssh" {
  name        = "private_ssh"
  description = "Allows access on port 22 from the private subnet"
}

resource "openstack_networking_secgroup_rule_v2" "private_ssh_22" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "${openstack_networking_subnet_v2.swarm_subnet_1.cidr}"
  security_group_id = "${openstack_networking_secgroup_v2.private_ssh.id}"
}

resource "openstack_networking_secgroup_rule_v2" "private_ssh_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.private_ssh.id}"
}

resource "openstack_networking_secgroup_v2" "swarm_mode" {
  name        = "swarm_mode"
  description = "Allows network traffic over the ports required for docker swarm"
}

resource "openstack_networking_secgroup_rule_v2" "swarm_mode_2377" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2377
  port_range_max    = 2377
  remote_group_id   = "${openstack_networking_secgroup_v2.swarm_mode.id}"
  security_group_id = "${openstack_networking_secgroup_v2.swarm_mode.id}"
}

resource "openstack_networking_secgroup_rule_v2" "swarm_mode_7946tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_group_id   = "${openstack_networking_secgroup_v2.swarm_mode.id}"
  security_group_id = "${openstack_networking_secgroup_v2.swarm_mode.id}"
}

resource "openstack_networking_secgroup_rule_v2" "swarm_mode_7946udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 7946
  port_range_max    = 7946
  remote_group_id   = "${openstack_networking_secgroup_v2.swarm_mode.id}"
  security_group_id = "${openstack_networking_secgroup_v2.swarm_mode.id}"
}

resource "openstack_networking_secgroup_rule_v2" "swarm_mode_4789" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 4789
  port_range_max    = 4789
  remote_group_id   = "${openstack_networking_secgroup_v2.swarm_mode.id}"
  security_group_id = "${openstack_networking_secgroup_v2.swarm_mode.id}"
}

resource "openstack_networking_secgroup_rule_v2" "swarm_mode_esp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "esp"
  remote_group_id   = "${openstack_networking_secgroup_v2.swarm_mode.id}"
  security_group_id = "${openstack_networking_secgroup_v2.swarm_mode.id}"
}

resource "openstack_networking_secgroup_v2" "coreos" {
  name        = "coreos"
  description = "Coreos requires etcd to schedule patches and config changes. These firewall rules allow it to operate"
}

resource "openstack_networking_secgroup_rule_v2" "coreos_2379" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2379
  port_range_max    = 2380
  remote_group_id   = "${openstack_networking_secgroup_v2.coreos.id}"
  security_group_id = "${openstack_networking_secgroup_v2.coreos.id}"
}

resource "openstack_networking_secgroup_rule_v2" "coreos_4001" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 4001
  port_range_max    = 4001
  remote_group_id   = "${openstack_networking_secgroup_v2.coreos.id}"
  security_group_id = "${openstack_networking_secgroup_v2.coreos.id}"
}

resource "openstack_networking_secgroup_rule_v2" "coreos_7001" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 7001
  port_range_max    = 7001
  remote_group_id   = "${openstack_networking_secgroup_v2.coreos.id}"
  security_group_id = "${openstack_networking_secgroup_v2.coreos.id}"
}

resource "openstack_networking_secgroup_v2" "docker_tcp" {
  name        = "docker-tcp"
  description = "Opening this port allows the docker client to cummnicate with a docker engine exposed over tcp"
}

# TODO: remove 2375 once we have the docker engine configured to use TLS
resource "openstack_networking_secgroup_rule_v2" "docker_tcp_2375" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2375
  port_range_max    = 2376
  remote_group_id   = "${openstack_networking_secgroup_v2.docker_tcp.id}"
  security_group_id = "${openstack_networking_secgroup_v2.docker_tcp.id}"
}
