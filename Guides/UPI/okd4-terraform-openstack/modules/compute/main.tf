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
  records     = [openstack_compute_instance_v2.k8s_lb.access_ip_v4]
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
  records     = [openstack_compute_instance_v2.k8s_lb.access_ip_v4]
}

resource "openstack_dns_recordset_v2" "master_api_int" {
  zone_id     = var.dns_zone_id
  name        = "api-int.${var.cluster_name}.${var.domain_name}."
  description = "Internal master api record "
  ttl         = 300
  type        = "A"
  records     = [openstack_compute_instance_v2.k8s_lb.access_ip_v4]
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
  records     = [openstack_compute_instance_v2.k8s_lb.access_ip_v4]
}

