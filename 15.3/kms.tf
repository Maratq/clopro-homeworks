resource "yandex_kms_symmetric_key" "homework" {
  name                = "hw-cloud-encryption"
  folder_id           = var.folder_id
  default_algorithm   = "AES_256"
  rotation_period     = "8760h"
  deletion_protection = true
}

resource "yandex_kms_symmetric_key_iam_member" "storage" {
  symmetric_key_id = yandex_kms_symmetric_key.homework.id
  role             = "kms.keys.encrypterDecrypter"
  member           = "serviceAccount:${yandex_iam_service_account.storage.id}"
}

output "kms_key_id" {
  value = yandex_kms_symmetric_key.homework.id
}
