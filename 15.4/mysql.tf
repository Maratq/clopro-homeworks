resource "yandex_vpc_security_group" "mysql" {
  name       = "hw154-mysql"
  network_id = var.network_id

  ingress {
    protocol          = "TCP"
    port              = 3306
    security_group_id = yandex_vpc_security_group.kubernetes.id
  }

  ingress {
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_mysql_cluster" "lab" {
  name                = "hw154-mysql"
  environment         = "PRESTABLE"
  network_id          = var.network_id
  version             = "8.0"
  deletion_protection = var.mysql_deletion_protection
  security_group_ids  = [yandex_vpc_security_group.mysql.id]

  resources {
    resource_preset_id = var.mysql_preset
    disk_type_id       = "network-ssd"
    disk_size          = 20
  }

  maintenance_window {
    type = "ANYTIME"
  }

  backup_window_start {
    hours   = 23
    minutes = 59
  }

  host {
    name             = "mysql-a"
    zone             = "ru-central1-a"
    subnet_id        = data.yandex_vpc_subnet.private_a.id
    assign_public_ip = false
  }

  host {
    name             = "mysql-b"
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.private_b.id
    assign_public_ip = false
  }

  lifecycle {
    precondition {
      condition     = data.yandex_vpc_subnet.private_a.network_id == var.network_id && data.yandex_vpc_subnet.private_a.zone == "ru-central1-a"
      error_message = "The existing private subnet must belong to the selected VPC in ru-central1-a."
    }
  }
}

resource "yandex_mdb_mysql_database" "netology" {
  cluster_id = yandex_mdb_mysql_cluster.lab.id
  name       = "netology_db"
}

resource "yandex_mdb_mysql_user" "netology" {
  cluster_id = yandex_mdb_mysql_cluster.lab.id
  name       = "netology"
  password   = var.mysql_password

  permission {
    database_name = yandex_mdb_mysql_database.netology.name
    roles         = ["ALL"]
  }
}
