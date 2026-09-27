-- Orbit — Stage 2 migration: invite-code crew links.
-- Run ONCE, after SUPABASE_SETUP.sql: Dashboard > SQL Editor > New query > Run.
--
-- Why this is needed: SUPABASE_SETUP.sql's crew_links requires user_b up
-- front and only lets existing members read a row — so the person joining
-- with an invite code could never find the row to join it. Now:
--   1. user A inserts a row with user_b = null (an open invite)
--   2. user B calls join_crew('CODE'), which fills in user_b server-side

alter table crew_links alter column user_b drop not null;

-- Only let people create invites for themselves.
drop policy if exists "anyone signed in can create a crew link" on crew_links;
create policy "a user can create an invite for themselves"
  on crew_links for insert with check (auth.uid() = user_a);

-- `security definer` runs this with the table owner's rights, bypassing
-- RLS for exactly this one narrow operation: claim an open invite that
-- isn't your own. Returns the joined row, or nothing if the code is
-- wrong / already used.
create or replace function join_crew(code text)
returns setof crew_links
language sql
security definer
set search_path = public
as $$
  update crew_links
     set user_b = auth.uid()
   where invite_code = upper(trim(code))
     and user_b is null
     and user_a <> auth.uid()
  returning *;
$$;

grant execute on function join_crew(text) to authenticated;

-- Let the crew home screen update live when someone joins your invite.
alter publication supabase_realtime add table crew_links;
