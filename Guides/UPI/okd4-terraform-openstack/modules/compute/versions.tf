terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "3.4.2"
    }
  }
}
