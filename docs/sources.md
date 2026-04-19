# Источники

Ниже список материалов, которые были использованы при проектировании этой конфигурации.

## Routing rules и geo-файлы

- `runetfreedom/russia-v2ray-rules-dat`
  - https://github.com/runetfreedom/russia-v2ray-rules-dat
  - взяты как источник обновляемых `geoip.dat` и `geosite.dat`
- `runetfreedom/russia-v2ray-custom-routing-list`
  - https://github.com/runetfreedom/russia-v2ray-custom-routing-list
  - использован как база для клиентских routing-пресетов и DNS-настроек

## Практические идеи по Reality и split routing

- `Sergei-thinker/vpn-setup`
  - https://github.com/Sergei-thinker/vpn-setup
  - использованы практические замечания по donor/SNI, split routing и общему hardening
- Habr: `Прозрачный прокси-шлюз на роутере: VLESS + Reality + TPROXY на OpenWrt от А до Я`
  - https://habr.com/ru/articles/1020866/
  - взята логика direct-routing для `geoip:ru`, `geosite:ru-available-only-inside` и RU-доменных зон
- Habr: `Мой VPN пережил белые списки. Архитектура из 4 уровней за 265₽ в месяц`
  - https://habr.com/ru/articles/1021160/
  - подтверждена общая схема: основной Layer 0 на `VLESS Reality`, а split routing делается именно на клиенте

## Документация 3x-ui

- `MHSanaei/3x-ui`
  - https://github.com/MHSanaei/3x-ui
- Docker installation
  - https://github.com/MHSanaei/3x-ui/wiki/Installation
- Configuration and API
  - https://github.com/MHSanaei/3x-ui/wiki/Configuration

## Что из этого не включено специально

В проект не добавлялись:

- обход белых списков через relay/Yandex Cloud
- Cloudflare backup
- доменная маскировка панели

Это сделано специально, потому что вы отдельно написали, что обход белых списков вам сейчас не нужен.
