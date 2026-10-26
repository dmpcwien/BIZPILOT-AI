-- Initial multi-tenant schema for BIZPILOT AI.
-- Execute only after reviewing the migration in your Supabase project.
create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  country_code text not null default 'AT' check (country_code in ('AT','DE')),
  created_at timestamptz not null default now()
);
create unique index if not exists businesses_id_owner_idx on public.businesses(id, owner_id);
create index if not exists businesses_owner_idx on public.businesses(owner_id);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  email text,
  created_at timestamptz not null default now()
);
create index if not exists customers_business_idx on public.customers(business_id);

create table if not exists public.drafts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete restrict,
  kind text not null check (kind in ('offer','invoice')),
  description text not null,
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null default 'EUR',
  created_at timestamptz not null default now(),
  unique (id, business_id)
);
create index if not exists drafts_business_idx on public.drafts(business_id);
create unique index if not exists customers_id_business_idx on public.customers(id,business_id);
alter table public.drafts drop constraint if exists drafts_customer_same_business;
alter table public.drafts add constraint drafts_customer_same_business
  foreign key (customer_id, business_id) references public.customers(id,business_id);

alter table public.businesses enable row level security;
alter table public.customers enable row level security;
alter table public.drafts enable row level security;

create policy "business_owner_all" on public.businesses
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "customers_owner_all" on public.customers
  for all to authenticated
  using (exists (select 1 from public.businesses b
    where b.id = business_id and b.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.businesses b
    where b.id = business_id and b.owner_id = (select auth.uid())));

create policy "drafts_owner_all" on public.drafts
  for all to authenticated
  using (exists (select 1 from public.businesses b
    where b.id = business_id and b.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.businesses b
    where b.id = business_id and b.owner_id = (select auth.uid())));
