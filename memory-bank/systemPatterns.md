# System Patterns — Kommunalka

## Архитектура (слои `lib/`)
- `models/` — доменные модели (supplier, channel, reading, payment, receipt).
- `database/` — drift: `app_database.dart`, `tables/`, `daos/`; `.g.dart` — генерируются (build_runner).
- `repositories/` — репозитории над Supabase + drift; `repository_exceptions.dart` — доменные исключения.
- `providers/` — Riverpod-провайдеры.
- `services/` — auth, storage, settings, excel_report, yandex_disk, supabase_tables.
- `screens/` — экраны (auth, shell, suppliers_list, supplier_card, supplier_form, reading_entry, payment, receipt, history, reports, settings).
- `utils/` — чистые функции-хелперы (date_format, amount_format, payment_status_format, bank_details_format, supplier_category_icon, json_parsing, qr_parser).
- `widgets/` — переиспользуемые виджеты.

Корневые: `main.dart` (Supabase init), `app.dart` (MaterialApp.router), `router.dart` (go_router + StatefulShellRoute).

## Состояние и навигация
- Riverpod (`flutter_riverpod`) — провайдеры для асинхронной работы.
- go_router: `StatefulShellRoute.indexedStack` с 4 ветками (Поставщики/История/Отчёты/Настройки).
- `GoRouterRefreshStream` — мост Stream → Listenable для redirect при входе/выходе.

## Работа с данными
- Паттерн Repository + DAO.
- Синхронизация — pull (при старте/открытии экрана/pull-to-refresh), без realtime в MVP.
- Офлайн в MVP: только просмотр загруженного.
- Ошибки — доменные исключения (напр. `ChannelHasReadingsException`).

## Стиль кода
- Комментарии/докстринги — на русском, код — английский.
- Глаголы в именах методов, явные имена, без сокращений.
- Полная обработка ошибок.
- «Одна точка правды» для форматирования (`utils/`).
- Чистые функции (парсер/генератор QR, форматирование) — в `utils/` + unit-тесты.

## БД (Supabase, Postgres)
Таблицы: suppliers (личный счёт, способы передачи, кабинет/e-mail), channels (self-ref source_channel_id), readings (unique channel+date), payments (unique supplier+period), receipts. RLS: user_id = auth.uid() (receipts — через payment_id).
