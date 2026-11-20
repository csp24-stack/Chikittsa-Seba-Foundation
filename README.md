# Chikittsa Seba Foundation website

## Folder structure
```
chikittsa-seba/
├── index.html                      Home page (also contains the admin panel at #admin)
├── donation.html                   Donation form            -> table donations
├── medical-assistance.html         Medical assistance form  -> table medical_applications
├── member-registration.html        Member registration      -> table members
├── volunteer-registration.html     Volunteer registration   -> table volunteers
├── blood-donor-registration.html   Blood donor registration -> table blood_donors
├── blood-request.html              Emergency blood request  -> table blood_requests
├── medical-camp-application.html   Medical camp application -> table medical_camp_applications (new)
├── contact.html                    Contact form             -> table contact_messages
├── assets/
│   ├── css/style.css               Shared styles (logo is embedded inside this file)
│   └── js/common.js                Shared script: Supabase connection, language switch, form submit
├── supabase/
│   ├── setup-all.sql               First setup (tables, security rules)
│   ├── update-2-panel.sql          Admin panel update
│   └── update-3-camp-form.sql      Adds the medical camp applications table
└── README.md
```

## Setup
1. Supabase > SQL Editor: run `setup-all.sql`, then `update-2-panel.sql`, then `update-3-camp-form.sql` (each once).
2. Supabase keys: `index.html` (top of the script) and `assets/js/common.js` (top of the file). Publishable key only, never a secret key.
3. GitHub Pages: upload everything in this folder, keeping the `assets` folder. Settings > Pages > branch `main` / root.
4. Admin: Authentication > Users > add user, then run
   `insert into admins (user_id) select id from auth.users where email = 'YOU@example.com';`
   Open the site and click "Admin" (`index.html#admin`).
