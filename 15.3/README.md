# 15.3. Шифрование Object Storage ключом KMS

[Условия задания](../15.3.md) · [KMS и права доступа](kms.tf) · [Изменения бакета 15.2](bucket-encryption.patch)

Создаём симметричный ключ AES-256 в том же каталоге, что и бакет из 15.2. Сервисному аккаунту бакета выдаём право шифрования и расшифрования на конкретный ключ. Для бакета включаем шифрование по умолчанию с алгоритмом `aws:kms`. Идентификатор ключа доступен через Terraform output и используется в 15.4.

## Применение к бакету 15.2

Из корня репозитория в рабочей копии с конфигурацией 15.2:

```bash
git apply --check 15.3/bucket-encryption.patch
git apply 15.3/bucket-encryption.patch
cp 15.3/kms.tf 15.2/kms-15-3.tf
cd 15.2
terraform init
terraform validate
terraform plan -out=hw153.tfplan
```

Используйте прежние значения переменных и **тот же Terraform state**, в котором уже есть `yandex_storage_bucket.picture`. Если state сохранён в другом месте, укажите его при планировании через `-state=/путь/к/terraform.tfstate` для локального backend. В плане бакет должен обновляться на месте. После проверки плана:

```bash
terraform apply hw153.tfplan
KEY_ID=$(terraform output -raw kms_key_id)
```

Публичное чтение `picture.svg` меняется на приватное. Браузер со страницы LAMP 15.2 больше не сможет анонимно загрузить картинку по старому URL. Для чтения объекта нужен авторизованный запрос с правом расшифрования.

## Проверка шифрования

Используйте AWS CLI с настроенным профилем Object Storage. У субъекта должны быть права чтения и записи объекта, а также право шифрования и расшифрования на ключ.

```bash
export BUCKET='<имя существующего бакета>'
export AWS_PROFILE='<профиль Object Storage>'
endpoint=https://storage.yandexcloud.net

aws --endpoint-url "$endpoint" s3api get-bucket-encryption --bucket "$BUCKET"
aws --endpoint-url "$endpoint" s3api head-object \
  --bucket "$BUCKET" --key picture.svg \
  --query '{Algorithm:ServerSideEncryption,Key:SSEKMSKeyId}'
```

Настройка бакета распространяется на новые записи. Если `HeadObject` показывает, что `picture.svg` ещё не использует нужный ключ, перезапишите его из проверенного исходного файла в каталоге 15.2:

```bash
aws --endpoint-url "$endpoint" s3api put-object \
  --bucket "$BUCKET" --key picture.svg --body picture.svg \
  --acl private --content-type image/svg+xml \
  --server-side-encryption aws:kms --ssekms-key-id "$KEY_ID"

aws --endpoint-url "$endpoint" s3api head-object \
  --bucket "$BUCKET" --key picture.svg \
  --query '{Algorithm:ServerSideEncryption,Key:SSEKMSKeyId}'
```

Результат проверки: алгоритм `aws:kms` и идентификатор ключа из `kms_key_id`. Для других существующих объектов проверка и перезапись выполняются отдельно, с сохранением их содержимого и нужных метаданных. Ключ должен оставаться доступен, пока в бакете есть объекты, зашифрованные им.

[Документация Yandex Cloud по шифрованию Object Storage](https://yandex.cloud/en/docs/storage/operations/buckets/encrypt).
