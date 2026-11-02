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

-- 2. Assessments: everyone signed in reads, only the author writes -------
create table if not exists public.assessments (
  id         text primary key,
  owner      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  doc        jsonb not null,
  updated_at timestamptz not null default now()
);
create index if not exists assessments_owner_idx on public.assessments(owner);
alter table public.assessments enable row level security;

drop policy if exists "Signed-in users can read all assessments" on public.assessments;
create policy "Signed-in users can read all assessments"
  on public.assessments for select to authenticated using (true);

drop policy if exists "Authors create their own assessments" on public.assessments;
create policy "Authors create their own assessments"
  on public.assessments for insert to authenticated with check (owner = (select auth.uid()));

drop policy if exists "Only the author can edit" on public.assessments;
create policy "Only the author can edit"
  on public.assessments for update to authenticated
  using (owner = (select auth.uid())) with check (owner = (select auth.uid()));

drop policy if exists "Only the author can delete" on public.assessments;
create policy "Only the author can delete"
  on public.assessments for delete to authenticated using (owner = (select auth.uid()));

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
