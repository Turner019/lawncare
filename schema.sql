-- ═══════════════════════════════════════════════════════════════
-- LawnCare PWA — Supabase Schema
-- Paste this entire file into Supabase → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ── LAWNS ──────────────────────────────────────────────────────
create table if not exists lawns (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null,
  address         text not null,
  lat             double precision not null,
  lon             double precision not null,
  sqft            integer not null default 6500,
  zone_offset     integer not null default 0,      -- week shift from NJ baseline
  zone_name       text not null default 'Mid-Atlantic/Midwest (Zone 6-7)',
  is_warm_season  boolean not null default false,
  created_at      timestamptz not null default now()
);

-- ── TASK LOGS ──────────────────────────────────────────────────
create table if not exists task_logs (
  id              uuid primary key default gen_random_uuid(),
  lawn_id         uuid not null references lawns(id) on delete cascade,
  task_id         text not null,                   -- matches BASE_TASKS[].id in JS
  logged_date     date not null,
  created_at      timestamptz not null default now(),
  unique (lawn_id, task_id)                        -- one log per task per lawn
);

-- ── SOIL TEMPERATURE LOGS ──────────────────────────────────────
create table if not exists soil_logs (
  id              uuid primary key default gen_random_uuid(),
  lawn_id         uuid not null references lawns(id) on delete cascade,
  reading_date    date not null,
  temp_f          integer not null,
  created_at      timestamptz not null default now()
);

-- ── INDEXES ────────────────────────────────────────────────────
create index if not exists task_logs_lawn_id_idx  on task_logs(lawn_id);
create index if not exists soil_logs_lawn_id_idx  on soil_logs(lawn_id);
create index if not exists lawns_user_id_idx      on lawns(user_id);

-- ── ROW LEVEL SECURITY ─────────────────────────────────────────
-- Users can only see and modify their own data

alter table lawns     enable row level security;
alter table task_logs enable row level security;
alter table soil_logs enable row level security;

-- Lawns: owned by the authenticated user
create policy "Users manage own lawns"
  on lawns for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Task logs: user must own the parent lawn
create policy "Users manage own task logs"
  on task_logs for all
  using  (exists (select 1 from lawns where lawns.id = task_logs.lawn_id and lawns.user_id = auth.uid()))
  with check (exists (select 1 from lawns where lawns.id = task_logs.lawn_id and lawns.user_id = auth.uid()));

-- Soil logs: user must own the parent lawn
create policy "Users manage own soil logs"
  on soil_logs for all
  using  (exists (select 1 from lawns where lawns.id = soil_logs.lawn_id and lawns.user_id = auth.uid()))
  with check (exists (select 1 from lawns where lawns.id = soil_logs.lawn_id and lawns.user_id = auth.uid()));

-- ── DONE ───────────────────────────────────────────────────────
-- 3 tables, indexes, RLS policies — all set.
