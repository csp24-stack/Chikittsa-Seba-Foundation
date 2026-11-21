-- Run once in Supabase > SQL Editor. Safe to run again.
-- Adds the only new table needed by the separate form pages: medical camp applications.
-- All other forms use existing tables (donations, medical_applications, members, volunteers, blood_donors, blood_requests, contact_messages).

create table if not exists medical_camp_applications (
  id uuid primary key default gen_random_uuid(),
  organization_name text not null check (char_length(organization_name) between 2 and 160),
  contact_person text not null check (char_length(contact_person) between 2 and 120),
  phone text not null,
  email text,
  district text,
  upazila text,
  venue text not null check (char_length(venue) <= 240),
  preferred_date date,
  expected_participants int check (expected_participants > 0),
  camp_type text not null default 'general' check (camp_type in ('general','eye','mother_child','other')),
  details text check (char_length(details) <= 2000),
  consent boolean not null check (consent),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz default now()
);

alter table medical_camp_applications enable row level security;
drop policy if exists "admin all" on medical_camp_applications;
drop policy if exists "apply camp" on medical_camp_applications;
create policy "admin all" on medical_camp_applications for all using (is_admin()) with check (is_admin());
create policy "apply camp" on medical_camp_applications for insert with check (status = 'pending' and consent);

grant insert on medical_camp_applications to anon, authenticated;
grant all on medical_camp_applications to authenticated;

notify pgrst, 'reload schema';
