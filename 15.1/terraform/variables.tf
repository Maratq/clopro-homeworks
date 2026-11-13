variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}
variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}
variable "zone" {
  type    = string
  default = "ru-central1-a"
}
variable "ssh_public_key_path" {
  description = "Path to an existing SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
variable "admin_cidr" {
  description = "Administrator public IPv4 CIDR allowed to connect by SSH"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "Specify your public IPv4 CIDR, for example 203.0.113.10/32."
  }
}
variable "nat_image_id" {
  description = "NAT image from the assignment; may be overridden with an available NAT image ID"
  type        = string
  default     = "fd80mrhj8fl2oe87o4e1"
}
variable "ubuntu_image_family" {
  type    = string
  default = "ubuntu-2204-lts"
}
