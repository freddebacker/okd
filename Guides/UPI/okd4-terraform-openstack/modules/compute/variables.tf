variable "cluster_name" {}

variable "number_of_boot" {}

variable "number_of_masters" {}

variable "number_of_workers" {}

variable "master_volume_size" {
  type = number
}

variable "node_volume_size" {
  type = number
}

variable "designate_dns_zone_id" {
  type    = string
  default = ""
}

variable "public_key_path" {}

variable "ssh_user" {}

variable "image" {}

variable "image_lb" {}

variable "flavor_master" {}

variable "flavor_worker" {}

variable "flavor_lb" {}

variable "network_name" {}

variable "domain_name" {}

variable "master_ignition" {}

variable "worker_ignition" {}

variable "boot_ignition_iso" {}

variable "allow_ssh_from_v4" {
  type    = list(string)
  default = []
}

variable "use_octavia" {
  type    = bool
  default = false
}

variable "use_designate" {
  type    = bool
  default = true
}

variable "dns_server" {
  type    = string
  default = ""
}

variable "dns_key_name" {
  type    = string
  default = ""
}

variable "dns_key_secret" {
  type    = string
  default = ""
}

variable "dns_key_alg" {
  type    = string
  default = ""
}
