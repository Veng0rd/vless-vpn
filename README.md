# VLESS TCP Reality + 3x-ui + split routing for RU traffic

Этот проект поднимает на сервере в Нидерландах базовый стек `3x-ui`/`Xray` в Docker и автоматически создаёт `VLESS TCP Reality` inbound. Параллельно он тянет актуальные routing-артефакты `runetfreedom` и готовит клиентские файлы, чтобы российские сервисы шли напрямую под вашим домашним IP, а остальной трафик уходил через VPN.

Ключевой момент: split routing, при котором российские сервисы видят ваш реальный IP, делается **на клиенте или на роутере**, а не на сервере в Нидерландах. Сервер только принимает VPN-подключение и выводит зарубежный трафик наружу.

Стек рассчитан на **Linux VPS**. В `compose.yaml` используется `network_mode: host`, поэтому локальный Docker на Windows/macOS не является полноценной проверкой рабочего рантайма.

## Что входит

- `3x-ui` в Docker c host network
- bootstrap-скрипт, который через API панели создаёт `VLESS TCP Reality` inbound
- фоновая синхронизация `geoip.dat`, `geosite.dat` и клиентских routing-шаблонов из `runetfreedom`
- готовый кастомный routing-пресет для сценария `всё кроме РФ через VPN`
- документация по запуску, безопасности и подключению клиента

## Нужен ли домен

Для базового `VLESS TCP Reality` домен не нужен. Он понадобится только если позже захотите:

- прятать панель за `HTTPS` reverse proxy
- делать CDN/Cloudflare backup
- получать ACME-сертификаты на доменное имя

Для текущей конфигурации достаточно публичного IP вашего VPS.

Если домен уже есть, проект умеет поднять отдельный HTTPS-вход для панели и подписок через `Caddy` с автоматическим выпуском и продлением сертификата. Подробности: [docs/panel-domain-ssl.md](docs/panel-domain-ssl.md)

## Быстрый старт

1. Скопируйте `.env.example` в `.env`.
2. Заполните минимум `OUTPUT_HOST` реальным публичным IP сервера.
3. При желании поменяйте `VLESS_PORT`, `REALITY_DEST` и `REALITY_SERVER_NAMES`.
4. На сервере выполните:

```bash
docker compose pull
docker compose up -d
```

5. Подождите 20-60 секунд и проверьте:

```bash
docker compose ps
docker compose logs bootstrap --tail=200
docker compose logs rules-sync --tail=50
```

6. Готовые артефакты появятся в `output/client/`:

- `vless-uri.txt` — ссылка для импорта в клиент
- `connection-info.json` — разложенные параметры подключения
- `IMPORT-NOTES.txt` — краткая памятка

7. Актуальные routing-файлы появятся в `output/rules/`.

## Режим с доменом и SSL

Если хотите убрать предупреждения панели про небезопасный доступ, используйте профиль `secure-panel`:

```bash
docker compose pull
docker compose --profile secure-panel up -d
```

Перед этим заполните в `.env`:

- `PANEL_DOMAIN`
- `PANEL_WEB_BASE_PATH`
- `SUBSCRIPTION_PATH`
- `PANEL_INTERNAL_PORT`
- `PANEL_HTTPS_PORT`

Подробная инструкция: [docs/panel-domain-ssl.md](docs/panel-domain-ssl.md)

## Как использовать клиент

Базовый путь для `v2rayN` / `v2rayNG`:

1. Импортируйте `output/client/vless-uri.txt`.
2. Включите `TUN` режим.
3. Обновите geo-файлы в клиенте.
4. Импортируйте routing-пресет [templates/v2rayn-routing-custom.json](templates/v2rayn-routing-custom.json).

Подробности: [docs/client-routing.md](docs/client-routing.md)

## Безопасность

- Не держите `2053/tcp` панели открытым наружу без необходимости.
- Лучше оставлять снаружи только `SSH` и `VLESS_PORT`.
- После первого входа в `3x-ui` сразу смените `admin/admin`.
- Панель удобнее открывать через `SSH` tunnel, а не публиковать в интернет.

## Структура

- `compose.yaml` — основной Docker-стек
- `scripts/bootstrap-3xui.sh` — создаёт Reality inbound и клиентские артефакты
- `scripts/sync-routing-rules.sh` — подтягивает и обновляет routing-файлы
- `templates/v2rayn-routing-custom.json` — кастомный пресет `всё кроме РФ через VPN`
- `templates/xray-routing-snippet.json` — routing-snippet для клиентов с raw Xray config
- `docs/architecture.md` — принятые решения
- `docs/client-routing.md` — подключение клиентской части
- `docs/panel-domain-ssl.md` — домен, HTTPS и автообновление сертификата
- `docs/sources.md` — изученные источники и что взято из них

## Что проверим позже на вашем сервере

Когда дадите доступ, я проверю:

- корректность запуска контейнеров
- доступность панели и Reality inbound
- выбранный SNI/donor с вашего VPS
- firewall и лишние открытые порты
- импорт в клиент и split routing на практике
