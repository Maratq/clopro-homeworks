# 15.4. Managed MySQL и Kubernetes в Yandex Cloud

[Условия задания](../15.4.md) · [VPC и переменные](main.tf) · [MySQL](mysql.tf) · [Kubernetes и IAM](kubernetes.tf) · [Пример параметров](terraform.tfvars.example)

Используем существующую VPC из 15.1 и KMS-ключ из [15.3](../15.3/README.md). Публичную и приватную подсети зоны `ru-central1-a` подключаем по ID. В этой же VPC Terraform добавляет две публичные подсети и одну приватную.

| Зона | Kubernetes | MySQL |
|---|---|---|
| `ru-central1-a` | Существующая public | Существующая private |
| `ru-central1-b` | Новая public `192.168.11.0/24` | Новая private `192.168.21.0/24` |
| `ru-central1-d` | Новая public `192.168.12.0/24` | — |

**MySQL.** Два хоста в разных зонах без публичных IP. Сервис управляет репликацией и выбором мастера. Конфигурация задаёт `PRESTABLE`, MySQL 8.0, SSD 20 ГБ на хост, обслуживание `ANYTIME`, резервное копирование в 23:59 UTC и защиту от удаления. Пользователь `netology` получает права в БД `netology_db`. Класс Intel Broadwell с гарантией 50% CPU из задания недоступен для новых кластеров. Выбран документированный класс `s2.micro` с гарантией 100% CPU. [Классы хостов MySQL](https://yandex.cloud/en/docs/managed-mysql/concepts/instance-types).

**Kubernetes.** Региональный мастер размещён в трёх зонах. Для шифрования Kubernetes Secrets используется ключ из 15.3. Отдельный сервисный аккаунт получает роли для кластера, сети и скачивания образов. Доступ к внешнему API ограничен IP оператора. Группа с автомасштабированием в Yandex Cloud привязана к одной зоне, поэтому создаются три группы, каждая с начальным размером 1 и максимумом 2. Всего от 3 до 6 рабочих узлов. [Группы узлов Yandex Cloud](https://yandex.cloud/en/docs/managed-kubernetes/operations/node-group/node-group-create).

## Развёртывание

Из каталога `15.4`:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Заполните ID облака, каталога, VPC, двух существующих подсетей зоны A и KMS-ключа. В `operator_cidr` укажите текущий внешний IPv4 оператора с маской `/32`. Убедитесь, что новые CIDR и диапазоны Pod/Service не пересекаются с действующими сетями.

```bash
export YC_TOKEN="$(yc iam create-token)"
read -r -s -p 'MySQL password: ' TF_VAR_mysql_password
export TF_VAR_mysql_password
printf '\n'

terraform init
terraform validate
terraform plan -out=hw154.tfplan
terraform apply hw154.tfplan
unset TF_VAR_mysql_password
```

Команды с `read -p` рассчитаны на Bash. Terraform state и план содержат чувствительные данные и хранятся вне Git.

## Проверка

```bash
mysql_id=$(terraform output -raw mysql_cluster_id)
k8s_id=$(terraform output -raw kubernetes_cluster_id)

yc managed-mysql cluster get "$mysql_id"
yc managed-mysql host list --cluster-id "$mysql_id"
yc managed-mysql database list --cluster-id "$mysql_id"
yc managed-mysql user list --cluster-id "$mysql_id"

yc managed-kubernetes cluster get "$k8s_id"
yc managed-kubernetes node-group list --cluster-id "$k8s_id"
export KUBECONFIG="$PWD/.terraform/hw154-kubeconfig"
yc managed-kubernetes cluster get-credentials "$k8s_id" --external
kubectl cluster-info
kubectl get nodes -L topology.kubernetes.io/zone
```

В MySQL проверьте два хоста в разных зонах, роли мастера и реплики, время бэкапа, защиту и наличие БД. В Kubernetes проверьте KMS key ID, три зоны мастера и начальные три узла со статусом `Ready`. Пределы автомасштабирования проверяются по описанию каждой группы, фактическое увеличение числа узлов требует отдельной нагрузки.

Для удаления учебного стенда сначала примените настройку `mysql_deletion_protection = false` в той же конфигурации и проверьте план удаления. Существующую VPC, подсети 15.1 и ключ 15.3 этот Terraform state не удаляет.
