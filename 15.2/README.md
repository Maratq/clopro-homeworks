# 15.2. Вычислительные мощности и балансировка нагрузки

В Yandex Cloud через Terraform развёрнуты три ВМ с LAMP, сетевой балансировщик с проверкой `/healthz` и бакет с публичной картинкой.

[Terraform](main.tf) · [cloud-init](cloud-init.yaml.tftpl) · [Сайт](http://37.230.168.186/) · [Картинка из Object Storage](https://storage.yandexcloud.net/marat-lamp-20261118-2026-a5jtk7/picture.svg)

## Скриншоты

![Публичная картинка](screenshots/01-public-picture.jpg)

| До удаления | Удаление ВМ | Во время замены | После восстановления |
|---|---|---|---|
| ![Три ВМ](screenshots/02-before-deletion.jpg) | ![Операция удаления](screenshots/03-delete-operation.jpg) | ![Оставшиеся цели](screenshots/04-during-deletion.jpg) | ![Восстановленная группа](screenshots/05-recovered.jpg) |
