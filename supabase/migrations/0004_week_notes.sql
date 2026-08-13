-- Планер репетитора — таблица заметок недели (блок «Заметки» на развороте дневника).
-- Выполняется после 0001_init.sql, 0002_personal_tasks.sql и 0003_hardening.sql.
--
-- Миграция идемпотентна: её можно выполнять повторно.

-- Заметки недели: не привязаны ни к ученику, ни к конкретному времени.
-- `week_start` — понедельник недели, тип `date`, а не `timestamptz`: неделя это
-- календарная метка, и полночь понедельника в другом часовом поясе не должна
-- переносить заметку в соседнюю неделю.
create table if not exists public.week_notes (
    id         uuid primary key default gen_random_uuid(),
    owner_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
    week_start date not null,
    text       text not null,
    created_at timestamptz not null default now()
);

create index if not exists week_notes_owner_week_idx
    on public.week_notes (owner_id, week_start);

-- Row Level Security: пользователь видит и меняет только свои заметки.
alter table public.week_notes enable row level security;

drop policy if exists "week_notes_owner_all" on public.week_notes;
create policy "week_notes_owner_all" on public.week_notes
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

-- Анонимная роль не должна иметь доступа к данным вообще: приложение обращается
-- к таблице только после входа, то есть под ролью `authenticated`.
revoke all on public.week_notes from anon;
grant select, insert, update, delete on public.week_notes to authenticated;

-- Владельца проставляет сервер, а не клиент: триггер перезаписывает присланное
-- значение идентификатором из JWT (функция создана в 0003_hardening.sql).
drop trigger if exists week_notes_set_owner on public.week_notes;
create trigger week_notes_set_owner
    before insert or update on public.week_notes
    for each row execute function public.set_owner_id();

-- Проверка результата: должна вернуться одна строка с rls_enabled = true и policies = 1.
select
    c.relname                                            as table_name,
    c.relrowsecurity                                     as rls_enabled,
    (select count(*) from pg_policies p
      where p.schemaname = 'public' and p.tablename = c.relname) as policies
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'week_notes';
