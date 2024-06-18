
module "compute" {
  source = "./modules/compute"
  cluster_name                                 = "${var.cluster_name}"
  boot_ignition                                = "${var.boot_ignition}"
  master_ignition                              = "${var.master_ignition}"
  worker_ignition                              = "${var.worker_ignition}"
  public_key_path                              = "${var.public_key_path}"
  ssh_user                                     = "${var.ssh_user}"
  dns_zone_id                                  = "${var.dns_zone_id}"
  number_of_boot                               = "${var.number_of_boot}"
  number_of_masters                            = "${var.number_of_masters}"
  number_of_workers                            = "${var.number_of_workers}"
  master_volume_size                           = "${var.master_volume_size}"
  node_volume_size                             = "${var.node_volume_size}"
  image                                        = "${var.image}"
  image_lb                                     = "${var.image_lb}"
  flavor_master                                = "${var.flavor_master}"
  flavor_worker                                = "${var.flavor_worker}"
  flavor_lb                                    = "${var.flavor_lb}"
  network_name                                 = "${var.network_name}"
  allow_ssh_from_v4                            = "${var.allow_ssh_from_v4}"
  domain_name                                  = "${var.domain_name}"
  use_octavia                                  = var.use_octavia
}

