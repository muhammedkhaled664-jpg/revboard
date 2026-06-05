-- ============================================================
-- QA Cases table
-- Run in: Supabase Dashboard > SQL Editor > New query > Run
-- ============================================================

create table if not exists public.qa_cases (
    id            bigserial primary key,
    agent_name    text not null,
    call_date     date,
    issue_type    text not null,
    comment       text,
    team          text,
    coaching_status text default 'Verbal',
    coaching_date date,
    wrong_dispo   boolean default false,
    warning_sent  boolean default false,
    deduction_sheet boolean default false,
    department    text,
    logged_by     text,
    created_at    timestamptz default now()
);

-- Enable RLS
alter table public.qa_cases enable row level security;

-- Same department-scoped policies as other tables
drop policy if exists qa_select_dept on public.qa_cases;
create policy qa_select_dept on public.qa_cases
  for select using (department = public.my_department());

drop policy if exists qa_insert_dept on public.qa_cases;
create policy qa_insert_dept on public.qa_cases
  for insert with check (department = public.my_department());

drop policy if exists qa_update_dept on public.qa_cases;
create policy qa_update_dept on public.qa_cases
  for update using (department = public.my_department());

drop policy if exists qa_delete_dept on public.qa_cases;
create policy qa_delete_dept on public.qa_cases
  for delete using (department = public.my_department());
