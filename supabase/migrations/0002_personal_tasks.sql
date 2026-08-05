-- Планер репетитора — таблица личных задач (раздел «Планы»).
-- Выполняется после 0001_init.sql в Supabase SQL Editor или через Supabase CLI.

-- Личные задачи планера (не привязаны к ученику).
create table if not exists public.personal_tasks (
    id           uuid primary key default gen_random_uuid(),
    owner_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
    title        text not null,
    scheduled_at timestamptz not null,
    note         text,
    is_done      boolean not null default false,
    color_hex    text not null default '#8A94B8',
    created_at   timestamptz not null default now()
);

create index if not exists personal_tasks_owner_scheduled_idx
    on public.personal_tasks (owner_id, scheduled_at);

-- Row Level Security: пользователь видит и меняет только свои задачи.
alter table public.personal_tasks enable row level security;

drop policy if exists "personal_tasks_owner_all" on public.personal_tasks;
create policy "personal_tasks_owner_all" on public.personal_tasks
    for all
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());
