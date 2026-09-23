-- Схема БД проекта "Коммуналка" (Этап 2.2 плана выполнения)
-- Соответствует модели данных из ТЗ §7.
-- RLS-политики добавляются отдельным скриптом на Этапе 2.3 —
-- здесь только структура таблиц, индексы и триггер автообновления updated_at.

-- Общий триггер для updated_at
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- ===== suppliers =====

create table suppliers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  category text,
  type text not null check (type in ('with_readings', 'without_readings')),
  bank_details jsonb,
  payment_purpose_template text,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_suppliers_user_id on suppliers (user_id);
-- частый запрос — список активных (неархивных) поставщиков пользователя
create index idx_suppliers_user_active on suppliers (user_id) where archived_at is null;

create trigger trg_suppliers_updated_at
  before update on suppliers
  for each row execute function set_updated_at();

-- ===== channels =====

create table channels (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  supplier_id uuid not null references suppliers(id) on delete cascade,
  name text not null,
  unit text not null,
  tariff numeric(10, 2) not null,
  -- производный канал: расход берётся из другого канала (см. ТЗ §4.1) —
  -- self-reference, поэтому FK можно объявить сразу (таблица уже существует)
  source_channel_id uuid references channels(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_channels_supplier_id on channels (supplier_id);
create index idx_channels_source_channel_id on channels (source_channel_id);

create trigger trg_channels_updated_at
  before update on channels
  for each row execute function set_updated_at();

-- ===== readings =====

create table readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  channel_id uuid not null references channels(id) on delete cascade,
  value numeric(12, 3) not null,
  reading_date date not null,
  meter_replaced boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- защита от случайного дублирования показания на одну и ту же дату
  unique (channel_id, reading_date)
);

-- "последнее показание по каналу" — order by reading_date desc limit 1
create index idx_readings_channel_date on readings (channel_id, reading_date desc);

create trigger trg_readings_updated_at
  before update on readings
  for each row execute function set_updated_at();

-- ===== payments =====

create table payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  supplier_id uuid not null references suppliers(id) on delete cascade,
  period date not null,
  reading_snapshot jsonb,
  consumption numeric(12, 3),
  calculated_amount numeric(10, 2) not null,
  actual_amount numeric(10, 2),
  bank text,
  status text not null default 'pending' check (status in ('pending', 'partially_paid', 'paid')),
  payment_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- один платёж на поставщика за период (нужно для сценария "Закрытие месяца", ТЗ §8)
  unique (supplier_id, period)
);

-- "платежи по поставщику"
create index idx_payments_supplier_period on payments (supplier_id, period desc);
-- "платежи по периоду" (общая история по всем поставщикам пользователя)
create index idx_payments_user_period on payments (user_id, period desc);

create trigger trg_payments_updated_at
  before update on payments
  for each row execute function set_updated_at();

-- ===== receipts =====

create table receipts (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references payments(id) on delete cascade,
  file_path text not null,
  created_at timestamptz not null default now()
);

create index idx_receipts_payment_id on receipts (payment_id);
