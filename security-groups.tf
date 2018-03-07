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

resource "openstack_networking_secgroup_v2" "public_http_server" {
  name        = "public-http-server"
  description = "Security group which opens up port 80 and 443 to the internet, so http traffic can be server"
}

resource "openstack_networking_secgroup_rule_v2" "public_http_server_80" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.public_http_server.id}"
}

resource "openstack_networking_secgroup_rule_v2" "public_http_server_443" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.public_http_server.id}"
}
