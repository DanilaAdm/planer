-- Планер репетитора — начальная схема PostgreSQL (Supabase)
-- Выполняется в Supabase SQL Editor или через Supabase CLI.

-- Расширение для генерации UUID (в Supabase обычно уже включено).
create extension if not exists "pgcrypto";

-- Формат работы с учеником.
do $$
begin
    if not exists (select 1 from pg_type where typname = 'work_format') then
        create type work_format as enum ('postpay', 'subscription');
    end if;
end$$;

-- Ученики.
create table if not exists public.students (
    id                 uuid primary key default gen_random_uuid(),
    owner_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
    name               text not null,
    color_hex          text not null default '#4E9CFF',
    price_per_lesson   numeric(12, 2) not null default 0,
    work_format        work_format not null default 'postpay',
    google_doc_url     text,
    paid_lessons_total integer not null default 0 check (paid_lessons_total >= 0),
    lessons_used       integer not null default 0 check (lessons_used >= 0),
    created_at         timestamptz not null default now()
);

-- Уроки.
create table if not exists public.lessons (
    id           uuid primary key default gen_random_uuid(),
    owner_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
    student_id   uuid not null references public.students (id) on delete cascade,
    start_at     timestamptz not null,
    duration_min integer not null default 60 check (duration_min > 0),
    is_paid      boolean not null default false,
    note         text,
    created_at   timestamptz not null default now()
);

create index if not exists lessons_owner_start_idx on public.lessons (owner_id, start_at);
create index if not exists lessons_student_idx on public.lessons (student_id);
create index if not exists students_owner_idx on public.students (owner_id);

-- Row Level Security: пользователь видит и меняет только свои данные.
alter table public.students enable row level security;
alter table public.lessons  enable row level security;

drop policy if exists "students_owner_all" on public.students;
create policy "students_owner_all" on public.students
    for all
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

drop policy if exists "lessons_owner_all" on public.lessons;
create policy "lessons_owner_all" on public.lessons
    for all
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());
