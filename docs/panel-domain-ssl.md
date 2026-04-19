# Домен и SSL для панели

Этот режим добавляет отдельный HTTPS-вход для панели и подписок через `Caddy`, не затрагивая `VLESS Reality` на `443/tcp`.

## Почему панель вынесена на другой HTTPS-порт

У вас `VLESS TCP Reality` уже слушает `443/tcp`. Поэтому доменная HTTPS-панель не может занять тот же порт. В проекте для панели используется отдельный внешний порт, по умолчанию `8443/tcp`.

Итоговая схема:

- `443/tcp` — `VLESS Reality`
- `80/tcp` — ACME challenge для Let's Encrypt
- `8443/tcp` — HTTPS-панель и подписки через `Caddy`

## Что меняется автоматически

При запуске профиля `secure-panel` bootstrap:

- переводит панель на нестандартный внутренний порт `PANEL_INTERNAL_PORT`
- задаёт уникальный `PANEL_WEB_BASE_PATH`
- задаёт уникальный `SUBSCRIPTION_PATH`
- прописывает домен в настройках панели и подписок

А `Caddy`:

- получает сертификат Let's Encrypt для вашего домена
- автоматически продлевает его
- проксирует HTTPS-запросы к панели и подпискам

## Что заполнить в `.env`

Минимально:

```env
PANEL_DOMAIN=tema.asmart-viewdemo.ru
PANEL_HTTPS_PORT=8443
PANEL_INTERNAL_PORT=38453
PANEL_SUBSCRIPTION_INTERNAL_PORT=2096
PANEL_WEB_BASE_PATH=panel-a8m4v7q2r9x6
SUBSCRIPTION_PATH=sub-k3n8p5t1y7w4
PANEL_PUBLIC_SCHEME=https
```

Важно:

- `PANEL_WEB_BASE_PATH` и `SUBSCRIPTION_PATH` указываются **без** начального `/`
- домен должен уже резолвиться на IP вашего VPS
- на VPS должны быть открыты `80/tcp` и `${PANEL_HTTPS_PORT}/tcp`

## Как запускать

```bash
docker compose pull
docker compose --profile secure-panel up -d
```

Проверка:

```bash
docker compose ps
docker compose logs bootstrap --tail=200
docker compose --profile secure-panel logs caddy --tail=200
```

## Какие URL получатся

После запуска bootstrap сохранит итоговые адреса в:

- `output/client/panel-info.json`
- `output/client/connection-info.json`
- `output/client/IMPORT-NOTES.txt`

Типичный результат:

- панель: `https://tema.asmart-viewdemo.ru:8443/panel-a8m4v7q2r9x6/`
- база подписок: `https://tema.asmart-viewdemo.ru:8443/sub-k3n8p5t1y7w4/`

## Что может остаться вручную

Если в самой панели предупреждение ещё не исчезло сразу после первого запуска:

1. перезагрузите страницу по новому HTTPS-адресу
2. войдите уже через доменное URL, а не по IP
3. проверьте, что в `.env` заданы не пустые `PANEL_WEB_BASE_PATH` и `SUBSCRIPTION_PATH`

## Источники

- `3x-ui` configuration and reverse proxy:
  - https://github.com/MHSanaei/3x-ui/wiki/Configuration
- `3x-ui` settings controller routes:
  - https://github.com/MHSanaei/3x-ui/blob/main/web/controller/setting.go
- `Caddy` automatic HTTPS:
  - https://caddyserver.com/docs/automatic-https
- `Caddy` global options:
  - https://caddyserver.com/docs/caddyfile/options
