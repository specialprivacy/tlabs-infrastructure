# Openstack Provider variables
variable "password" {}

variable "user_name" {}

variable "auth_url" {
  default = "https://public.tlabs.cloud:5000/v3"
}

variable "region" {
  default = "RegionOne"
}

variable "tenant_name" {
  default = "EU-SPECIAL"
}

variable "domain_name" {
  default = "Default"
}

# Stack variables
variable "manager_node_count" {
  default = 2
}

variable "worker_node_count" {
  default = 0
}

variable "instance_flavor" {
  default = "m1.large"
}

variable "swarm_public_key_file" {
  default = "id_rsa.pub"
}

variable "swarm_private_key_file" {
  default = "id_rsa"
}

variable "project_name" {
  default = "Special Demo"
}
