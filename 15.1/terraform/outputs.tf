output "VM-public" {
  value = {
    name        = yandex_compute_instance.public.name
    ip_internal = yandex_compute_instance.public.network_interface[0].ip_address
    ip_external = yandex_compute_instance.public.network_interface[0].nat_ip_address
  }
}
output "VM-private" {
  value = {
    name        = yandex_compute_instance.private.name
    ip_internal = yandex_compute_instance.private.network_interface[0].ip_address
    ip_external = yandex_compute_instance.private.network_interface[0].nat_ip_address
  }
}
output "nat-instance" {
  value = {
    name        = yandex_compute_instance.nat.name
    ip_internal = yandex_compute_instance.nat.network_interface[0].ip_address
    ip_external = yandex_compute_instance.nat.network_interface[0].nat_ip_address
  }
}
output "public_ip" {
  value = yandex_compute_instance.public.network_interface[0].nat_ip_address
}
output "private_ip" {
  value = yandex_compute_instance.private.network_interface[0].ip_address
}
