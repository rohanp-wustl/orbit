-- Orbit — Stage 3 migration: photo storage.
-- Run ONCE, after STAGE2_MIGRATION.sql: Dashboard > SQL Editor > New query > Run.
--
-- Creates a private "media" Storage bucket. Files live at
-- media/<sender uid>/<media id>.jpg (see Shared/Services/MediaRepository.swift).

insert into storage.buckets (id, name, public)
values ('media', 'media', false)
on conflict (id) do nothing;

-- Upload only into your own folder.
create policy "users upload into their own media folder"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);

-- upsert: true in the app needs update rights on your own files too.
create policy "users update their own media"
  on storage.objects for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);

-- Hackathon-permissive: any signed-in user can read any media file. File
-- names are random UUIDs, so they aren't guessable — but tighten this to
-- "sender or recipient of a capsule that references it" in Stage 5.
create policy "signed-in users can read media"
  on storage.objects for select to authenticated
  using (bucket_id = 'media');
