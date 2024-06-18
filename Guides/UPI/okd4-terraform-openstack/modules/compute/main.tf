resource "openstack_compute_keypair_v2" "k8s" {
  name       = "kubernetes-${var.cluster_name}"
  public_key = chomp(file(var.public_key_path))
}

resource "openstack_networking_secgroup_v2" "k8s_master" {
  name        = "${var.cluster_name}-master"
  description = "${var.cluster_name} - Kubernetes Master"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master-rule1" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s_master.id
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_v2" "lb_in" {
  name        = "${var.cluster_name}-lb-in"
  description = "${var.cluster_name} - Load balancer ingress"
}

resource "openstack_networking_secgroup_rule_v2" "lb_in-rule1" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.lb_in.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "lb_in-rule2" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.lb_in.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_v2" "k8s" {
  name        = "${var.cluster_name}-inter-cluster"
  description = "${var.cluster_name} - Kubernetes"
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule1" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule2" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  remote_group_id   = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule3" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "udp"
  port_range_min    = 0
  port_range_max    = 0
  remote_group_id   = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s-rule4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.k8s.id
  protocol          = "icmp"
  remote_group_id   = openstack_networking_secgroup_v2.k8s.id
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
  zone_id     = var.dns_zone_id
  name        = "lb-${var.cluster_name}.${var.domain_name}."
  count      = var.number_of_boot
  description = "lb dns record"
  ttl         = 300
  type        = "A"
  records     = var.use_octavia ? [openstack_lb_loadbalancer_v2.lb_1[0].vip_address] : [openstack_compute_instance_v2.k8s_lb[0].access_ip_v4]
}
resource "openstack_compute_instance_v2" "k8s_boot" {
  name       = "boot-${var.cluster_name}.${var.domain_name}"
  count      = var.number_of_boot
  image_name = var.image
  flavor_id  = var.flavor_lb
  network {
    name = var.network_name
  }
  user_data = file("${var.boot_ignition}")
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
  zone_id     = var.dns_zone_id
  name        = "boot-${var.cluster_name}.${var.domain_name}."
  count      = var.number_of_boot
  description = "Bootstrap dns record"
  ttl         = 300
  type        = "A"
  records     = [element(openstack_compute_instance_v2.k8s_boot.*.access_ip_v4,count.index)]
}

resource "openstack_compute_instance_v2" "k8s_master" {
  name       = "master-${count.index+1}-${var.cluster_name}.${var.domain_name}"
  count      = var.number_of_masters
  image_name = var.image
  flavor_id  = var.flavor_master

  network {
    name = var.network_name
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
  zone_id     = var.dns_zone_id
  name        = "master-${count.index+1}-${var.cluster_name}.${var.domain_name}."
  description = "Master ${count.index+1} dns record"
  count       = var.number_of_masters
  ttl         = 300
  type        = "A"
  records     = [element(openstack_compute_instance_v2.k8s_master.*.access_ip_v4,count.index)]
}

resource "openstack_dns_recordset_v2" "master_api" {
  zone_id     = var.dns_zone_id
  name        = "api.${var.cluster_name}.${var.domain_name}."
  description = "Master api record "
  ttl         = 300
  type        = "A"
  records     = var.use_octavia ? [openstack_lb_loadbalancer_v2.lb_1[0].vip_address] : [openstack_compute_instance_v2.k8s_lb[0].access_ip_v4]
}

resource "openstack_dns_recordset_v2" "master_api_int" {
  zone_id     = var.dns_zone_id
  name        = "api-int.${var.cluster_name}.${var.domain_name}."
  description = "Internal master api record "
  ttl         = 300
  type        = "A"
  records     = var.use_octavia ? [openstack_lb_loadbalancer_v2.lb_1[0].vip_address] : [openstack_compute_instance_v2.k8s_lb[0].access_ip_v4]
}

resource "openstack_dns_recordset_v2" "etcd_instances" {
  zone_id     = var.dns_zone_id
  name        = "etcd-${count.index+1}-${var.cluster_name}.${var.domain_name}."
  description = "Etcd ${count.index+1} dns record"
  count       = var.number_of_masters
  ttl         = 300
  type        = "A"
  records     = [element(openstack_compute_instance_v2.k8s_master.*.access_ip_v4,count.index)]
}

resource "openstack_dns_recordset_v2" "etcd_srv" {
  zone_id     = var.dns_zone_id
  name        = "_etcd-server-ssl._tcp.${var.cluster_name}.${var.domain_name}."
  description = "Etcd srv record"
  ttl         = 300
  type        = "SRV"
  records     = formatlist("0 10 2380 etcd-%s-${var.cluster_name}.${var.domain_name}.",range(1,"${var.number_of_masters}"+1))
}


resource "openstack_compute_instance_v2" "k8s_worker" {
  name       = "worker-${count.index+1}-${var.cluster_name}.${var.domain_name}"
  count      = var.number_of_workers
  image_name = var.image
  flavor_id  = var.flavor_worker

  network {
    name = var.network_name
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
  zone_id     = var.dns_zone_id
  name        = "worker-${count.index+1}-${var.cluster_name}.${var.domain_name}."
  description = "Worker ${count.index+1} dns record"
  count       = var.number_of_workers
  ttl         = 300
  type        = "A"
  records     = [element(openstack_compute_instance_v2.k8s_worker.*.access_ip_v4,count.index)]
}

resource "openstack_dns_recordset_v2" "apps" {
  zone_id     = var.dns_zone_id
  name        = "*.apps.${var.cluster_name}.${var.domain_name}."
  description = "apps record (DNS-RR)"
  ttl         = 300
  type        = "A"
  records     = var.use_octavia ? [openstack_lb_loadbalancer_v2.lb_1[0].vip_address] : [openstack_compute_instance_v2.k8s_lb[0].access_ip_v4]
}

data "openstack_networking_network_v2" "lb_network" {
  count = var.use_octavia ? 1 : 0
  name  = var.network_name
}

resource "openstack_lb_loadbalancer_v2" "lb_1" {
  count              = var.use_octavia ? 1 : 0
  vip_network_id     = data.openstack_networking_network_v2.lb_network[0].id
  security_group_ids = [openstack_networking_secgroup_v2.lb_in.id]
}

resource "openstack_lb_pool_v2" "pool_1" {
  count           = var.use_octavia ? 1 : 0
  protocol        = "TCP"
  lb_method       = "ROUND_ROBIN"
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[0].id
}

resource "openstack_lb_member_v2" "pool_1_members_1" {
  count         = var.use_octavia ? var.number_of_masters : 0
  pool_id       = openstack_lb_pool_v2.pool_1[0].id
  address       = element(openstack_compute_instance_v2.k8s_master.*.access_ip_v4,count.index)
  protocol_port = 6443
}

resource "openstack_lb_member_v2" "pool_1_members_2" {
  count         = var.use_octavia ? var.number_of_boot : 0
  pool_id       = openstack_lb_pool_v2.pool_1[0].id
  address       = element(openstack_compute_instance_v2.k8s_boot.*.access_ip_v4,count.index)
  protocol_port = 6443
}

resource "openstack_lb_monitor_v2" "monitor_1" {
  count       = var.use_octavia ? 1 : 0
  pool_id     = openstack_lb_pool_v2.pool_1[0].id
  type        = "HTTPS"
  url_path    = "/readyz"
  delay       = 10
  timeout     = 9
  max_retries = 3
}

resource "openstack_lb_listener_v2" "listener_1" {
  count           = var.use_octavia ? 1 : 0
  protocol        = "TCP"
  protocol_port   = 6443
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[0].id
  default_pool_id = openstack_lb_pool_v2.pool_1[0].id
}

resource "openstack_lb_pool_v2" "pool_2" {
  count           = var.use_octavia ? 1 : 0
  protocol        = "TCP"
  lb_method       = "ROUND_ROBIN"
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[0].id
}

resource "openstack_lb_member_v2" "pool_2_members_1" {
  count         = var.use_octavia ? var.number_of_masters : 0
  pool_id       = openstack_lb_pool_v2.pool_2[0].id
  address       = element(openstack_compute_instance_v2.k8s_master.*.access_ip_v4,count.index)
  protocol_port = 22623
}

resource "openstack_lb_member_v2" "pool_2_members_2" {
  count         = var.use_octavia ? var.number_of_boot : 0
  pool_id       = openstack_lb_pool_v2.pool_2[0].id
  address       = element(openstack_compute_instance_v2.k8s_boot.*.access_ip_v4,count.index)
  protocol_port = 22623
}

resource "openstack_lb_monitor_v2" "monitor_2" {
  count       = var.use_octavia ? 1 : 0
  pool_id     = openstack_lb_pool_v2.pool_2[0].id
  type        = "TCP"
  delay       = 10
  timeout     = 9
  max_retries = 3
}

resource "openstack_lb_listener_v2" "listener_2" {
  count           = var.use_octavia ? 1 : 0
  protocol        = "TCP"
  protocol_port   = 22623
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[0].id
  default_pool_id = openstack_lb_pool_v2.pool_2[0].id
}

resource "openstack_lb_pool_v2" "pool_3" {
  count           = var.use_octavia ? 1 : 0
  protocol        = "TCP"
  lb_method       = "SOURCE_IP"
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[0].id

  persistence {
    type        = "SOURCE_IP"
  }
}

resource "openstack_lb_member_v2" "pool_3_members_1" {
  count         = var.use_octavia ? var.number_of_workers : 0
  pool_id       = openstack_lb_pool_v2.pool_3[0].id
  address       = element(openstack_compute_instance_v2.k8s_worker.*.access_ip_v4,count.index)
  protocol_port = 80
}

resource "openstack_lb_monitor_v2" "monitor_3" {
  count       = var.use_octavia ? 1 : 0
  pool_id     = openstack_lb_pool_v2.pool_3[0].id
  type        = "TCP"
  delay       = 10
  timeout     = 9
  max_retries = 3
}

resource "openstack_lb_listener_v2" "listener_3" {
  count           = var.use_octavia ? 1 : 0
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[0].id
  default_pool_id = openstack_lb_pool_v2.pool_3[0].id
}

resource "openstack_lb_pool_v2" "pool_4" {
  count           = var.use_octavia ? 1 : 0
  protocol        = "TCP"
  lb_method       = "SOURCE_IP"
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[0].id

  persistence {
    type        = "SOURCE_IP"
  }
}

resource "openstack_lb_member_v2" "pool_4_members_1" {
  count         = var.use_octavia ? var.number_of_workers : 0
  pool_id       = openstack_lb_pool_v2.pool_4[0].id
  address       = element(openstack_compute_instance_v2.k8s_worker.*.access_ip_v4,count.index)
  protocol_port = 443
}

resource "openstack_lb_monitor_v2" "monitor_4" {
  count       = var.use_octavia ? 1 : 0
  pool_id     = openstack_lb_pool_v2.pool_4[0].id
  type        = "TCP"
  delay       = 10
  timeout     = 9
  max_retries = 3
}

resource "openstack_lb_listener_v2" "listener_4" {
  count           = var.use_octavia ? 1 : 0
  protocol        = "TCP"
  protocol_port   = 443
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb_1[0].id
  default_pool_id = openstack_lb_pool_v2.pool_4[0].id
}
