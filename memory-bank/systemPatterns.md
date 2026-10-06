# System Patterns — Kommunalka

## Архитектура (слои `lib/`)
- `models/` — доменные модели (supplier, channel, reading, payment, receipt).
- `database/` — drift: `app_database.dart`, `tables/`, `daos/`; `.g.dart` — генерируются (build_runner).
- `repositories/` — репозитории над Supabase + drift; `repository_exceptions.dart` — доменные исключения.
- `providers/` — Riverpod-провайдеры.
- `services/` — auth, storage, settings, excel_report, yandex_disk, supabase_tables, timeout_http_client (общий http-клиент с таймаутами).
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

## Сеть
- Все сетевые вызовы (Supabase Storage, Яндекс.Диск) идут через `TimeoutHttpClient` — таймауты на подключение/ответ; иначе «вечное зависание» UI (закрыто в 5.9.1).
- `rootScaffoldMessengerKey` (main.dart) — глобальный messenger: SnackBar виден поверх открытых диалогов.
- Каскадное удаление (5.9.2): порядок с учётом `readings.channel_id ON DELETE RESTRICT` — readings → receipts (+Storage) → payments → channels → supplier.

## Excel-отчёт
- `ExcelReportService.generate` собирает xlsx (пакет `excel`); автофильтр пакет не умеет → пост-обработка zip (`archive`): вставка `<autoFilter>` после `</sheetData>`.
- Колонка «Расход»: `payment.consumption`; при null (старые платежи) — восстановление из `reading_snapshot`.
- Формат показаний — `formatReading` (целые без «.0»).

## Стиль кода
- Комментарии/докстринги — на русском, код — английский.
- Глаголы в именах методов, явные имена, без сокращений.
- Полная обработка ошибок.
- «Одна точка правды» для форматирования (`utils/`).
- Чистые функции (парсер/генератор QR, форматирование) — в `utils/` + unit-тесты.

## БД (Supabase, Postgres)
Таблицы: suppliers (личный счёт, способы передачи, кабинет/e-mail), channels (self-ref source_channel_id), readings (unique channel+date), payments (unique supplier+period), receipts. RLS: user_id = auth.uid() (receipts — через payment_id).
