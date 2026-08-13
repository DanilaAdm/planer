-- Планер репетитора — еженедельное повторение занятий (отметка «Каждую неделю»
-- в блоке «Новая запись»).
-- Выполняется после 0001_init.sql … 0004_week_notes.sql.
--
-- Миграция идемпотентна: её можно выполнять повторно.

-- Повторы — обычные строки в `lessons` с общим `series_id`, а не правило
-- повторения: тогда каждое занятие серии можно оплатить, перенести или отменить
-- по отдельности, а заработок и абонементы считаются без исключений.
-- `null` — разовое занятие.
alter table public.lessons
    add column if not exists series_id uuid;

-- Индекс под снятие отметки: убрать повторы серии, начиная с указанного времени.
create index if not exists lessons_owner_series_idx
    on public.lessons (owner_id, series_id, start_at);

-- Проверка результата: должна вернуться одна строка со столбцом series_id.
select
    c.column_name,
    c.data_type,
    c.is_nullable
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'lessons'
  and c.column_name = 'series_id';
