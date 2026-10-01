-- Миграция схемы для существующей БД Supabase (Этап 5, п. 5.8).
-- Добавляет в таблицу suppliers новые поля из ТЗ v2.1 (§4.11, §4.12, §7):
--   personal_account — лицевой счёт плательщика у поставщика;
--   reading_methods  — способы передачи показаний (bank_form / cabinet / email);
--   cabinet_url      — ссылка на личный кабинет/страницу для передачи;
--   reading_email    — адрес для письма с показаниями.
-- bank_details (jsonb) не трогается: bank_name / corr_account — это ключи
-- внутри jsonb, их добавляет приложение при записи, ALTER не нужен.
--
-- Выполнить в Supabase SQL Editor (раздел SQL → New query) от имени Олега.
-- Выполняется один раз; повторный запуск на уже мигрированной БД даст
-- ошибки «column ... already exists» — это нормально, миграция идемпотентна
-- только визуально, повторно запускать не нужно.

alter table suppliers
  add column personal_account text,
  add column reading_methods text[] not null default '{}',
  add column cabinet_url text,
  add column reading_email text;
