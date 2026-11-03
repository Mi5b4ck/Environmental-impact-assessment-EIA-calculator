-- EIA Impact Assessor — make yourself the app owner
-- Run this once in Supabase (SQL Editor → New query → Run), AFTER supabase-setup.sql.
-- Replace the email below with the one you use to sign in to the app.
-- The owner is a moderator and is the only person who can make other people moderators.

insert into public.app_roles (user_id, role)
select id, 'owner' from auth.users where lower(email) = lower('you@example.com')
on conflict (user_id) do update set role = 'owner';

-- Check: this should list your account as owner.
select u.email, r.role from public.app_roles r join auth.users u on u.id = r.user_id;
