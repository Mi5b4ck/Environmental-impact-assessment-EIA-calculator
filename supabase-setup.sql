-- EIA Impact Assessor — Supabase setup
-- Paste this whole file into Supabase: SQL Editor → New query → Run.
-- Safe to run more than once.

-- 1. People's display names --------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  updated_at   timestamptz not null default now()
);
alter table public.profiles enable row level security;

drop policy if exists "Signed-in users can see names" on public.profiles;
create policy "Signed-in users can see names"
  on public.profiles for select to authenticated using (true);

drop policy if exists "Users create their own profile" on public.profiles;
create policy "Users create their own profile"
  on public.profiles for insert to authenticated with check (id = (select auth.uid()));

drop policy if exists "Users edit their own profile" on public.profiles;
create policy "Users edit their own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- 2. Assessments and sharing ---------------------------------------------
-- The creator (owner) controls access, like sharing in Canva:
--   access = 'private' : only the creator and the people they add
--   access = 'view'    : everyone signed in can view (default)
--   access = 'edit'    : everyone signed in can view and edit
--   editors / viewers  : people the creator added by name or email
-- Only the creator can delete an assessment or change who has access.
create table if not exists public.assessments (
  id         text primary key,
  owner      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  doc        jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.assessments add column if not exists access  text   not null default 'view';
alter table public.assessments add column if not exists editors uuid[] not null default '{}';
alter table public.assessments add column if not exists viewers uuid[] not null default '{}';
do $$ begin
  alter table public.assessments add constraint assessments_access_check check (access in ('private','view','edit'));
exception when duplicate_object then null; end $$;
create index if not exists assessments_owner_idx on public.assessments(owner);
alter table public.assessments enable row level security;

drop policy if exists "Signed-in users can read all assessments" on public.assessments;
drop policy if exists "Read assessments shared with you" on public.assessments;
create policy "Read assessments shared with you"
  on public.assessments for select to authenticated
  using (owner = (select auth.uid()) or access in ('view','edit')
         or (select auth.uid()) = any(editors) or (select auth.uid()) = any(viewers));

drop policy if exists "Authors create their own assessments" on public.assessments;
create policy "Authors create their own assessments"
  on public.assessments for insert to authenticated with check (owner = (select auth.uid()));

drop policy if exists "Only the author can edit" on public.assessments;
drop policy if exists "Creator and editors can edit" on public.assessments;
create policy "Creator and editors can edit"
  on public.assessments for update to authenticated
  using      (owner = (select auth.uid()) or access = 'edit' or (select auth.uid()) = any(editors))
  with check (owner = (select auth.uid()) or access = 'edit' or (select auth.uid()) = any(editors));

drop policy if exists "Only the author can delete" on public.assessments;
drop policy if exists "Only the creator can delete" on public.assessments;
create policy "Only the creator can delete"
  on public.assessments for delete to authenticated using (owner = (select auth.uid()));

-- Editors may change the content only; owner and sharing columns are
-- changed through set_assessment_sharing(), which checks the creator.
revoke update on public.assessments from authenticated, anon;
grant update (doc, updated_at) on public.assessments to authenticated;

create or replace function public.set_assessment_sharing(p_id text, p_access text, p_editors uuid[], p_viewers uuid[])
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_access not in ('private','view','edit') then
    raise exception 'Invalid access level';
  end if;
  update public.assessments
     set access  = p_access,
         editors = coalesce(p_editors, '{}'),
         viewers = coalesce(p_viewers, '{}')
   where id = p_id and owner = auth.uid();
  if not found then
    raise exception 'Only the creator can change who has access';
  end if;
end $$;
revoke all on function public.set_assessment_sharing(text, text, uuid[], uuid[]) from public, anon;
grant execute on function public.set_assessment_sharing(text, text, uuid[], uuid[]) to authenticated;

-- Find a person by their exact email, to add them to an assessment.
-- Returns only their id and display name, never the email list.
create or replace function public.find_user_by_email(p_email text)
returns table(id uuid, display_name text)
language sql stable security definer set search_path = public, auth as $$
  select u.id, coalesce(p.display_name, '')
    from auth.users u left join public.profiles p on p.id = u.id
   where auth.uid() is not null and lower(u.email) = lower(trim(p_email))
   limit 1;
$$;
revoke all on function public.find_user_by_email(text) from public, anon;
grant execute on function public.find_user_by_email(text) to authenticated;

-- List people in the app for the Share window, filtered by any part of
-- their name or email. Only signed-in users can call it.
create or replace function public.search_app_users(p_q text default '')
returns table(id uuid, display_name text, email text)
language sql stable security definer set search_path = public, auth as $$
  select u.id, coalesce(p.display_name, ''), u.email::text
    from auth.users u left join public.profiles p on p.id = u.id
   where auth.uid() is not null
     and u.id <> auth.uid()
     and (coalesce(trim(p_q), '') = ''
          or position(lower(trim(p_q)) in lower(coalesce(p.display_name, ''))) > 0
          or position(lower(trim(p_q)) in lower(coalesce(u.email, ''))) > 0)
   order by lower(coalesce(nullif(p.display_name, ''), u.email))
   limit 50;
$$;
revoke all on function public.search_app_users(text) from public, anon;
grant execute on function public.search_app_users(text) to authenticated;

-- Live co-editing ---------------------------------------------------------
-- Every change is sent as a small operation (set one score, rename one
-- impact, add or remove an impact...) and applied inside the database while
-- the row is locked. Two people editing the same assessment, or the same
-- impact, at the same time never overwrite each other's other changes.
-- Runs with the caller's rights, so the sharing rules above still apply.
create or replace function public.apply_assessment_patch(p_id text, p_ops jsonb)
returns jsonb language plpgsql security invoker set search_path = public as $$
declare
  d jsonb; op jsonb; idx int; p text[];
begin
  select doc into d from public.assessments where id = p_id for update;
  if not found then
    raise exception 'You do not have edit access to this assessment';
  end if;
  d := jsonb_set(d, '{impacts}', coalesce(d->'impacts', '[]'::jsonb), true);
  for op in select * from jsonb_array_elements(coalesce(p_ops, '[]'::jsonb)) loop
    idx := null;
    if op->>'op' in ('imp_set', 'ev_add', 'ev_del') then
      select (e.ord - 1)::int into idx
        from jsonb_array_elements(d->'impacts') with ordinality e(v, ord)
       where e.v->>'id' = op->>'imp';
      continue when idx is null;  -- the impact was removed meanwhile
    end if;
    case op->>'op'
      when 'field' then
        if op->>'key' not in ('title', 'project', 'location', 'description', 'status') then
          raise exception 'This field cannot be changed';
        end if;
        d := jsonb_set(d, array[op->>'key'], coalesce(op->'value', 'null'::jsonb), true);
      when 'imp_add' then
        continue when op->'value'->>'id' is null
          or exists (select 1 from jsonb_array_elements(d->'impacts') v where v->>'id' = op->'value'->>'id');
        d := jsonb_set(d, '{impacts}', (d->'impacts') || jsonb_build_array(op->'value'), true);
      when 'imp_del' then
        d := jsonb_set(d, '{impacts}', coalesce((select jsonb_agg(e.v order by e.ord)
               from jsonb_array_elements(d->'impacts') with ordinality e(v, ord)
              where e.v->>'id' <> op->>'imp'), '[]'::jsonb), true);
      when 'imp_set' then
        p := array(select jsonb_array_elements_text(op->'path'));
        if p[1] not in ('name', 'category', 'phases', 'sel', 'rsel', 'notes', 'mitigation') then
          raise exception 'This impact field cannot be changed';
        end if;
        d := jsonb_set(d, array['impacts', idx::text] || p, coalesce(op->'value', 'null'::jsonb), true);
      when 'ev_add' then
        d := jsonb_set(d, array['impacts', idx::text, 'evidence'],
               coalesce(d #> array['impacts', idx::text, 'evidence'], '[]'::jsonb) || jsonb_build_array(op->'value'), true);
      when 'ev_del' then
        d := jsonb_set(d, array['impacts', idx::text, 'evidence'],
               coalesce((select jsonb_agg(v) from jsonb_array_elements(coalesce(d #> array['impacts', idx::text, 'evidence'], '[]'::jsonb)) v
                          where v->>'id' <> op->>'id'), '[]'::jsonb), true);
      else
        raise exception 'Unknown change';
    end case;
  end loop;
  d := jsonb_set(d, '{updatedAt}', to_jsonb((extract(epoch from now()) * 1000)::bigint), true);
  d := jsonb_set(d, '{updatedBy}', to_jsonb(auth.uid()), true);
  update public.assessments set doc = d, updated_at = now() where id = p_id;
  return d;
end $$;
revoke all on function public.apply_assessment_patch(text, jsonb) from public, anon;
grant execute on function public.apply_assessment_patch(text, jsonb) to authenticated;

-- Private workspace: each person's dashboard and compare settings ---------
-- Only the owner of a row can read or change it.
create table if not exists public.user_settings (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  dashboard  jsonb not null default '{}'::jsonb,
  compare    jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.user_settings enable row level security;
drop policy if exists "Read your own settings" on public.user_settings;
create policy "Read your own settings" on public.user_settings for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Create your own settings" on public.user_settings;
create policy "Create your own settings" on public.user_settings for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Update your own settings" on public.user_settings;
create policy "Update your own settings" on public.user_settings for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Live updates: everyone sees changes as they happen
do $$ begin
  alter publication supabase_realtime add table public.assessments;
exception when duplicate_object then null; end $$;

-- 3. Evidence files (photos, PDFs, data) ---------------------------------
-- Public bucket: anyone with a file's link can open it. Uploads go into a
-- folder named after the uploader, and only they can delete their files.
insert into storage.buckets (id, name, public, file_size_limit)
values ('evidence', 'evidence', true, 20971520)
on conflict (id) do nothing;

drop policy if exists "Signed-in users upload to their own folder" on storage.objects;
create policy "Signed-in users upload to their own folder"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'evidence' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "Uploaders delete their own files" on storage.objects;
create policy "Uploaders delete their own files"
  on storage.objects for delete to authenticated
  using (bucket_id = 'evidence' and (storage.foldername(name))[1] = (select auth.uid())::text);
