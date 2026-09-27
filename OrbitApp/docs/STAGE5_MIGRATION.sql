-- Orbit — Stage 5 migration: Ground Control in iMessage (Photon Spectrum).
-- Run ONCE, after STAGE4_MIGRATION.sql: Dashboard > SQL Editor > New query > Run.
--
-- Lets crew members live in iMessage instead of the app (e.g. Grandma):
-- the agent server (agent/, runs with the service-role key) creates their
-- profile, texts landed capsules to them, and turns their iMessage replies
-- into capsules that fly back. See docs/PHOTON.md.

-- Who can be reached in iMessage.
alter table profiles add column if not exists phone text unique;
alter table profiles add column if not exists imessage_only boolean not null default false;
alter table profiles add column if not exists imessage_updates boolean not null default false;

-- Track the iMessage side of each capsule.
alter table capsules add column if not exists source text not null default 'app'
  check (source in ('app', 'imessage'));
alter table capsules add column if not exists imessage_notified_at timestamptz;

-- The app asks the agent to invite someone by phone through this table
-- (no public server URL needed — the agent polls it with the service key).
create table if not exists imessage_invites (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references profiles(id) on delete cascade,
  display_name text not null,
  phone text not null,
  status text not null default 'pending' check (status in ('pending', 'sent', 'failed')),
  error text,
  profile_id uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table imessage_invites enable row level security;

create policy "inviter can create invites"
  on imessage_invites for insert to authenticated with check (auth.uid() = inviter_id);
create policy "inviter can see their invites"
  on imessage_invites for select to authenticated using (auth.uid() = inviter_id);

-- Live status in the app while Ground Control sends the invite.
alter publication supabase_realtime add table imessage_invites;
