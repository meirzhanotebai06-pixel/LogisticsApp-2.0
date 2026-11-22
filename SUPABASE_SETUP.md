# Настройка Supabase (PostgreSQL) для LogisticsApp 2.0

Проект полностью переведён с Firebase на **Supabase (PostgreSQL)** с реляционной базой данных в 3НФ, политиками безопасности Row Level Security (RLS), атомарными транзакциями (`accept_order`), Realtime-подписками и Storage для сканов документов.

---

## Шаг 1. Создайте бесплатный проект в Supabase

1. Перейдите на [supabase.com](https://supabase.com) и войдите через GitHub (карта не требуется).
2. Нажмите **New project**, задайте имя `LogisticsApp` и пароль базы данных.
3. Дождитесь создания проекта (1–2 минуты).

---

## Шаг 2. Создайте таблицы, RLS и функции в PostgreSQL

1. В левом меню выберите **SQL Editor → New query**.
2. Скопируйте всё содержимое файла [schema.sql](file:///workspaces/LogisticsApp-2.0/supabase/schema.sql) и вставьте в редактор.
3. Нажмите **Run** (`Ctrl+Enter` / `Cmd+Enter`).
4. Убедитесь, что скрипт выполнился без ошибок (`Success`).

> **Для дипломной работы:** перейдите в **Database → Schema Visualizer** — там автоматически появится готовая **ER-диаграмма** со всеми таблицами (`profiles`, `vehicles`, `driver_documents`, `orders`, `order_status_events`, `reviews`) и связями `1:1` / `1:N`. Её можно экспортировать и вставить в пояснительную записку.

---

## Шаг 3. Настройте Auth (для удобного тестирования на дипломе)

1. Перейдите в **Authentication → Providers → Email**.
2. Для быстрого тестирования в демо можно отключить **Confirm email** (чтобы клиенты и водители входили сразу после регистрации без подтверждения почты).

---

## Шаг 4. Подключите ключи в iOS-приложение

1. Откройте **Project Settings → API** в панели Supabase.
2. Скопируйте:
   - **Project URL** (`https://xxxxxxxxxxxx.supabase.co`)
   - **anon / public key** (`eyJ...`)
3. Откройте [SupabaseConfig.swift](file:///workspaces/LogisticsApp-2.0/LogisticsApp/Services/SupabaseConfig.swift) и вставьте ваши значения в `defaultURL` и `defaultAnonKey`.

---

## Шаг 5. Создание аккаунта Администратора

Из соображений безопасности регистрация в приложении позволяет выбрать только роль `client` или `driver`. Чтобы создать администратора:

1. Зарегистрируйте обычный аккаунт через приложение (или через **Authentication → Users → Add user**).
2. В **SQL Editor** выполните:
   ```sql
   update public.profiles
   set user_type = 'admin'
   where email = 'admin@example.com';
   ```

---

## Шаг 6. Сборка и запуск в Xcode

1. Откройте [LogisticsApp.xcodeproj](file:///workspaces/LogisticsApp-2.0/LogisticsApp.xcodeproj) в Xcode.
2. Xcode автоматически скачает пакет `supabase-swift` через Swift Package Manager (**File → Packages → Resolve Package Versions** при необходимости).
3. Нажмите **Run (`⌘R`)**.
