# Планер репетитора (iOS + macOS)

Приложение-планер для репетитора: календарь занятий (Месяц → Неделя → День), управление
учениками, учёт оплат и расчёт заработка. Написано на SwiftUI, работает на iOS 17+ и macOS 14+.
Данные хранятся в PostgreSQL через [Supabase](https://supabase.com) с локальным офлайн-кэшем.

## Возможности

- Календарь: **Месяц → Неделя (как школьный дневник) → День**.
- Ученики: добавление/удаление, свой **цвет**, стоимость урока, формат работы
  (**Постоплата / Абонемент**), ссылка на **Google-документ** (пройденный материал и
  предстоящие темы) — открывается во встроенном **режиме чтения** (см. ниже).
- Счётчик **оплаченных уроков** «X/Y» с кнопкой **«−»** для списания урока (в карточке ученика
  и на блоке урока в календаре).
- Уроки: добавление, удаление, **перетаскивание по времени** и **изменение длительности** прямо
  в дне; отметка **«Занятие оплачено»** на каждом занятии (цветовая индикатор + чекбокс).
- Заработок за месяц: по каждому ученику и итог.
- Синхронизация через Supabase (PostgreSQL) + офлайн-кэш (SwiftData).

## Структура репозитория

```
Packages/PlannerCore/   Swift Package: модели и бизнес-логика (без UI), покрыт unit-тестами
App/Sources/            Приложение SwiftUI (iOS + macOS): экраны, Supabase, SwiftData-кэш
App/Tests/              Unit-тесты уровня приложения
App/UITests/            UI-тесты (XCUITest)
supabase/               SQL-схема PostgreSQL и инструкция по настройке
scripts/                Скрипты сборки (.ipa, .dmg) и генерации проекта
project.yml             Описание Xcode-проекта для XcodeGen
.github/workflows/      CI (тесты) и Release (сборка .ipa/.dmg → GitHub Releases)
```

Бизнес-логика вынесена в `PlannerCore` и полностью покрыта тестами (расчёт заработка, списание
оплаченных уроков, пересечения и длительность уроков, работа с цветом, маппинг DTO, синхронизация).

## Требования для сборки

- macOS с установленным **Xcode 15+** (не только Command Line Tools).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.

## Как собрать и запустить локально

```bash
# 1. Сгенерировать Xcode-проект из project.yml
./scripts/generate_project.sh        # или: xcodegen generate

# 2. Открыть проект
open PlannerApp.xcodeproj

# 3. Выбрать схему PlannerApp и запустить на симуляторе iOS или на Mac
```

Проект `PlannerApp.xcodeproj` не хранится в git — он генерируется из `project.yml`.

## Настройка Supabase (PostgreSQL)

См. подробную инструкцию в [`supabase/README.md`](supabase/README.md). Кратко:

1. Создать проект на https://supabase.com.
2. Выполнить [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql) в SQL Editor.
3. Скопировать `Project URL` и `anon`-ключ (Project Settings → API).
4. В приложении на экране входа/настроек ввести URL и ключ, затем зарегистрироваться/войти.

## Тесты

```bash
# Unit-тесты бизнес-логики (без Xcode-проекта)
swift test --package-path Packages/PlannerCore

# Все тесты приложения (нужен сгенерированный проект)
xcodegen generate
xcodebuild test -project PlannerApp.xcodeproj -scheme PlannerApp -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
xcodebuild test -project PlannerApp.xcodeproj -scheme PlannerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO

# Дополнительно проверить, что документ Ксюши открыт «по ссылке» (нужен интернет)
TEST_RUNNER_RUN_NETWORK_TESTS=1 xcodebuild test -project PlannerApp.xcodeproj -scheme PlannerApp \
  -destination 'platform=macOS' -only-testing:PlannerAppTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
```

UI-тесты запускают приложение с аргументом `-uitest`: используется хранилище в памяти
(без сети и Supabase) с предзаполненными данными.

## Установка через GitHub (для пользователей)

Готовые файлы публикуются на вкладке **Releases** при создании тега `vX.Y.Z`
(например, `git tag v1.0.0 && git push origin v1.0.0`). CI соберёт и приложит:

### iOS — `PlannerApp-unsigned.ipa`

Неподписанный `.ipa`. Установите одним из способов с вашим Apple ID:

- **AltStore**: https://altstore.io — установите AltServer на компьютер, затем добавьте `.ipa`.
- **Sideloadly**: https://sideloadly.io — подключите iPhone и перетащите `.ipa`.

При бесплатном Apple ID подпись действует **7 дней**, после чего приложение нужно переустановить/
переподписать. С платным Apple Developer аккаунтом — 1 год.

### macOS — `PlannerApp-macOS.dmg`

1. Откройте `.dmg` и перетащите «Планер» в «Программы».
2. Первый запуск: правый клик по приложению → **«Открыть»** (обход Gatekeeper), либо в терминале:

```bash
xattr -dr com.apple.quarantine "/Applications/Планер.app"
```

## Как это работает (архитектура)

- `PlannerCore` — чистые модели и логика, без зависимостей от UI/сети (легко тестируется).
- `PlannerRepository` — координатор «online-first + офлайн-кэш»: читает из Supabase, при
  отсутствии сети отдаёт данные из локального кэша (SwiftData); запись идёт в кэш и на сервер.
- `SupabaseRemoteStore` — доступ к PostgreSQL через официальный SDK `supabase-swift`.
- Приложение никогда не подключается к PostgreSQL напрямую — только через Supabase API (безопасно).

## Google-документ ученика

Ссылка из карточки ученика открывается внутри приложения в режиме чтения:

- Ссылка любого вида (`/edit`, `/view`, `?tab=…`) приводится к облегчённой версии Google
  (`/mobilebasic` для документов, `/htmlview` для таблиц, `/preview` для презентаций) —
  разбор ссылки живёт в `GoogleDocLink` и покрыт unit-тестами.
- В страницу подставляется свой CSS: комфортный кегль, перенос длинных строк, скрытые
  баннеры и панели Google, поддержка тёмной темы.
- Панель просмотра одинакова на iOS и macOS: «Закрыть», уменьшить/увеличить текст
  (масштаб запоминается), «Обновить», «Полная версия», «Открыть в браузере».
- Понятные состояния: индикатор загрузки, «нет связи», «нужен доступ» (403/404) с кнопками
  «Повторить» и «Открыть в браузере».

Документ должен быть доступен **по ссылке** («Просмотр» для всех): войти в Google-аккаунт
внутри WebView нельзя — сам Google это запрещает, поэтому приватные файлы открываются
только кнопкой «Открыть в браузере».

Демо-данные и UI-тесты содержат ученицу **Ксюша** с реальным документом; UI-тест
`testKsyushaDocumentOpens` открывает его и проверяет содержимое, а без доступа к сети
(например, на машине с включённым VPN) тест помечается как skipped.

## Замечания по решениям

- Для «настоящего PostgreSQL» выбран Supabase (управляемый Postgres + авто-API), чтобы не
  писать и не хостить отдельный backend. При желании `RemoteStore` можно заменить на свой сервер.
