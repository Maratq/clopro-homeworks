data "yandex_compute_image" "ubuntu" {
  family = var.ubuntu_image_family
}
locals {
  ssh_key = "ubuntu:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
}
resource "yandex_compute_instance" "nat" {
  name        = "nat-instance"
  platform_id = "standard-v3"
  zone        = var.zone
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = var.nat_image_id
      size     = 20
      type     = "network-hdd"
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    ip_address         = "192.168.10.254"
    nat                = true
    security_group_ids = [yandex_vpc_security_group.lab.id]
  }
  metadata = { ssh-keys = local.ssh_key }
}
resource "yandex_compute_instance" "public" {
  name        = "public"
  platform_id = "standard-v3"
  zone        = var.zone
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    ip_address         = "192.168.10.13"
    nat                = true
    security_group_ids = [yandex_vpc_security_group.lab.id]
  }
  metadata = { ssh-keys = local.ssh_key }
}
resource "yandex_compute_instance" "private" {
  name        = "private"
  platform_id = "standard-v3"
  zone        = var.zone
  depends_on  = [yandex_compute_instance.nat]
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.private.id
    ip_address         = "192.168.20.6"
    nat                = false
    security_group_ids = [yandex_vpc_security_group.lab.id]
  }
  metadata = { ssh-keys = local.ssh_key }
}
