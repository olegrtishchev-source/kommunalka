-- Бакет для чеков об оплате (ТЗ §4.5, Этап 3.8 плана).
-- Приватный — публичного доступа нет, доступ только владельцу через
-- RLS-политику на storage.objects ниже.
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- Storage RLS не умеет напрямую проверить владельца через
-- payment_id -> payments.user_id (это была бы политика с subquery,
-- отдельная головная боль для каждой операции). Вместо этого путь
-- файла начинается с user_id (см. ReceiptRepository.attach:
-- '<user_id>/<payment_id>/<таймстемп>.jpg') — первый сегмент пути
-- сравнивается с auth.uid(). Это стандартный для Supabase Storage приём.
create policy "receipts_owner"
  on storage.objects
  for all
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
