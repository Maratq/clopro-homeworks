terraform {
  required_version = ">= 1.5.0, < 2.0.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.248.0"
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
}

variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "network_id" {
  type = string
}

variable "public_a_subnet_id" {
  type = string
}

variable "private_a_subnet_id" {
  type = string
}

variable "kms_key_id" {
  type = string
}

variable "operator_cidr" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.operator_cidr)) && try(tonumber(split("/", var.operator_cidr)[1]) == 32, false)
    error_message = "Use the operator's public IPv4 address with a /32 mask."
  }
}

variable "mysql_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.mysql_password) >= 12 && length(var.mysql_password) <= 128
    error_message = "Use a MySQL password between 12 and 128 characters."
  }
}

variable "mysql_preset" {
  type    = string
  default = "s2.micro"
}

variable "mysql_deletion_protection" {
  type    = bool
  default = true
}

data "yandex_vpc_subnet" "public_a" {
  subnet_id = var.public_a_subnet_id
}

data "yandex_vpc_subnet" "private_a" {
  subnet_id = var.private_a_subnet_id
}

locals {
  public_additions = {
    "ru-central1-b" = "192.168.11.0/24"
    "ru-central1-d" = "192.168.12.0/24"
  }
  public_subnet_ids = merge(
    { "ru-central1-a" = data.yandex_vpc_subnet.public_a.id },
    { for zone, subnet in yandex_vpc_subnet.public : zone => subnet.id }
  )
  private_cidr_b = "192.168.21.0/24"
  pods_cidr      = "10.112.0.0/16"
  services_cidr  = "10.96.0.0/16"
}

resource "yandex_vpc_subnet" "public" {
  for_each       = local.public_additions
  name           = "hw154-public-${substr(each.key, -1, 1)}"
  zone           = each.key
  network_id     = var.network_id
  v4_cidr_blocks = [each.value]
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "hw154-private-b"
  zone           = "ru-central1-b"
  network_id     = var.network_id
  v4_cidr_blocks = [local.private_cidr_b]
}

output "kubernetes_cluster_id" {
  value = yandex_kubernetes_cluster.lab.id
}

output "kubernetes_node_groups" {
  value = { for zone, group in yandex_kubernetes_node_group.zone : zone => group.id }
}

output "mysql_cluster_id" {
  value = yandex_mdb_mysql_cluster.lab.id
}

output "mysql_hosts" {
  value = [for host in yandex_mdb_mysql_cluster.lab.host : host.fqdn]
}
