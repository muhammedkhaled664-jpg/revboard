-- ============================================================
-- RevBoard / SYNC — Supabase Auth + Row Level Security migration
-- Run this in: Supabase Dashboard > SQL Editor > New query > Run
-- Safe to run once. Read SECURITY_MIGRATION.md before running.
-- ============================================================

-- 1. Link the existing profile table (floor_users) to real auth accounts.
--    We keep name / role / department / status, and add an auth link + email.
alter table public.floor_users
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists email text;

create unique index if not exists floor_users_user_id_key on public.floor_users(user_id);
create unique index if not exists floor_users_email_key   on public.floor_users(lower(email));

-- 2. Helper functions (SECURITY DEFINER so they bypass RLS and avoid recursion).
--    They answer "what department am I in?" and "am I a manager?" for the
--    currently logged-in auth user.
create or replace function public.my_department()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select department from public.floor_users
  where user_id = auth.uid() and status = 'Active'
  limit 1;
$$;

create or replace function public.is_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select (role ilike '%Manager%' or role = 'Admin')
     from public.floor_users
     where user_id = auth.uid() and status = 'Active'
     limit 1),
    false);
$$;

-- 3. Turn ON Row Level Security. After this, the public anon key can no longer
--    read raw tables — every request is checked against the policies below.
alter table public.floor_users   enable row level security;
alter table public.pulses        enable row level security;
alter table public.activity_logs enable row level security;

-- ---- floor_users policies ----
-- You can always read your own profile (needed at login).
drop policy if exists fu_select_self on public.floor_users;
create policy fu_select_self on public.floor_users
  for select using (user_id = auth.uid());

-- You can read teammates in your own department.
drop policy if exists fu_select_dept on public.floor_users;
create policy fu_select_dept on public.floor_users
  for select using (department = public.my_department());

-- Only managers can add / change / remove people in their department.
drop policy if exists fu_insert_mgr on public.floor_users;
create policy fu_insert_mgr on public.floor_users
  for insert with check (public.is_manager() and department = public.my_department());

drop policy if exists fu_update_mgr on public.floor_users;
create policy fu_update_mgr on public.floor_users
  for update using (public.is_manager() and department = public.my_department());

drop policy if exists fu_delete_mgr on public.floor_users;
create policy fu_delete_mgr on public.floor_users
  for delete using (public.is_manager() and department = public.my_department());

-- ---- pulses (tasks) policies ----
-- Everyone in the department can see and work the department's tasks.
drop policy if exists pulses_select_dept on public.pulses;
create policy pulses_select_dept on public.pulses
  for select using (department = public.my_department());

drop policy if exists pulses_insert_dept on public.pulses;
create policy pulses_insert_dept on public.pulses
  for insert with check (department = public.my_department());

drop policy if exists pulses_update_dept on public.pulses;
create policy pulses_update_dept on public.pulses
  for update using (department = public.my_department());

-- Only managers can permanently delete tasks.
drop policy if exists pulses_delete_mgr on public.pulses;
create policy pulses_delete_mgr on public.pulses
  for delete using (public.is_manager() and department = public.my_department());

-- ---- activity_logs policies ----
drop policy if exists logs_select_dept on public.activity_logs;
create policy logs_select_dept on public.activity_logs
  for select using (department = public.my_department());

drop policy if exists logs_insert_dept on public.activity_logs;
create policy logs_insert_dept on public.activity_logs
  for insert with check (department = public.my_department());

-- ============================================================
-- 4. AFTER you have created auth accounts for everyone and confirmed
--    login works (see SECURITY_MIGRATION.md step 5), remove the old
--    plaintext password column by running JUST this line:
--
--    alter table public.floor_users drop column password;
--
--    Do NOT run it before logins work, or you can lock people out.
-- ============================================================
