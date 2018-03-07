output "cluster_ip" {
  value = "${openstack_networking_floatingip_v2.cluster_ip.address}"
}

output "registry_ip" {
  value = "${openstack_networking_floatingip_v2.registry_ip.address}"
}
