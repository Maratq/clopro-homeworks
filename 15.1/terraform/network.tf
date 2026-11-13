resource "yandex_vpc_network" "develop" {
  name = "develop"
}
resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = var.zone
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}
resource "yandex_vpc_route_table" "nat-instance-route" {
  name       = "private-route"
  network_id = yandex_vpc_network.develop.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = "192.168.10.254"
  }
}
resource "yandex_vpc_subnet" "private" {
  name           = "private"
  zone           = var.zone
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.nat-instance-route.id
}
resource "yandex_vpc_security_group" "lab" {
  name       = "network-lab"
  network_id = yandex_vpc_network.develop.id
  ingress {
    description    = "SSH from administrator"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description    = "Internal traffic including traffic forwarded through NAT"
    protocol       = "ANY"
    v4_cidr_blocks = ["192.168.10.0/24", "192.168.20.0/24"]
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
