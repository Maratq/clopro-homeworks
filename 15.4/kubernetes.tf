resource "yandex_iam_service_account" "kubernetes" {
  name      = "hw154-kubernetes"
  folder_id = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "kubernetes" {
  for_each  = toset(["k8s.clusters.agent", "vpc.publicAdmin", "container-registry.images.puller"])
  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.kubernetes.id}"
}

resource "yandex_kms_symmetric_key_iam_member" "kubernetes" {
  symmetric_key_id = var.kms_key_id
  role             = "kms.keys.encrypterDecrypter"
  member           = "serviceAccount:${yandex_iam_service_account.kubernetes.id}"
}

resource "yandex_vpc_security_group" "kubernetes" {
  name       = "hw154-kubernetes"
  network_id = var.network_id

  ingress {
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = [local.pods_cidr, local.services_cidr]
  }

  ingress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = [var.operator_cidr]
  }

  ingress {
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = [var.operator_cidr]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_kubernetes_cluster" "lab" {
  name                    = "hw154-kubernetes"
  network_id              = var.network_id
  service_account_id      = yandex_iam_service_account.kubernetes.id
  node_service_account_id = yandex_iam_service_account.kubernetes.id
  cluster_ipv4_ranges     = [local.pods_cidr]
  service_ipv4_range      = local.services_cidr
  release_channel         = "STABLE"

  master {
    public_ip          = true
    security_group_ids = [yandex_vpc_security_group.kubernetes.id]

    regional {
      region = "ru-central1"
      dynamic "location" {
        for_each = local.public_subnet_ids
        content {
          zone      = location.key
          subnet_id = location.value
        }
      }
    }
  }

  kms_provider {
    key_id = var.kms_key_id
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.kubernetes,
    yandex_kms_symmetric_key_iam_member.kubernetes,
  ]

  lifecycle {
    precondition {
      condition     = data.yandex_vpc_subnet.public_a.network_id == var.network_id && data.yandex_vpc_subnet.public_a.zone == "ru-central1-a"
      error_message = "The existing public subnet must belong to the selected VPC in ru-central1-a."
    }
  }
}

resource "yandex_kubernetes_node_group" "zone" {
  for_each   = local.public_subnet_ids
  cluster_id = yandex_kubernetes_cluster.lab.id
  name       = "hw154-${substr(each.key, -1, 1)}"

  instance_template {
    platform_id = "standard-v3"

    network_interface {
      subnet_ids         = [each.value]
      nat                = true
      security_group_ids = [yandex_vpc_security_group.kubernetes.id]
    }

    resources {
      cores  = 2
      memory = 4
    }

    boot_disk {
      type = "network-ssd"
      size = 64
    }

    container_runtime {
      type = "containerd"
    }
  }

  allocation_policy {
    location {
      zone      = each.key
      subnet_id = each.value
    }
  }

  scale_policy {
    auto_scale {
      min     = 1
      initial = 1
      max     = 2
    }
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
  }
}
