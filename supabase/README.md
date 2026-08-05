# Настройка Supabase (PostgreSQL)

Приложение хранит данные в PostgreSQL через [Supabase](https://supabase.com) — это управляемый
PostgreSQL с автоматическим REST API (PostgREST) и авторизацией. Приложение не подключается к базе
напрямую (это небезопасно), а работает через официальный SDK `supabase-swift`.

## Шаги

1. Создайте бесплатный проект на https://supabase.com.
2. Откройте **SQL Editor** и выполните содержимое [`migrations/0001_init.sql`](migrations/0001_init.sql),
   затем [`migrations/0002_personal_tasks.sql`](migrations/0002_personal_tasks.sql).
   Это создаст таблицы `students`, `lessons`, `personal_tasks`, тип `work_format` и политики RLS.
3. В **Project Settings → API** скопируйте:
   - `Project URL` (например, `https://xxxx.supabase.co`);
   - `anon public` ключ.
4. В **Authentication → Providers** оставьте включённым Email (для входа по e-mail).
   При желании отключите подтверждение почты (Authentication → Providers → Email → Confirm email).
5. Запустите приложение и на экране настроек введите `Project URL` и `anon` ключ,
   затем зарегистрируйтесь/войдите по e-mail.

## Структура данных

- `students` — ученики: имя, цвет, цена урока, формат работы (postpay/subscription),
  ссылка на Google-документ, счётчики оплаченных/использованных уроков.
- `lessons` — уроки: ссылка на ученика, время начала, длительность, отметка «оплачено», заметка.
- `personal_tasks` — личные задачи из раздела «Планы»: название, дата/время, заметка,
  отметка «выполнено», цвет.

RLS-политики гарантируют, что каждый пользователь видит только свои записи (`owner_id = auth.uid()`).
