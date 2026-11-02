-- Samaa: database setup. Run this once in your Supabase project (SQL Editor → New query → Run).

-- One row per player: their whole progress as JSON, plus the fields the weekly league needs.
create table if not exists public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  display_name text not null default 'Oud player' check (char_length(display_name) <= 24),
  state        jsonb not null default '{}'::jsonb,
  week_xp      integer not null default 0,
  week_key     text,
  updated_at   timestamptz not null default now()
);

-- Row-level security: every player can read and write only their own row.
alter table public.profiles enable row level security;

drop policy if exists "read own profile"   on public.profiles;
drop policy if exists "insert own profile" on public.profiles;
drop policy if exists "update own profile" on public.profiles;
create policy "read own profile"   on public.profiles for select using (auth.uid() = id);
create policy "insert own profile" on public.profiles for insert with check (auth.uid() = id);
create policy "update own profile" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- The league: signed-in players see the top 20 names and weekly XP. Nothing else is exposed.
create or replace function public.leaderboard(wk text)
returns table (id uuid, display_name text, week_xp integer)
language sql stable security definer set search_path = public
as $$
  select p.id, p.display_name, p.week_xp
  from public.profiles p
  where p.week_key = wk and p.week_xp > 0
  order by p.week_xp desc, p.updated_at asc
  limit 20;
$$;

revoke all on function public.leaderboard(text) from public, anon;
grant execute on function public.leaderboard(text) to authenticated;
