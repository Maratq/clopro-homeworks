# Домашнее задание 15.1 — Организация сети в Yandex Cloud

[Условия задания](../15.1.md)

## Задание 1. Публичная и приватная подсети

Создать VPC с двумя подсетями, настроить выход приватной виртуальной машины в интернет через NAT-инстанс и проверить соединение.


## Terraform-файлы

- [locals.tf](locals.tf)
- [main.tf](main.tf)
- [nat-instance.tf](nat-instance.tf)
- [outputs.tf](outputs.tf)
- [providers.tf](providers.tf)
- [resource-vm.tf](resource-vm.tf)
- [variables.tf](variables.tf)

## Решение

### 1. Схема сети

| Компонент | Подсеть | Внутренний IP | Публичный IP |
|---|---|---|---|
| `public` — виртуальная машина для SSH-подключения | `192.168.10.0/24` | `192.168.10.13` | `158.160.46.7` |
| `nat-instance` — выход приватной сети в интернет | `192.168.10.0/24` | `192.168.10.254` | `89.169.129.81` |
| `private` — приватная виртуальная машина | `192.168.20.0/24` | `192.168.20.6` | Отсутствует |

Зона — `ru-central1-a`.

```mermaid
flowchart LR
    SSH["SSH-клиент"] --> Public["public: 192.168.10.13"]
    Public --> Private["private: 192.168.20.6"]
    Public --> Internet["Интернет"]
    Private --> NAT["NAT: 192.168.10.254"]
    NAT --> Internet
```

### 2. Публичная подсеть

В VPC создана подсеть `public` с адресным диапазоном `192.168.10.0/24`.

В ней размещены:

- NAT-инстанс со статическим внутренним IP `192.168.10.254`; в условии указан образ `fd80mrhj8fl2oe87o4e1`.
- Виртуальная машина `public` с публичным IP для подключения по SSH.

**Проверка доступа в интернет с public** — результат:

```console
$ ping ya.ru
PING ya.ru (5.255.255.242) 56(84) bytes of data.
64 bytes from ya.ru (5.255.255.242): icmp_seq=1 ttl=56 time=0.599 ms
64 bytes from ya.ru (5.255.255.242): icmp_seq=2 ttl=56 time=0.234 ms
^C
--- ya.ru ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 0.234/0.416/0.599/0.182 ms
```

### 3. Приватная подсеть и маршрут через NAT

Создана подсеть `private` с диапазоном `192.168.20.0/24`. Для неё используется таблица маршрутизации, направляющая исходящий трафик на NAT-инстанс.

Таблица маршрутизации в Terraform:

```hcl
resource "yandex_vpc_route_table" "nat-instance-route" {
  name       = "private-route"
  network_id = yandex_vpc_network.develop.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = "192.168.10.254"
  }
}
```

Для использования маршрута таблица должна быть привязана к приватной подсети через `route_table_id`. Привязка задана в [main.tf](main.tf).

В подсети размещена виртуальная машина `private` с внутренним адресом `192.168.20.6`, без публичного IP.

### 4. Подключение к private через public

Подключение выполняется через SSH ProxyJump:

```bash
ssh -J ubuntu@158.160.46.7 ubuntu@192.168.20.6
```

Здесь `ubuntu` — имя пользователя для SSH-аутентификации, а IP-адреса — параметры подключения. 

**Проверка доступа в интернет с private** — вывод:

```console
$ ping ya.ru
PING ya.ru (77.88.44.242) 56(84) bytes of data.
64 bytes from ya.ru (77.88.44.242): icmp_seq=1 ttl=53 time=6.03 ms
64 bytes from ya.ru (77.88.44.242): icmp_seq=2 ttl=53 time=5.49 ms
^C
--- ya.ru ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 5.485/5.758/6.031/0.273 ms
```

### 5. Созданные виртуальные машины

Команда просмотра:

```bash
yc compute instance list
```

Сводка:

| NAME | ZONE ID | STATUS | EXTERNAL IP | INTERNAL IP |
|---|---|---|---|---|
| private | ru-central1-a | RUNNING | — | 192.168.20.6 |
| nat-instance | ru-central1-a | RUNNING | 89.169.129.81 | 192.168.10.254 |
| public | ru-central1-a | RUNNING | 158.160.46.7 | 192.168.10.13 |

<details>
<summary>Outputs Terraform</summary>

```hcl
VM-private = {
  "ip_external" = ""
  "ip_internal" = "192.168.20.6"
  "name"        = "private"
}
VM-public = {
  "ip_external" = "158.160.46.7"
  "ip_internal" = "192.168.10.13"
  "name"        = "public"
}
nat-instance = {
  "ip_external" = "89.169.129.81"
  "ip_internal" = "192.168.10.254"
  "name"        = "nat-instance"
}
```

</details>

### Результат

Обе машины успешно получают ответы от `ya.ru`: по два отправленных и полученных пакета, потери — 0%. Приватная машина не имеет публичного IP; для неё показана схема выхода через NAT.

