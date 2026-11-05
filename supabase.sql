-- Samaa: database setup. Run this in your Supabase project (SQL Editor → New query → Run).
-- It is safe to run again after an update.
--
-- How the leaderboard stays fair: players can never write XP themselves. Their app asks award_xp()
-- for each finished lesson, and the server enforces a limit per lesson, per hour and per day.

-- ---------- players ----------
create table if not exists public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  display_name text not null,
  country      text check (country is null or country ~ '^[A-Z]{2}$'),
  avatar       text check (avatar is null or avatar ~ '^[a-z]{1,16}$'),
  state        jsonb not null default '{}'::jsonb check (pg_column_size(state) < 500000),
  xp_total     integer not null default 0,
  week_xp      integer not null default 0,
  week_key     text,
  day_key      date,
  day_xp       integer not null default 0,
  streak       integer not null default 0,
  banned       boolean not null default false,   -- set by you in the Table Editor; hides a cheater from the boards
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table public.profiles add column if not exists country text;
alter table public.profiles add column if not exists avatar text;
alter table public.profiles add column if not exists xp_total integer not null default 0;
alter table public.profiles add column if not exists day_key date;
alter table public.profiles add column if not exists day_xp integer not null default 0;
alter table public.profiles add column if not exists streak integer not null default 0;
alter table public.profiles add column if not exists banned boolean not null default false;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles alter column display_name drop default;

-- names: 3 to 20 letters, digits, spaces and . _ -; Arabic welcome; unique regardless of capitals
alter table public.profiles drop constraint if exists profiles_display_name_check;
alter table public.profiles drop constraint if exists profiles_name_format;
alter table public.profiles add constraint profiles_name_format
  check (display_name ~ '^[A-Za-z0-9À-ɏ؀-ۿ._-][A-Za-z0-9À-ɏ؀-ۿ ._-]{1,18}[A-Za-z0-9À-ɏ؀-ۿ._-]$');
create unique index if not exists profiles_name_unique on public.profiles (lower(display_name));
create index if not exists profiles_all_board on public.profiles (xp_total desc) where not banned and xp_total > 0;
create index if not exists profiles_week_board on public.profiles (week_key, week_xp desc) where not banned and week_xp > 0;

-- every award, for retries and for spotting cheaters
create table if not exists public.xp_log (
  id      uuid primary key,
  user_id uuid not null references public.profiles on delete cascade,
  lesson  text not null,
  xp      integer not null,
  at      timestamptz not null default now()
);
create index if not exists xp_log_user_time on public.xp_log (user_id, at desc);

-- ---------- who may touch what ----------
-- Row-level security keeps each row private to its owner; the column grants mean that even the owner
-- can change only their name, country, avatar and saved progress. XP columns are out of reach.
alter table public.profiles enable row level security;
alter table public.xp_log   enable row level security;

drop policy if exists "read own profile"   on public.profiles;
drop policy if exists "insert own profile" on public.profiles;
drop policy if exists "update own profile" on public.profiles;
create policy "read own profile"   on public.profiles for select to authenticated using (auth.uid() = id);
create policy "update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

revoke all on public.profiles from public, anon, authenticated;
revoke all on public.xp_log   from public, anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, country, avatar, state, updated_at) on public.profiles to authenticated;

-- ---------- a profile for every new account ----------
create or replace function public.clean_name(raw text)
returns text language sql immutable as $$
  select left(trim(both ' ' from regexp_replace(coalesce(raw, ''), '[^A-Za-z0-9À-ɏ؀-ۿ ._-]', '', 'g')), 20);
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  base text := public.clean_name(new.raw_user_meta_data ->> 'display_name');
  candidate text;
begin
  if char_length(base) < 3 or base !~ '[^ ._-]$' then base := 'Oud player'; end if;
  candidate := base;
  while exists (select 1 from public.profiles where lower(display_name) = lower(candidate)) loop
    candidate := left(base, 15) || ' ' || (1000 + floor(random() * 9000))::int;
  end loop;
  insert into public.profiles (id, display_name) values (new.id, candidate);
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- earning XP ----------
create or replace function public.week_now()
returns text language sql stable as $$ select to_char(now() at time zone 'utc', 'IYYY-"W"IW'); $$;

-- p_id is made by the app, so a retry after a dropped connection can't pay twice.
create or replace function public.award_xp(p_id uuid, p_lesson text, p_xp integer)
returns table (awarded integer, xp_total integer, week_xp integer, streak integer)
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := auth.uid();
  max_lesson constant integer := 60;     -- a mastery test at Double XP
  max_hour   constant integer := 40;     -- awards in any 60 minutes
  max_day    constant integer := 1500;   -- XP in a UTC day
  p    public.profiles;
  today date := (now() at time zone 'utc')::date;
  wk   text := public.week_now();
  gain integer := 0;
begin
  if me is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if p_lesson !~ '^[A-Za-z0-9-]{1,32}$' or p_xp is null then raise exception 'bad award' using errcode = '22023'; end if;

  select * into p from public.profiles where id = me for update;
  if not found then raise exception 'no profile' using errcode = 'P0002'; end if;

  if exists (select 1 from public.xp_log where id = p_id) then null;   -- already paid
  elsif (select count(*) from public.xp_log l where l.user_id = me and l.at > now() - interval '1 hour') >= max_hour then null;
  else
    if p.day_key is distinct from today then p.day_xp := 0; end if;
    gain := greatest(0, least(p_xp, max_lesson, max_day - p.day_xp));
    if gain > 0 then
      insert into public.xp_log (id, user_id, lesson, xp) values (p_id, me, p_lesson, gain);
      update public.profiles u set
        xp_total = u.xp_total + gain,
        week_xp  = case when u.week_key = wk then u.week_xp + gain else gain end,
        week_key = wk,
        streak   = case when u.day_key = today then u.streak when u.day_key = today - 1 then u.streak + 1 else 1 end,
        day_xp   = p.day_xp + gain,
        day_key  = today
      where u.id = me;
    end if;
  end if;

  return query select gain, u.xp_total, case when u.week_key = wk then u.week_xp else 0 end, u.streak
    from public.profiles u where u.id = me;
end $$;

-- ---------- the world leaderboard ----------
-- scope: 'week' or 'all'. Open to everyone, signed in or not. It never shows emails or progress.
drop function if exists public.leaderboard(text);
create or replace function public.leaderboard(scope text default 'week', max_rows integer default 100)
returns table (place bigint, id uuid, display_name text, country text, avatar text, xp integer, streak integer)
language sql stable security definer set search_path = public as $$
  select rank() over (order by b.xp desc), b.id, b.display_name, b.country, b.avatar, b.xp, b.streak
  from (
    select p.id, p.display_name, p.country, p.avatar, p.streak, p.created_at,
           case when scope = 'all' then p.xp_total else p.week_xp end as xp
    from public.profiles p
    where not p.banned and (case when scope = 'all' then p.xp_total > 0 else p.week_key = public.week_now() and p.week_xp > 0 end)
  ) b
  order by b.xp desc, b.created_at asc
  limit least(greatest(max_rows, 1), 200);
$$;

-- your own place, even far outside the top 100
create or replace function public.my_rank(scope text default 'week')
returns table (place bigint, players bigint, xp integer)
language sql stable security definer set search_path = public as $$
  with b as (
    select p.id, case when scope = 'all' then p.xp_total else p.week_xp end as xp
    from public.profiles p
    where not p.banned and (case when scope = 'all' then p.xp_total > 0 else p.week_key = public.week_now() and p.week_xp > 0 end)
  )
  select (select count(*) + 1 from b where b.xp > mine.xp), (select count(*) from b), mine.xp
  from b mine where mine.id = auth.uid();
$$;

-- a player's public card
create or replace function public.player_card(player uuid)
returns table (display_name text, country text, avatar text, xp integer, week_xp integer, streak integer, joined timestamptz)
language sql stable security definer set search_path = public as $$
  select p.display_name, p.country, p.avatar, p.xp_total,
         case when p.week_key = public.week_now() then p.week_xp else 0 end, p.streak, p.created_at
  from public.profiles p where p.id = player and not p.banned;
$$;

-- ---------- closing an account: removes the login, the profile and the XP history ----------
create or replace function public.delete_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  delete from auth.users where id = auth.uid();
end $$;

revoke all on function public.award_xp(uuid, text, integer) from public, anon;
revoke all on function public.my_rank(text) from public, anon;
revoke all on function public.delete_account() from public, anon;
revoke all on function public.leaderboard(text, integer) from public;
revoke all on function public.player_card(uuid) from public;
revoke all on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.award_xp(uuid, text, integer) to authenticated;
grant execute on function public.my_rank(text) to authenticated;
grant execute on function public.delete_account() to authenticated;
grant execute on function public.leaderboard(text, integer) to anon, authenticated;
grant execute on function public.player_card(uuid) to anon, authenticated;

-- ---------- accounts made before this version ----------
insert into public.profiles (id, display_name)
  select u.id, 'Oud player ' || (1000 + floor(random() * 9000))::int from auth.users u
  where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict do nothing;
