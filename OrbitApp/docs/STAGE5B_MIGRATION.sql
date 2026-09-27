-- Orbit — Stage 5b: iMessage opt-in (run ONCE, after STAGE5_MIGRATION.sql).
-- Dashboard > SQL Editor > New query > Run.
--
-- Photon's shared lines (Free/Pro) can only text someone after they've texted
-- their assigned line once. An invite now waits in 'waiting' with that line's
-- number until they text "hi"; then Ground Control sends the welcome.

alter table imessage_invites drop constraint if exists imessage_invites_status_check;
alter table imessage_invites add constraint imessage_invites_status_check
  check (status in ('pending', 'waiting', 'sent', 'failed'));
alter table imessage_invites add column if not exists line text;
