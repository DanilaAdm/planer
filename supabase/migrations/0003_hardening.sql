-- Планер репетитора — усиление изоляции данных между пользователями.
-- Выполняется после 0001_init.sql и 0002_personal_tasks.sql.
--
-- Миграция идемпотентна: её можно выполнять повторно. Она не проверяет
-- состояние базы, а приводит его к нужному, поэтому закрывает и случай, когда
-- предыдущие миграции накатились частично.

-- 1. Row Level Security включён на всех таблицах с пользовательскими данными.
alter table public.students       enable row level security;
alter table public.lessons        enable row level security;
alter table public.personal_tasks enable row level security;

-- 2. Политики «владелец видит только своё». Пересоздаём, чтобы гарантировать
--    их наличие и содержимое независимо от предыдущего состояния базы.
--    Ограничение `to authenticated` явно сообщает, что политика работает только
--    для вошедших пользователей.
drop policy if exists "students_owner_all" on public.students;
create policy "students_owner_all" on public.students
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

drop policy if exists "lessons_owner_all" on public.lessons;
create policy "lessons_owner_all" on public.lessons
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

drop policy if exists "personal_tasks_owner_all" on public.personal_tasks;
create policy "personal_tasks_owner_all" on public.personal_tasks
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

-- 3. Роль `anon` (запрос без входа) не должна иметь доступа к данным вообще.
--    Приложение обращается к таблицам только после входа, то есть под ролью
--    `authenticated`, поэтому отзыв прав ничего не ломает, но убирает целый
--    класс ошибок: даже если политику однажды случайно удалят, анонимный
--    запрос упрётся в отсутствие прав, а не выдаст чужие данные.
revoke all on public.students       from anon;
revoke all on public.lessons        from anon;
revoke all on public.personal_tasks from anon;

grant select, insert, update, delete on public.students       to authenticated;
grant select, insert, update, delete on public.lessons        to authenticated;
grant select, insert, update, delete on public.personal_tasks to authenticated;

-- 4. Владельца проставляет сервер, а не клиент.
--
--    Клиент присылает свой owner_id, но полагаться на присланное значение
--    нельзя: триггер перезаписывает поле идентификатором из JWT, поэтому
--    подделать владельца невозможно даже изменённым клиентом.
--
--    Когда `auth.uid()` пуст (операции из SQL Editor или из скрипта с
--    сервисным ключом), поле не трогаем — иначе такие операции падали бы на
--    ограничении NOT NULL. Для запросов через API `auth.uid()` всегда заполнен.
create or replace function public.set_owner_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is not null then
        new.owner_id := auth.uid();
    end if;
    return new;
end;
$$;

drop trigger if exists students_set_owner       on public.students;
drop trigger if exists lessons_set_owner        on public.lessons;
drop trigger if exists personal_tasks_set_owner on public.personal_tasks;

create trigger students_set_owner
    before insert or update on public.students
    for each row execute function public.set_owner_id();

create trigger lessons_set_owner
    before insert or update on public.lessons
    for each row execute function public.set_owner_id();

create trigger personal_tasks_set_owner
    before insert or update on public.personal_tasks
    for each row execute function public.set_owner_id();

-- 5. Проверка результата: должно вернуться три строки, у всех
--    rls_enabled = true и policies = 1.
select
    c.relname                                            as table_name,
    c.relrowsecurity                                     as rls_enabled,
    (select count(*) from pg_policies p
      where p.schemaname = 'public' and p.tablename = c.relname) as policies
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('students', 'lessons', 'personal_tasks')
order by c.relname;
