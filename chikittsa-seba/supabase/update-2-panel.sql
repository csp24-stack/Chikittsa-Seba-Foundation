-- Run once in Supabase > SQL Editor (after setup-all.sql). Safe to run again.

-- 1) Medical help applications (public form -> admin review)
create table if not exists medical_applications (
  id uuid primary key default gen_random_uuid(),
  patient_name text not null check (char_length(patient_name) between 2 and 120),
  age int check (age between 0 and 120),
  phone text not null,
  address text,
  condition text not null check (char_length(condition) <= 2000),
  help_needed text check (char_length(help_needed) <= 2000),
  consent boolean not null check (consent),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz default now()
);

-- 2) Income and expenses ledger (admin only)
create table if not exists income_expenses (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('income','expense')),
  amount numeric(12,2) not null check (amount > 0),
  category text,
  note text,
  entry_date date not null default current_date,
  created_at timestamptz default now()
);

alter table medical_applications enable row level security;
alter table income_expenses enable row level security;

drop policy if exists "admin all" on medical_applications;
drop policy if exists "admin all" on income_expenses;
drop policy if exists "apply medical" on medical_applications;
create policy "admin all" on medical_applications for all using (is_admin()) with check (is_admin());
create policy "admin all" on income_expenses for all using (is_admin()) with check (is_admin());
create policy "apply medical" on medical_applications for insert with check (status = 'pending' and consent);

grant insert on medical_applications to anon, authenticated;
grant all on medical_applications, income_expenses to authenticated;

-- 3) Admin roles: only role 'admin' may manage the admin list
create or replace function is_super() returns boolean language sql security definer stable set search_path = public as
$$ select exists (select 1 from admins where user_id = auth.uid() and role = 'admin') $$;

drop policy if exists "super manage admins" on admins;
create policy "super manage admins" on admins for all using (is_super()) with check (is_super());
grant select, insert, update, delete on admins to authenticated;

create or replace function list_admins()
returns table (user_id uuid, email text, role text, created_at timestamptz)
language sql security definer stable set search_path = public, auth as
$$ select a.user_id, u.email::text, a.role, a.created_at
   from admins a join auth.users u on u.id = a.user_id where is_super() order by a.created_at $$;

create or replace function add_admin(p_email text, p_role text default 'editor') returns text
language plpgsql security definer set search_path = public, auth as
$$
declare uid uuid;
begin
  if not is_super() then raise exception 'not allowed'; end if;
  if p_role not in ('admin','editor') then raise exception 'bad role'; end if;
  select id into uid from auth.users where lower(email) = lower(trim(p_email));
  if uid is null then return 'not_found'; end if;
  insert into admins (user_id, role) values (uid, p_role)
    on conflict (user_id) do update set role = excluded.role;
  return 'ok';
end;
$$;

revoke all on function list_admins() from public, anon;
revoke all on function add_admin(text, text) from public, anon;
grant execute on function list_admins() to authenticated;
grant execute on function add_admin(text, text) to authenticated;

notify pgrst, 'reload schema';
