-- Миграция схемы для существующей БД Supabase.
-- Добавляет в таблицу suppliers флаг «оплата по показаниям прошлого периода»:
-- для таких поставщиков (напр. ОАО «Водопровод», АО «Очистные сооружения
-- канализации») сумма платежа и QR строятся по расходу предыдущего месяца.
--
-- Выполнить в Supabase SQL Editor (раздел SQL → New query) один раз.

alter table suppliers
  add column pays_previous_period boolean not null default false;
