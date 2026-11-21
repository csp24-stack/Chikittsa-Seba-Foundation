-- Run once in Supabase > SQL Editor if forms show "permission denied"
grant usage on schema public to anon, authenticated;
grant insert on volunteers, members, blood_donors, blood_requests, contact_messages, donations to anon, authenticated;
grant select on site_settings, campaigns, events, activities, news, gallery, reports to anon, authenticated;
grant select on donations to authenticated;
grant select on admins to authenticated;
grant all on admins, site_settings, volunteers, members, donations, blood_donors, blood_requests,
  campaigns, events, activities, news, gallery, contact_messages, reports to authenticated;
