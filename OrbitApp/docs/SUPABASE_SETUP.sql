-- Orbit — Supabase schema (free-tier MVP)
-- Paste this whole file into Supabase Dashboard > SQL Editor > New query > Run.
-- Replaces docs/DATA_MODELS.md's old Firestore collection structure.

-- Enable the extension gen_random_uuid() needs (on by default on new
-- Supabase projects, but harmless to run again).
create extension if not exists pgcrypto;

create table profiles (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  created_at timestamptz not null default now()
);

create table crew_links (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references profiles(id) on delete cascade,
  user_b uuid not null references profiles(id) on delete cascade,
  invite_code text unique not null,
  created_at timestamptz not null default now()
);

create table media_assets (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('photo', 'video', 'audio')),
  storage_path text not null,
  transcript text,
  uploaded_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table capsules (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references profiles(id) on delete cascade,
  recipient_id uuid not null references profiles(id) on delete cascade,
  crew_link_id uuid not null references crew_links(id) on delete cascade,
  status text not null default 'draft'
    check (status in ('draft', 'launched', 'in_transit', 'landed', 'opened')),
  layout jsonb not null,
  created_at timestamptz not null default now(),
  launched_at timestamptz,
  delivery_at timestamptz,
  delivery_delay_seconds int not null default 10,
  opened_at timestamptz,
  preview_image_path text
);

-- ---------------------------------------------------------------------
-- Row Level Security. These are intentionally permissive for hackathon
-- speed (any signed-in user, including anonymous sign-ins, can read/write
-- their own rows) — tighten later, don't block the demo on this now.
-- ---------------------------------------------------------------------

alter table profiles enable row level security;
alter table crew_links enable row level security;
alter table media_assets enable row level security;
alter table capsules enable row level security;

create policy "anyone signed in can read profiles"
  on profiles for select using (auth.role() = 'authenticated');
create policy "a user can create their own profile"
  on profiles for insert with check (auth.uid() = id);
create policy "a user can update their own profile"
  on profiles for update using (auth.uid() = id);

create policy "crew members can read their crew link"
  on crew_links for select using (auth.uid() in (user_a, user_b));
create policy "anyone signed in can create a crew link"
  on crew_links for insert with check (auth.role() = 'authenticated');

create policy "uploader can read their media"
  on media_assets for select using (auth.uid() = uploaded_by);
create policy "a user can upload their own media rows"
  on media_assets for insert with check (auth.uid() = uploaded_by);

create policy "sender or recipient can read a capsule"
  on capsules for select using (auth.uid() in (sender_id, recipient_id));
create policy "sender can create a capsule"
  on capsules for insert with check (auth.uid() = sender_id);
create policy "sender or recipient can update a capsule"
  on capsules for update using (auth.uid() in (sender_id, recipient_id));

-- Realtime: tell Supabase to publish changes on this table so
-- CapsuleRepository.subscribeToCapsules(...) gets live updates.
alter publication supabase_realtime add table capsules;
