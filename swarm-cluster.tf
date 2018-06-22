resource "openstack_compute_instance_v2" "root" {
  name        = "root"
  image_id    = "${openstack_images_image_v2.coreos_stable.id}"
  flavor_name = "${var.instance_flavor}"
  key_pair    = "${openstack_compute_keypair_v2.swarm_keypair.name}"

  security_groups = ["${openstack_networking_secgroup_v2.public_http_server.name}", "${openstack_networking_secgroup_v2.public_ssh.name}", "${openstack_networking_secgroup_v2.swarm_mode.name}", "${openstack_networking_secgroup_v2.coreos.name}", "${openstack_networking_secgroup_v2.docker_tcp.name}", "${openstack_networking_secgroup_v2.monitoring_stack.name}"]
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
  count       = "${var.manager_node_count}"
  name        = "master-${count.index}"
  image_id    = "${openstack_images_image_v2.coreos_stable.id}"
  flavor_name = "${var.instance_flavor}"
  key_pair    = "${openstack_compute_keypair_v2.swarm_keypair.name}"

  security_groups = ["${openstack_networking_secgroup_v2.public_http_server.name}", "${openstack_networking_secgroup_v2.private_ssh.name}", "${openstack_networking_secgroup_v2.swarm_mode.name}", "${openstack_networking_secgroup_v2.coreos.name}", "${openstack_networking_secgroup_v2.docker_tcp.name}", "${openstack_networking_secgroup_v2.monitoring_stack.name}"]
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
  count       = "${var.worker_node_count}"
  name        = "worker-${count.index}"
  image_id    = "${openstack_images_image_v2.coreos_stable.id}"
  flavor_name = "${var.instance_flavor}"
  key_pair    = "${openstack_compute_keypair_v2.swarm_keypair.name}"

  security_groups = ["${openstack_networking_secgroup_v2.public_http_server.name}", "${openstack_networking_secgroup_v2.private_ssh.name}", "${openstack_networking_secgroup_v2.swarm_mode.name}", "${openstack_networking_secgroup_v2.coreos.name}", "${openstack_networking_secgroup_v2.docker_tcp.name}", "${openstack_networking_secgroup_v2.monitoring_stack.name}"]
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
