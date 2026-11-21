-- Chikittsa Seba Foundation: run in Supabase > SQL Editor
create extension if not exists pgcrypto;

create table admins (user_id uuid primary key references auth.users on delete cascade,
  role text not null default 'admin' check (role in ('admin','editor')), created_at timestamptz default now());
create function is_admin() returns boolean language sql security definer stable as
$$ select exists (select 1 from admins where user_id = auth.uid()) $$;

create table site_settings (key text primary key, value text not null);
insert into site_settings values
 ('stat_volunteers','0'),('stat_people_helped','0'),('stat_medical_services','0'),('stat_campaigns','0'),
 ('email','info@example.org'),('phone','+880-XXXX-XXXXXX'),('address','[Office address]'),
 ('facebook',''),('youtube',''),('whatsapp',''),('banner','');

create table volunteers (id uuid primary key default gen_random_uuid(), full_name text not null check (char_length(full_name) between 2 and 120),
  email text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'), phone text not null, address text, date_of_birth date,
  profession text, skills text, department text, availability text, reason text, emergency_contact text,
  photo_path text, consent boolean not null check (consent), status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz default now());
create table members (id uuid primary key default gen_random_uuid(), full_name text not null, email text not null, phone text not null,
  address text, member_type text not null check (member_type in ('general','volunteer','donor','lifetime')),
  consent boolean not null check (consent), status text not null default 'pending' check (status in ('pending','approved','rejected')), created_at timestamptz default now());
create table donations (id uuid primary key default gen_random_uuid(), donor_name text not null, email text, phone text,
  amount numeric(12,2) not null check (amount > 0), purpose text, frequency text default 'one_time' check (frequency in ('one_time','monthly')),
  method text, transaction_ref text, status text not null default 'pending' check (status in ('pending','verified','failed')),
  user_id uuid references auth.users, created_at timestamptz default now());
create table blood_donors (id uuid primary key default gen_random_uuid(), full_name text not null, blood_group text not null check (blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  district text not null, upazila text, phone text not null, share_contact_consent boolean not null default false, consent boolean not null check (consent),
  status text not null default 'pending' check (status in ('pending','approved','rejected')), created_at timestamptz default now());
create table blood_requests (id uuid primary key default gen_random_uuid(), patient_name text, blood_group text not null, district text not null,
  hospital text, needed_by date, contact_name text not null, contact_phone text not null, details text,
  status text not null default 'pending' check (status in ('pending','approved','fulfilled','rejected')), created_at timestamptz default now());
create table campaigns (id uuid primary key default gen_random_uuid(), title text not null, description text, goal_amount numeric(12,2),
  starts_on date, ends_on date, image_path text, published boolean default false, created_at timestamptz default now());
create table events (id uuid primary key default gen_random_uuid(), title text not null, description text, event_date timestamptz,
  location text, image_path text, published boolean default false, created_at timestamptz default now());
create table activities (id uuid primary key default gen_random_uuid(), program text not null, title text not null, description text,
  activity_date date, location text, beneficiaries int, image_path text, published boolean default false, created_at timestamptz default now());
create table news (id uuid primary key default gen_random_uuid(), title text not null, slug text unique, body text, image_path text,
  published boolean default false, created_at timestamptz default now());
create table gallery (id uuid primary key default gen_random_uuid(), category text not null, caption text, media_path text not null,
  media_type text default 'image' check (media_type in ('image','video')), published boolean default true, created_at timestamptz default now());
create table contact_messages (id uuid primary key default gen_random_uuid(), name text not null, email text not null, message text not null check (char_length(message) <= 4000),
  is_read boolean default false, created_at timestamptz default now());
create table reports (id uuid primary key default gen_random_uuid(), title text not null, category text not null, file_path text not null,
  published boolean default false, created_at timestamptz default now());

-- Row Level Security
do $$ declare t text; begin
 foreach t in array array['admins','site_settings','volunteers','members','donations','blood_donors','blood_requests','campaigns','events','activities','news','gallery','contact_messages','reports']
 loop execute format('alter table %I enable row level security', t);
   if t <> 'admins' then execute format('create policy "admin all" on %I for all using (is_admin()) with check (is_admin())', t); end if;
 end loop; end $$;
create policy "admins read self" on admins for select using (user_id = auth.uid());

-- Public read (published content only)
create policy "read settings" on site_settings for select using (key <> 'secret');
do $$ declare t text; begin
 foreach t in array array['campaigns','events','activities','news','gallery','reports'] loop
  execute format('create policy "public read" on %I for select using (published)', t); end loop; end $$;

-- Public forms: insert only, always as pending
create policy "apply volunteer" on volunteers for insert with check (status = 'pending' and consent);
create policy "apply member" on members for insert with check (status = 'pending' and consent);
create policy "register donor" on blood_donors for insert with check (status = 'pending' and consent);
create policy "request blood" on blood_requests for insert with check (status = 'pending');
create policy "send message" on contact_messages for insert with check (true);
create policy "pledge donation" on donations for insert with check (status = 'pending');
create policy "own donations" on donations for select using (user_id = auth.uid());

-- Public donor directory: approved donors, no phone, no full name
create view public_blood_donors with (security_invoker = off) as
 select id, split_part(full_name,' ',1) || ' ' || left(coalesce(nullif(split_part(full_name,' ',2),''),'-'),1) || '.' as display_name,
 blood_group, district, upazila from blood_donors where status = 'approved';
grant select on public_blood_donors to anon, authenticated;

-- Storage: public bucket for media, private bucket for volunteer photos
insert into storage.buckets (id, name, public) values ('media','media',true),('private-uploads','private-uploads',false) on conflict do nothing;
create policy "media read" on storage.objects for select using (bucket_id = 'media');
create policy "media admin write" on storage.objects for all using (bucket_id = 'media' and is_admin()) with check (bucket_id = 'media' and is_admin());
create policy "volunteer photo upload" on storage.objects for insert with check (bucket_id = 'private-uploads' and (storage.extension(name) in ('jpg','jpeg','png','webp')));
create policy "admin read private" on storage.objects for select using (bucket_id = 'private-uploads' and is_admin());

-- After creating your admin user in Authentication > Users, run:
-- insert into admins (user_id) values ('<YOUR-USER-UUID>');

-- ===== permissions =====
grant usage on schema public to anon, authenticated;
grant insert on volunteers, members, blood_donors, blood_requests, contact_messages, donations to anon, authenticated;
grant select on site_settings, campaigns, events, activities, news, gallery, reports to anon, authenticated;
grant select on donations to authenticated;
grant select on admins to authenticated;
grant all on admins, site_settings, volunteers, members, donations, blood_donors, blood_requests,
  campaigns, events, activities, news, gallery, contact_messages, reports to authenticated;

-- reload schema cache
notify pgrst, 'reload schema';
