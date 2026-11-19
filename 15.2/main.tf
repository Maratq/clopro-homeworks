terraform {
  required_version = ">= 1.5.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.140, < 1.0"
    }
  }
}

# Authentication: YC_TOKEN environment variable. Never commit credentials.
provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "existing_network_id" {
  description = "Existing VPC to use when the folder cannot create another network."
  type        = string
  default     = null
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "lamp_image_id" {
  type    = string
  default = "fd827b91d99psvq5fjit"
}

locals {
  prefix     = "hw-lamp"
  image_url  = "https://storage.yandexcloud.net/${yandex_storage_bucket.picture.bucket}/picture.svg"
  network_id = var.existing_network_id == null ? yandex_vpc_network.public[0].id : var.existing_network_id
}

resource "yandex_iam_service_account" "group" {
  name = "${local.prefix}-group"
}

resource "yandex_resourcemanager_folder_iam_member" "group" {
  for_each  = toset(["compute.editor", "load-balancer.editor", "vpc.publicAdmin"])
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.group.id}"
}

resource "yandex_iam_service_account" "storage" {
  name = "${local.prefix}-storage"
}

resource "yandex_resourcemanager_folder_iam_member" "storage_admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.storage.id}"
}

resource "yandex_iam_service_account_static_access_key" "storage" {
  service_account_id = yandex_iam_service_account.storage.id
  description        = "Terraform homework Object Storage"
  depends_on         = [yandex_resourcemanager_folder_iam_member.storage_admin]
}

resource "yandex_storage_bucket" "picture" {
  bucket     = var.bucket_name
  folder_id  = var.folder_id
  access_key = yandex_iam_service_account_static_access_key.storage.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage.secret_key
}

resource "yandex_storage_object" "picture" {
  bucket       = yandex_storage_bucket.picture.bucket
  key          = "picture.svg"
  source       = "${path.module}/picture.svg"
  source_hash  = filemd5("${path.module}/picture.svg")
  content_type = "image/svg+xml"
  acl          = "public-read"
  access_key   = yandex_iam_service_account_static_access_key.storage.access_key
  secret_key   = yandex_iam_service_account_static_access_key.storage.secret_key
}

resource "yandex_vpc_network" "public" {
  count = var.existing_network_id == null ? 1 : 0
  name  = "${local.prefix}-network"
}

resource "yandex_vpc_subnet" "public" {
  name           = "${local.prefix}-public"
  zone           = var.zone
  network_id     = local.network_id
  v4_cidr_blocks = ["10.76.10.0/24"]
}

resource "yandex_vpc_security_group" "web" {
  name       = "${local.prefix}-web"
  network_id = local.network_id
  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol          = "TCP"
    port              = 80
    predefined_target = "loadbalancer_healthchecks"
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance_group" "lamp" {
  name               = "${local.prefix}-group"
  folder_id          = var.folder_id
  service_account_id = yandex_iam_service_account.group.id
  depends_on         = [yandex_resourcemanager_folder_iam_member.group, yandex_storage_object.picture]

  instance_template {
    name        = "${local.prefix}-{instance.index}"
    platform_id = "standard-v3"
    resources {
      cores         = 2
      memory        = 2
      core_fraction = 20
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = var.lamp_image_id
        size     = 3
        type     = "network-hdd"
      }
    }
    network_interface {
      network_id         = local.network_id
      subnet_ids         = [yandex_vpc_subnet.public.id]
      nat                = true
      security_group_ids = [yandex_vpc_security_group.web.id]
    }
    metadata = {
      user-data = templatefile("${path.module}/cloud-init.yaml.tftpl", { image_url = local.image_url })
    }
  }
  scale_policy {
    fixed_scale { size = 3 }
  }
  allocation_policy { zones = [var.zone] }
  deploy_policy {
    max_unavailable  = 1
    max_expansion    = 0
    startup_duration = 60
  }
  health_check {
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    http_options {
      port = 80
      path = "/healthz"
    }
  }
  load_balancer {
    target_group_name = "${local.prefix}-targets"
  }
}

resource "yandex_lb_network_load_balancer" "web" {
  name = "${local.prefix}-nlb"
  type = "external"
  listener {
    name        = "http"
    port        = 80
    target_port = 80
    external_address_spec { ip_version = "ipv4" }
  }
  attached_target_group {
    target_group_id = yandex_compute_instance_group.lamp.load_balancer[0].target_group_id
    healthcheck {
      name                = "http"
      interval            = 5
      timeout             = 2
      healthy_threshold   = 2
      unhealthy_threshold = 3
      http_options {
        port = 80
        path = "/healthz"
      }
    }
  }
}

output "website_url" {
  value = "http://${one(one(yandex_lb_network_load_balancer.web.listener).external_address_spec).address}"
}
output "picture_url" { value = local.image_url }
output "instance_group_id" { value = yandex_compute_instance_group.lamp.id }
output "load_balancer_id" { value = yandex_lb_network_load_balancer.web.id }
output "target_group_id" { value = yandex_compute_instance_group.lamp.load_balancer[0].target_group_id }
