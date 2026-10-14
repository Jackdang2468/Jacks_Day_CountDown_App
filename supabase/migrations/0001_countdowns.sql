-- Jack's Day Counter: database + file storage with per-user security.
-- Run once in Supabase dashboard > SQL Editor > New query > paste > Run.

-- Countdowns, one row per event, owned by the signed-in user.
create table if not exists public.countdowns (
  id          uuid primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 120),
  target_date timestamptz not null,
  is_all_day  boolean not null default true,
  notes       text not null default '' check (char_length(notes) <= 2000),
  theme       text not null default 'ocean',
  emoji       text,
  image_key   text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists countdowns_user_id_idx on public.countdowns (user_id);

-- Row-level security: nobody can read or change another user's rows,
-- and the anonymous (not signed-in) role gets nothing at all.
alter table public.countdowns enable row level security;
revoke all on public.countdowns from anon;

drop policy if exists "countdowns_select_own" on public.countdowns;
create policy "countdowns_select_own" on public.countdowns
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "countdowns_insert_own" on public.countdowns;
create policy "countdowns_insert_own" on public.countdowns
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "countdowns_update_own" on public.countdowns;
create policy "countdowns_update_own" on public.countdowns
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "countdowns_delete_own" on public.countdowns;
create policy "countdowns_delete_own" on public.countdowns
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Private photo bucket. Files live under <user id>/<file>, and each user can
-- only touch their own folder. 5 MB limit, images only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('countdown-images', 'countdown-images', false, 5242880, array['image/jpeg', 'image/png', 'image/heic'])
on conflict (id) do nothing;

drop policy if exists "images_select_own" on storage.objects;
create policy "images_select_own" on storage.objects
  for select to authenticated
  using (bucket_id = 'countdown-images' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "images_insert_own" on storage.objects;
create policy "images_insert_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'countdown-images' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "images_update_own" on storage.objects;
create policy "images_update_own" on storage.objects
  for update to authenticated
  using (bucket_id = 'countdown-images' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "images_delete_own" on storage.objects;
create policy "images_delete_own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'countdown-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
