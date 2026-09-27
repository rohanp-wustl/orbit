-- Orbit — Stage 4 migration: private media.
-- Run ONCE, after STAGE3_MIGRATION.sql: Dashboard > SQL Editor > New query > Run.
--
-- Before: any signed-in user could read any file in the media bucket.
-- After: a file is readable only by
--   1. the person who uploaded it (its folder is their user id), or
--   2. the recipient of a capsule whose layout references that media id.
-- This backs the in-app promise "only you and the person you send to can
-- open a capsule" (Settings → About, docs/PRIVACY.md).

drop policy if exists "signed-in users can read media" on storage.objects;

create policy "uploader or capsule recipient can read media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.capsules c
        where c.recipient_id = auth.uid()
          and c.sender_id::text = (storage.foldername(name))[1]
          -- file name is "<media id>.<ext>"; the layout JSON lists media ids
          and position(split_part(storage.filename(name), '.', 1) in c.layout::text) > 0
      )
    )
  );

-- Let the recipient read the sender's media_assets rows for capsules they
-- received (transcripts stay with the uploader otherwise).
create policy "recipients can read media rows for their capsules"
  on media_assets for select to authenticated
  using (
    exists (
      select 1 from capsules c
      where c.recipient_id = auth.uid()
        and c.sender_id = media_assets.uploaded_by
        and position(media_assets.id::text in c.layout::text) > 0
    )
  );
