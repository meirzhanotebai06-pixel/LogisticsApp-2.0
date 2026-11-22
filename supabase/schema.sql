-- ============================================================================
-- LogisticsApp 2.0 — PostgreSQL / Supabase Schema (3NF + RLS + RPC + Storage)
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. TABLES (Normalized 3NF)
-- ----------------------------------------------------------------------------

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text not null unique,
    name text not null,
    user_type text not null check (user_type in ('client', 'driver', 'admin')),
    phone text,
    is_on_duty boolean not null default false,
    rating double precision,
    created_at timestamptz not null default now()
);

create table if not exists public.vehicles (
    id uuid primary key default gen_random_uuid(),
    driver_id uuid not null unique references public.profiles(id) on delete cascade,
    model text not null,
    plate_number text not null,
    capacity text not null,
    updated_at timestamptz not null default now()
);

create table if not exists public.driver_documents (
    id uuid primary key default gen_random_uuid(),
    driver_id uuid not null references public.profiles(id) on delete cascade,
    document_type text not null check (
        document_type in ('insurance', 'driverLicense', 'vehicleRegistration', 'technicalInspection')
    ),
    number text not null,
    expiry_date timestamptz,
    is_verified boolean not null default false,
    verification_status text not null default 'pending' check (
        verification_status in ('pending', 'approved', 'rejected')
    ),
    rejection_reason text,
    file_url text,
    upload_date timestamptz default now(),
    issue_date timestamptz,
    issued_by text,
    full_name text,
    iin text,
    category text,
    insurance_type text,
    insurance_company text,
    vin text,
    vehicle_year text,
    color text,
    engine_number text,
    capacity text,
    inspection_center text,
    verified_at timestamptz,
    unique (driver_id, document_type)
);

create table if not exists public.orders (
    id uuid primary key default gen_random_uuid(),
    track_number text not null unique,
    client_id uuid not null references public.profiles(id) on delete cascade,
    client_name text not null,
    client_phone text,
    driver_id uuid references public.profiles(id) on delete set null,
    driver_name text,
    driver_phone text,
    from_address text not null,
    to_address text not null,
    route text not null,
    package_description text not null,
    weight double precision not null check (weight > 0),
    package_type text not null,
    tariff_type text not null,
    status text not null default 'accepted' check (
        status in ('accepted', 'inTransit', 'atCustoms', 'delivered', 'cancelled')
    ),
    has_insurance boolean not null default false,
    is_urgent boolean not null default false,
    price integer not null check (price >= 0),
    currency text not null default '₸',
    driver_earning integer not null default 0 check (driver_earning >= 0),
    driver_latitude double precision,
    driver_longitude double precision,
    created_at timestamptz not null default now(),
    estimated_delivery timestamptz not null,
    accepted_at timestamptz,
    delivered_at timestamptz,
    cancelled_at timestamptz,
    updated_at timestamptz not null default now()
);

create table if not exists public.order_status_events (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id) on delete cascade,
    status text not null check (
        status in ('accepted', 'inTransit', 'atCustoms', 'delivered', 'cancelled')
    ),
    note text,
    created_at timestamptz not null default now()
);

create table if not exists public.reviews (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null unique references public.orders(id) on delete cascade,
    driver_id uuid not null references public.profiles(id) on delete cascade,
    client_id uuid not null references public.profiles(id) on delete cascade,
    client_name text not null,
    rating integer not null check (rating between 1 and 5),
    comment text not null default '',
    created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 2. INDEXES
-- ----------------------------------------------------------------------------

create index if not exists idx_orders_client_created on public.orders (client_id, created_at desc);
create index if not exists idx_orders_driver_created on public.orders (driver_id, created_at desc);
create index if not exists idx_orders_status_driver_created on public.orders (status, driver_id, created_at desc);
create index if not exists idx_orders_track_number on public.orders (track_number);
create index if not exists idx_events_order_created on public.order_status_events (order_id, created_at asc);
create index if not exists idx_documents_driver on public.driver_documents (driver_id);
create index if not exists idx_reviews_driver_created on public.reviews (driver_id, created_at desc);

-- ----------------------------------------------------------------------------
-- 3. SECURITY HELPERS
-- ----------------------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.profiles
        where id = auth.uid() and user_type = 'admin'
    );
$$;

create or replace function public.is_driver()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.profiles
        where id = auth.uid() and user_type = 'driver'
    );
$$;

create or replace function public.is_verified_driver(p_driver_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select (
        select count(distinct document_type)
        from public.driver_documents
        where driver_id = p_driver_id
          and is_verified = true
          and (expiry_date is null or expiry_date > now())
    ) = 4;
$$;

-- Trigger preventing non-admins from self-verifying documents or changing user_type
create or replace function public.guard_driver_document_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if not public.is_admin() then
        new.is_verified := false;
        new.verification_status := 'pending';
        new.rejection_reason := null;
        new.verified_at := null;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_guard_driver_document_verification on public.driver_documents;
create trigger trg_guard_driver_document_verification
before insert or update on public.driver_documents
for each row execute function public.guard_driver_document_verification();

-- ----------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS)
-- ----------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.driver_documents enable row level security;
alter table public.orders enable row level security;
alter table public.order_status_events enable row level security;
alter table public.reviews enable row level security;

-- PROFILES
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin" on public.profiles
for select using (auth.uid() = id or public.is_admin());

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self" on public.profiles
for insert with check (
    auth.uid() = id and user_type in ('client', 'driver')
);

drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin" on public.profiles
for update using (auth.uid() = id or public.is_admin())
with check (
    (auth.uid() = id and user_type = (select user_type from public.profiles where id = auth.uid()))
    or public.is_admin()
);

-- VEHICLES
drop policy if exists "vehicles_select_own_or_admin" on public.vehicles;
create policy "vehicles_select_own_or_admin" on public.vehicles
for select using (auth.uid() = driver_id or public.is_admin());

drop policy if exists "vehicles_upsert_own" on public.vehicles;
create policy "vehicles_upsert_own" on public.vehicles
for all using (auth.uid() = driver_id or public.is_admin())
with check (auth.uid() = driver_id or public.is_admin());

-- DRIVER DOCUMENTS
drop policy if exists "documents_select_own_or_admin" on public.driver_documents;
create policy "documents_select_own_or_admin" on public.driver_documents
for select using (auth.uid() = driver_id or public.is_admin());

drop policy if exists "documents_insert_own" on public.driver_documents;
create policy "documents_insert_own" on public.driver_documents
for insert with check (auth.uid() = driver_id);

drop policy if exists "documents_update_own_or_admin" on public.driver_documents;
create policy "documents_update_own_or_admin" on public.driver_documents
for update using (auth.uid() = driver_id or public.is_admin())
with check (auth.uid() = driver_id or public.is_admin());

-- ORDERS
drop policy if exists "orders_select" on public.orders;
create policy "orders_select" on public.orders
for select using (
    auth.uid() = client_id
    or auth.uid() = driver_id
    or public.is_admin()
    or (public.is_driver() and driver_id is null and status = 'accepted')
);

drop policy if exists "orders_insert_client" on public.orders;
create policy "orders_insert_client" on public.orders
for insert with check (
    auth.uid() = client_id
    and driver_id is null
    and status = 'accepted'
);

drop policy if exists "orders_update" on public.orders;
create policy "orders_update" on public.orders
for update using (
    auth.uid() = driver_id
    or (auth.uid() = client_id and driver_id is null and status = 'accepted')
    or public.is_admin()
)
with check (
    auth.uid() = driver_id
    or (auth.uid() = client_id and driver_id is null and status = 'cancelled')
    or public.is_admin()
);

drop policy if exists "orders_delete_client" on public.orders;
create policy "orders_delete_client" on public.orders
for delete using (auth.uid() = client_id and driver_id is null);

-- ORDER STATUS EVENTS
drop policy if exists "events_select" on public.order_status_events;
create policy "events_select" on public.order_status_events
for select using (
    exists (
        select 1 from public.orders o
        where o.id = order_id
          and (
              o.client_id = auth.uid()
              or o.driver_id = auth.uid()
              or public.is_admin()
              or (public.is_driver() and o.driver_id is null and o.status = 'accepted')
          )
    )
);

drop policy if exists "events_insert" on public.order_status_events;
create policy "events_insert" on public.order_status_events
for insert with check (
    exists (
        select 1 from public.orders o
        where o.id = order_id
          and (o.client_id = auth.uid() or o.driver_id = auth.uid() or public.is_admin())
    )
);

-- REVIEWS
drop policy if exists "reviews_select" on public.reviews;
create policy "reviews_select" on public.reviews
for select using (auth.role() = 'authenticated');

drop policy if exists "reviews_insert_client" on public.reviews;
create policy "reviews_insert_client" on public.reviews
for insert with check (auth.uid() = client_id);

-- ----------------------------------------------------------------------------
-- 5. ATOMIC RPC FUNCTIONS
-- ----------------------------------------------------------------------------

-- Atomic order acceptance by a verified driver (prevents race condition)
create or replace function public.accept_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
    v_driver_name text;
    v_driver_phone text;
    v_order public.orders%rowtype;
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;

    select name, phone into v_driver_name, v_driver_phone
    from public.profiles
    where id = v_uid and user_type = 'driver';

    if v_driver_name is null then
        raise exception 'Тек жүргізушілер тапсырыс қабылдай алады';
    end if;

    if not public.is_verified_driver(v_uid) then
        raise exception 'Барлық көлік құжаттары расталуы қажет';
    end if;

    select * into v_order
    from public.orders
    where id = p_order_id
    for update;

    if not found then
        raise exception 'Тапсырыс табылмады';
    end if;

    if v_order.driver_id is not null or v_order.status <> 'accepted' then
        raise exception 'Бұл тапсырысты басқа жүргізуші қабылдап қойған';
    end if;

    update public.orders
    set driver_id = v_uid,
        driver_name = v_driver_name,
        driver_phone = v_driver_phone,
        status = 'inTransit',
        accepted_at = now(),
        updated_at = now()
    where id = p_order_id;

    insert into public.order_status_events (order_id, status, note)
    values (p_order_id, 'inTransit', 'Жүргізуші тағайындалды: ' || v_driver_name);
end;
$$;

-- Clean account deletion for authenticated user (App Store Guideline 5.1.1(v))
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'Not authenticated';
    end if;
    delete from auth.users where id = v_uid;
end;
$$;

-- ----------------------------------------------------------------------------
-- 6. REALTIME & STORAGE BUCKET
-- ----------------------------------------------------------------------------

alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.order_status_events;
alter publication supabase_realtime add table public.driver_documents;

insert into storage.buckets (id, name, public)
values ('driver-documents', 'driver-documents', true)
on conflict (id) do nothing;

drop policy if exists "driver_docs_read" on storage.objects;
create policy "driver_docs_read" on storage.objects
for select using (
    bucket_id = 'driver-documents'
    and (auth.role() = 'authenticated')
);

drop policy if exists "driver_docs_upload_own" on storage.objects;
create policy "driver_docs_upload_own" on storage.objects
for insert with check (
    bucket_id = 'driver-documents'
    and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "driver_docs_update_own" on storage.objects;
create policy "driver_docs_update_own" on storage.objects
for update using (
    bucket_id = 'driver-documents'
    and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "driver_docs_delete_own" on storage.objects;
create policy "driver_docs_delete_own" on storage.objects
for delete using (
    bucket_id = 'driver-documents'
    and (auth.uid()::text = (storage.foldername(name))[1] or public.is_admin())
);
