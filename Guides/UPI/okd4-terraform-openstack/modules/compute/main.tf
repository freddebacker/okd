data "openstack_networking_network_v2" "network" {
  name  = var.network_name
}

data "openstack_networking_subnet_ids_v2" "subnets" {
  network_id = data.openstack_networking_network_v2.network.id
}

data "openstack_networking_subnet_v2" "subnet" {
  for_each  = toset(data.openstack_networking_subnet_ids_v2.subnets.ids)
  subnet_id = each.value
}

resource "openstack_compute_keypair_v2" "k8s" {
  name       = "kubernetes-${var.cluster_name}"
  public_key = chomp(file(var.public_key_path))
}

resource "openstack_networking_secgroup_v2" "k8s_master" {
  name        = "${var.cluster_name}-master"
  description = "${var.cluster_name} - Kubernetes Master"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master-rule1" {
  for_each          = toset(data.openstack_networking_subnet_ids_v2.subnets.ids)
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s_master.id
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "::/0" : "0.0.0.0/0"
}

resource "openstack_networking_secgroup_v2" "lb_in" {
  name        = "${var.cluster_name}-lb-in"
  description = "${var.cluster_name} - Load balancer ingress"
}

resource "openstack_networking_secgroup_rule_v2" "lb_in-rule1" {
  for_each          = toset(data.openstack_networking_subnet_ids_v2.subnets.ids)
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.lb_in.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "::/0" : "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "lb_in-rule2" {
  for_each          = toset(data.openstack_networking_subnet_ids_v2.subnets.ids)
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.lb_in.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "::/0" : "0.0.0.0/0"
}

resource "openstack_networking_secgroup_v2" "k8s" {
  name        = "${var.cluster_name}-inter-cluster"
  description = "${var.cluster_name} - Kubernetes"
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule1" {
  for_each          = toset(data.openstack_networking_subnet_ids_v2.subnets.ids)
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "ipv6-icmp" : "icmp"
  remote_ip_prefix  = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "::/0" : "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule2" {
  for_each          = toset(data.openstack_networking_subnet_ids_v2.subnets.ids)
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  remote_group_id   = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule3" {
  for_each          = toset(data.openstack_networking_subnet_ids_v2.subnets.ids)
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "udp"
  port_range_min    = 0
  port_range_max    = 0
  remote_group_id   = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule4" {
  for_each          = toset(data.openstack_networking_subnet_ids_v2.subnets.ids)
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "ipv6-icmp" : "icmp"
  remote_group_id   = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule5" {
  for_each          = var.use_octavia ? toset(data.openstack_networking_subnet_ids_v2.subnets.ids) : toset([])
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = data.openstack_networking_subnet_v2.subnet[each.value].cidr
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule6" {
  for_each          = var.use_octavia ? toset(data.openstack_networking_subnet_ids_v2.subnets.ids) : toset([])
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "tcp"
  port_range_min    = 22623
  port_range_max    = 22623
  remote_ip_prefix  = data.openstack_networking_subnet_v2.subnet[each.value].cidr
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule7" {
  for_each          = var.use_octavia ? toset(data.openstack_networking_subnet_ids_v2.subnets.ids) : toset([])
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = data.openstack_networking_subnet_v2.subnet[each.value].cidr
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule8" {
  for_each          = var.use_octavia ? toset(data.openstack_networking_subnet_ids_v2.subnets.ids) : toset([])
  direction         = "ingress"
  ethertype         = strcontains(data.openstack_networking_subnet_v2.subnet[each.value].cidr, ":") ? "IPv6" : "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = data.openstack_networking_subnet_v2.subnet[each.value].cidr
}

resource "openstack_networking_secgroup_v2" "ssh" {
  name        = "${var.cluster_name}-ssh"
  description = "${var.cluster_name} - SSH access"
}

resource "openstack_networking_secgroup_rule_v2" "ssh-cidr" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.ssh.id
  count             = length(var.allow_ssh_from_v4)
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allow_ssh_from_v4[count.index]
}


resource "openstack_compute_instance_v2" "k8s_lb" {
  count      = var.use_octavia ? 0 : 1
  name       = "lb-${var.cluster_name}.${var.domain_name}"
  image_name = var.image_lb
  flavor_id  = var.flavor_lb
  network {
    name = var.network_name
  }
  key_pair   = openstack_compute_keypair_v2.k8s.name
  metadata = {
    ssh_user         = var.ssh_user
    role             = "lb"
  }

  security_groups = [openstack_networking_secgroup_v2.k8s_master.name,
    openstack_networking_secgroup_v2.k8s.name,
    openstack_networking_secgroup_v2.lb_in.name,
    openstack_networking_secgroup_v2.ssh.name,
    "default",
  ]
}

resource "openstack_dns_recordset_v2" "lb_instance" {
  count       = length(data.openstack_networking_subnet_ids_v2.subnets.ids)
  zone_id     = var.dns_zone_id
  name        = "lb-${var.cluster_name}.${var.domain_name}."
  description = "lb dns record"
  ttl         = 300
  type        = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, count.index)].cidr, ":") ? "AAAA" : "A"
  records     = var.use_octavia ? [trim(openstack_lb_loadbalancer_v2.lb_1[count.index].vip_address, "[]")] : (strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, count.index)].cidr, ":") ? [trim(openstack_compute_instance_v2.k8s_lb[0].access_ip_v6, "[]")] : [openstack_compute_instance_v2.k8s_lb[0].access_ip_v4])
}

resource "openstack_images_image_v2" "k8s_boot_ignition_iso" {
  count            = var.number_of_boot > 0 ? 1 : 0
  name             = basename(var.boot_ignition_iso)
  local_file_path  = pathexpand(var.boot_ignition_iso)
  container_format = "bare"
  disk_format      = "raw"
}

data "openstack_images_image_v2" "k8s_boot_image" {
  count       = var.number_of_boot > 0 ? 1 : 0
  name        = var.image
  most_recent = true
}

resource "openstack_compute_instance_v2" "k8s_boot" {
  name       = "boot-${var.cluster_name}.${var.domain_name}"
  count      = var.number_of_boot
  flavor_id  = var.flavor_lb
  image_name = var.image

  block_device {
    uuid                  = data.openstack_images_image_v2.k8s_boot_image[0].id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 60
    delete_on_termination = true
    boot_index            = 0
  }

  block_device {
    uuid                  = openstack_images_image_v2.k8s_boot_ignition_iso[0].id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 1
    delete_on_termination = true
    device_type           = "cdrom"
    disk_bus              = "ide"
    boot_index            = 1
  }

  network {
    name = var.network_name
  }
  security_groups = [openstack_networking_secgroup_v2.k8s_master.name,
    openstack_networking_secgroup_v2.k8s.name,
    openstack_networking_secgroup_v2.ssh.name,
    "default",
  ]
  metadata = {
    role             = "boot"
  }
}

resource "openstack_dns_recordset_v2" "boot_instance" {
  count       = length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_boot
  zone_id     = var.dns_zone_id
  name        = "boot-${var.cluster_name}.${var.domain_name}."
  description = "Bootstrap dns record"
  ttl         = 300
  type        = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_boot))].cidr, ":") ? "AAAA" : "A"
  records     = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_boot))].cidr, ":") ? [trim(openstack_compute_instance_v2.k8s_boot[count.index % var.number_of_boot].access_ip_v6, "[]")] : [openstack_compute_instance_v2.k8s_boot[count.index % var.number_of_boot].access_ip_v4]
}

data "openstack_images_image_v2" "k8s_master_image" {
  count       = var.number_of_masters > 0 ? 1 : 0
  name        = var.image
  most_recent = true
}

resource "openstack_networking_port_v2" "k8s_master_instanceport" {
  name       = "master-${count.index+1}-${var.cluster_name}.${var.domain_name}"
  count      = var.number_of_masters
  network_id     = data.openstack_networking_network_v2.network.id
  admin_state_up = "true"
  allowed_address_pairs {
    ip_address = "0.0.0.0/0"
  }

  security_group_ids = [openstack_networking_secgroup_v2.k8s_master.id,
    openstack_networking_secgroup_v2.k8s.id,
    openstack_networking_secgroup_v2.ssh.id,
  ]
}

resource "openstack_compute_instance_v2" "k8s_master" {
  name       = "master-${count.index+1}-${var.cluster_name}.${var.domain_name}"
  count      = var.number_of_masters
  flavor_id  = var.flavor_master

  block_device {
    uuid                  = data.openstack_images_image_v2.k8s_master_image[0].id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 60
    delete_on_termination = true
    boot_index            = 0
  }

  network {
    port           = openstack_networking_port_v2.k8s_master_instanceport[count.index].id
    access_network = "true"
  }

  security_groups = [openstack_networking_secgroup_v2.k8s_master.name,
    openstack_networking_secgroup_v2.k8s.name,
    openstack_networking_secgroup_v2.ssh.name,
    "default",
  ]
  user_data = file("${var.master_ignition}")
  metadata = {
    role             = "master"
  }

}

resource "openstack_dns_recordset_v2" "master_instances" {
  count       = length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_masters
  zone_id     = var.dns_zone_id
  name        = "master-${(count.index % var.number_of_masters)+1}-${var.cluster_name}.${var.domain_name}."
  description = "Master ${(count.index % var.number_of_masters)+1} dns record"
  ttl         = 300
  type        = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_masters))].cidr, ":") ? "AAAA" : "A"
  records     = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_masters))].cidr, ":") ? [trim(openstack_compute_instance_v2.k8s_master[count.index % var.number_of_masters].access_ip_v6, "[]")] : [openstack_compute_instance_v2.k8s_master[count.index % var.number_of_masters].access_ip_v4]
}

resource "openstack_dns_recordset_v2" "master_api" {
  count       = length(data.openstack_networking_subnet_ids_v2.subnets.ids)
  zone_id     = var.dns_zone_id
  name        = "api.${var.cluster_name}.${var.domain_name}."
  description = "Master api record "
  ttl         = 300
  type        = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, count.index)].cidr, ":") ? "AAAA" : "A"
  records     = var.use_octavia ? [trim(openstack_lb_loadbalancer_v2.lb_1[count.index].vip_address, "[]")] : (strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, count.index)].cidr, ":") ? [trim(openstack_compute_instance_v2.k8s_lb[0].access_ip_v6, "[]")] : [openstack_compute_instance_v2.k8s_lb[0].access_ip_v4])
}

resource "openstack_dns_recordset_v2" "master_api_int" {
  count       = length(data.openstack_networking_subnet_ids_v2.subnets.ids)
  zone_id     = var.dns_zone_id
  name        = "api-int.${var.cluster_name}.${var.domain_name}."
  description = "Internal master api record "
  ttl         = 300
  type        = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, count.index)].cidr, ":") ? "AAAA" : "A"
  records     = var.use_octavia ? [trim(openstack_lb_loadbalancer_v2.lb_1[count.index].vip_address, "[]")] : (strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, count.index)].cidr, ":") ? [trim(openstack_compute_instance_v2.k8s_lb[0].access_ip_v6, "[]")] : [openstack_compute_instance_v2.k8s_lb[0].access_ip_v4])
}

resource "openstack_dns_recordset_v2" "etcd_instances" {
  count       = length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_masters
  zone_id     = var.dns_zone_id
  name        = "etcd-${(count.index % var.number_of_masters)+1}-${var.cluster_name}.${var.domain_name}."
  description = "Etcd ${(count.index % var.number_of_masters)+1} dns record"
  ttl         = 300
  type        = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_masters))].cidr, ":") ? "AAAA" : "A"
  records     = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_masters))].cidr, ":") ? [trim(openstack_compute_instance_v2.k8s_master[count.index % var.number_of_masters].access_ip_v6, "[]")] : [openstack_compute_instance_v2.k8s_master[count.index % var.number_of_masters].access_ip_v4]
}

resource "openstack_dns_recordset_v2" "etcd_srv" {
  zone_id     = var.dns_zone_id
  name        = "_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}."
  description = "Etcd srv record"
  ttl         = 300
  type        = "SRV"
  records     = formatlist("0 10 2380 etcd-%s-${var.cluster_name}.${var.domain_name}.",range(1,"${var.number_of_masters}"+1))
}

data "openstack_images_image_v2" "k8s_worker_image" {
  count       = var.number_of_workers > 0 ? 1 : 0
  name        = var.image
  most_recent = true
}

resource "openstack_networking_port_v2" "k8s_worker_instanceport" {
  name       = "worker-${count.index+1}-${var.cluster_name}.${var.domain_name}"
  count      = var.number_of_workers
  network_id     = data.openstack_networking_network_v2.network.id
  admin_state_up = "true"
  allowed_address_pairs {
    ip_address = "0.0.0.0/0"
  }

  security_group_ids = [openstack_networking_secgroup_v2.k8s.id,
    openstack_networking_secgroup_v2.ssh.id,
  ]
}

resource "openstack_compute_instance_v2" "k8s_worker" {
  name       = "worker-${count.index+1}-${var.cluster_name}.${var.domain_name}"
  count      = var.number_of_workers
  flavor_id  = var.flavor_worker

  block_device {
    uuid                  = data.openstack_images_image_v2.k8s_worker_image[0].id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 60
    delete_on_termination = true
    boot_index            = 0
  }

  network {
    port           = openstack_networking_port_v2.k8s_worker_instanceport[count.index].id
    access_network = "true"
  }

  security_groups = [openstack_networking_secgroup_v2.k8s.name,
    openstack_networking_secgroup_v2.ssh.name,
    "default",
  ]
  user_data = file("${var.worker_ignition}")
  metadata = {
    role             = "worker"
  }

}

resource "openstack_dns_recordset_v2" "worker_instances" {
  count       = length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_workers
  zone_id     = var.dns_zone_id
  name        = "worker-${(count.index % var.number_of_workers)+1}-${var.cluster_name}.${var.domain_name}."
  description = "Worker ${(count.index % var.number_of_workers)+1} dns record"
  ttl         = 300
  type        = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_workers))].cidr, ":") ? "AAAA" : "A"
  records     = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_workers))].cidr, ":") ? [trim(openstack_compute_instance_v2.k8s_worker[count.index % var.number_of_workers].access_ip_v6, "[]")] : [openstack_compute_instance_v2.k8s_worker[count.index % var.number_of_workers].access_ip_v4]
}

resource "openstack_dns_recordset_v2" "apps" {
  count       = length(data.openstack_networking_subnet_ids_v2.subnets.ids)
  zone_id     = var.dns_zone_id
  name        = "*.apps.${var.cluster_name}.${var.domain_name}."
  description = "apps record (DNS-RR)"
  ttl         = 300
  type        = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, count.index)].cidr, ":") ? "AAAA" : "A"
  records     = var.use_octavia ? [trim(openstack_lb_loadbalancer_v2.lb_1[count.index].vip_address, "[]")] : (strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, count.index)].cidr, ":") ? [trim(openstack_compute_instance_v2.k8s_lb[0].access_ip_v6, "[]")] : [openstack_compute_instance_v2.k8s_lb[0].access_ip_v4])
}

resource "openstack_lb_loadbalancer_v2" "lb_1" {
  count              = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  vip_subnet_id      = data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, count.index)].id
  security_group_ids = [openstack_networking_secgroup_v2.k8s_master.id,
    openstack_networking_secgroup_v2.k8s.id,
    openstack_networking_secgroup_v2.lb_in.id,
  ]
}

resource "openstack_lb_pool_v2" "pool_1" {
  name            = "pool :6443"
  count           = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  protocol        = "TCP"
  lb_method       = "ROUND_ROBIN"
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[count.index].id
}

resource "openstack_lb_member_v2" "pool_1_members_1" {
  count         = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_masters : 0
  pool_id       = openstack_lb_pool_v2.pool_1[floor(count.index/var.number_of_masters)].id
  address       = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_masters))].cidr, ":") ? trim(openstack_compute_instance_v2.k8s_master[count.index % var.number_of_masters].access_ip_v6, "[]") : openstack_compute_instance_v2.k8s_master[count.index % var.number_of_masters].access_ip_v4
  protocol_port = 6443
}

resource "openstack_lb_member_v2" "pool_1_members_2" {
  count         = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_boot : 0
  pool_id       = openstack_lb_pool_v2.pool_1[floor(count.index/var.number_of_boot)].id
  address       = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_boot))].cidr, ":") ? trim(openstack_compute_instance_v2.k8s_boot[count.index % var.number_of_boot].access_ip_v6, "[]") : openstack_compute_instance_v2.k8s_boot[count.index % var.number_of_boot].access_ip_v4
  protocol_port = 6443
}

resource "openstack_lb_monitor_v2" "monitor_1" {
  count       = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  pool_id     = openstack_lb_pool_v2.pool_1[count.index].id
  type        = "HTTPS"
  url_path    = "/readyz"
  delay       = 10
  timeout     = 9
  max_retries = 3
}

resource "openstack_lb_listener_v2" "listener_1" {
  count           = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  protocol        = "TCP"
  protocol_port   = 6443
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[count.index].id
  default_pool_id = openstack_lb_pool_v2.pool_1[count.index].id
}

resource "openstack_lb_pool_v2" "pool_2" {
  name            = "pool :22623"
  count           = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  protocol        = "TCP"
  lb_method       = "ROUND_ROBIN"
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[count.index].id
}

resource "openstack_lb_member_v2" "pool_2_members_1" {
  count         = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_masters : 0
  pool_id       = openstack_lb_pool_v2.pool_2[floor(count.index/var.number_of_masters)].id
  address       = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_masters))].cidr, ":") ? trim(openstack_compute_instance_v2.k8s_master[count.index % var.number_of_masters].access_ip_v6, "[]") : openstack_compute_instance_v2.k8s_master[count.index % var.number_of_masters].access_ip_v4
  protocol_port = 22623
}

resource "openstack_lb_member_v2" "pool_2_members_2" {
  count         = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_boot : 0
  pool_id       = openstack_lb_pool_v2.pool_2[floor(count.index/var.number_of_boot)].id
  address       = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_boot))].cidr, ":") ? trim(openstack_compute_instance_v2.k8s_boot[count.index % var.number_of_boot].access_ip_v6, "[]") : openstack_compute_instance_v2.k8s_boot[count.index % var.number_of_boot].access_ip_v4
  protocol_port = 22623
  backup        = true
}

resource "openstack_lb_monitor_v2" "monitor_2" {
  count       = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  pool_id     = openstack_lb_pool_v2.pool_2[count.index].id
  type        = "TCP"
  delay       = 10
  timeout     = 9
  max_retries = 3
}

resource "openstack_lb_listener_v2" "listener_2" {
  count           = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  protocol        = "TCP"
  protocol_port   = 22623
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[count.index].id
  default_pool_id = openstack_lb_pool_v2.pool_2[count.index].id
}

resource "openstack_lb_pool_v2" "pool_3" {
  name            = "pool :80"
  count           = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  protocol        = "TCP"
  lb_method       = "SOURCE_IP"
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[count.index].id

  persistence {
    type        = "SOURCE_IP"
  }
}

resource "openstack_lb_member_v2" "pool_3_members_1" {
  count         = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_workers : 0
  pool_id       = openstack_lb_pool_v2.pool_3[floor(count.index/var.number_of_workers)].id
  address       = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_workers))].cidr, ":") ? trim(openstack_compute_instance_v2.k8s_worker[count.index % var.number_of_workers].access_ip_v6, "[]") : openstack_compute_instance_v2.k8s_worker[count.index % var.number_of_workers].access_ip_v4
  protocol_port = 80
}

resource "openstack_lb_monitor_v2" "monitor_3" {
  count       = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  pool_id     = openstack_lb_pool_v2.pool_3[count.index].id
  type        = "TCP"
  delay       = 10
  timeout     = 9
  max_retries = 3
}

resource "openstack_lb_listener_v2" "listener_3" {
  count           = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[count.index].id
  default_pool_id = openstack_lb_pool_v2.pool_3[count.index].id
}

resource "openstack_lb_pool_v2" "pool_4" {
  name            = "pool :443"
  count           = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  protocol        = "TCP"
  lb_method       = "SOURCE_IP"
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[count.index].id

  persistence {
    type        = "SOURCE_IP"
  }
}

resource "openstack_lb_member_v2" "pool_4_members_1" {
  count         = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) * var.number_of_workers : 0
  pool_id       = openstack_lb_pool_v2.pool_4[floor(count.index/var.number_of_workers)].id
  address       = strcontains(data.openstack_networking_subnet_v2.subnet[element(data.openstack_networking_subnet_ids_v2.subnets.ids, floor(count.index/var.number_of_workers))].cidr, ":") ? trim(openstack_compute_instance_v2.k8s_worker[count.index % var.number_of_workers].access_ip_v6, "[]") : openstack_compute_instance_v2.k8s_worker[count.index % var.number_of_workers].access_ip_v4
  protocol_port = 443
}

resource "openstack_lb_monitor_v2" "monitor_4" {
  count       = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  pool_id     = openstack_lb_pool_v2.pool_4[count.index].id
  type        = "TCP"
  delay       = 10
  timeout     = 9
  max_retries = 3
}

resource "openstack_lb_listener_v2" "listener_4" {
  count           = var.use_octavia ? length(data.openstack_networking_subnet_ids_v2.subnets.ids) : 0
  protocol        = "TCP"
  protocol_port   = 443
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[count.index].id
  default_pool_id = openstack_lb_pool_v2.pool_4[count.index].id
}
