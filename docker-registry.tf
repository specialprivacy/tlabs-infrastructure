# Provision a standalone server which will run the docker Registry
# We're keeping this outside of the docker swarm cluster, because ideally
# we should not be running this but relying on the public registry or a Registry
# hosted by a reliable third party (quai.io or any of the large cloud providers)

resource "openstack_compute_instance_v2" "registry" {
  name        = "registry"
  image_id    = "${openstack_images_image_v2.ubuntu_artful.id}"
  flavor_name = "m1.tiny"
  key_pair    = "${openstack_compute_keypair_v2.swarm_keypair.name}"

  security_groups = ["${openstack_networking_secgroup_v2.public_ssh.name}", "${openstack_networking_secgroup_v2.public_http_server.name}"]
  user_data       = "${file("registry-cloud-config.yml")}"

  metadata {
    role    = "docker registry"
    project = "${var.project_name}"
  }

  network {
    uuid = "${openstack_networking_network_v2.swarm_network.id}"
  }
}

resource "openstack_blockstorage_volume_v2" "registry_volume" {
  name = "registry-volume"
  size = 100
}

resource "openstack_compute_volume_attach_v2" "registry_volume_attach" {
  instance_id = "${openstack_compute_instance_v2.registry.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.registry_volume.id}"
}

resource "openstack_images_image_v2" "ubuntu_artful" {
  name             = "Ubuntu Artful"
  image_source_url = "https://cloud-images.ubuntu.com/artful/20180303/artful-server-cloudimg-amd64.img"
  container_format = "bare"
  disk_format      = "qcow2"
}

# resource "openstack_networking_network_v2" "registry_network" {
#   name           = "docker_registry_network"
#   admin_state_up = "true"
# }
#
# resource "openstack_networking_subnet_v2" "registry_subnet" {
#   name            = "registry_subnet_1"
#   network_id      = "${openstack_networking_network_v2.registry_network.id}"
#   cidr            = "192.168.5.0/24"
#   ip_version      = 4
#   dns_nameservers = ["8.8.8.8", "8.8.4.4"]
# }

# resource "openstack_networking_router_v2" "registry_router" {
#   name                = "registry_router"
#   admin_state_up      = "true"
#   external_network_id = "${data.openstack_networking_network_v2.external_network.id}"
# }
#
# resource "openstack_networking_router_interface_v2" "registry_router_interface" {
#   router_id = "${openstack_networking_router_v2.registry_router.id}"
#   subnet_id = "${openstack_networking_subnet_v2.registry_subnet.id}"
# }

resource "openstack_networking_floatingip_v2" "registry_ip" {
  pool = "public"
}

resource "openstack_compute_floatingip_associate_v2" "registry_ip_assoc" {
  floating_ip = "${openstack_networking_floatingip_v2.registry_ip.address}"
  instance_id = "${openstack_compute_instance_v2.registry.id}"
}
