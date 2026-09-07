-- Run this in Supabase → SQL Editor.
-- Adds the tables the new Notebooks (Gemini) feature needs.
-- Assumes your existing `chats` table already has RLS enabled the same way —
-- follow that same pattern here so notebooks are private per-user.

create extension if not exists "uuid-ossp";

create table if not exists notebooks (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled notebook',
  summary text,
  created_at timestamptz not null default now()
);

create table if not exists notebook_sources (
  id uuid primary key default uuid_generate_v4(),
  notebook_id uuid not null references notebooks(id) on delete cascade,
  title text not null,
  mime_type text not null default 'text/plain',
  text_content text,
  base64_data text,
  created_at timestamptz not null default now()
);

create table if not exists notebook_messages (
  id uuid primary key default uuid_generate_v4(),
  notebook_id uuid not null references notebooks(id) on delete cascade,
  is_user boolean not null default true,
  text text not null,
  created_at timestamptz not null default now()
);

create table if not exists notebook_notes (
  id uuid primary key default uuid_generate_v4(),
  notebook_id uuid not null references notebooks(id) on delete cascade,
  title text not null default 'Untitled note',
  content text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table notebooks enable row level security;
alter table notebook_sources enable row level security;
alter table notebook_messages enable row level security;
alter table notebook_notes enable row level security;

-- Notebooks: only the owner can see/edit their own notebooks.
create policy "Users manage their own notebooks"
  on notebooks for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Sources: allowed if the parent notebook belongs to the user.
create policy "Users manage sources in their own notebooks"
  on notebook_sources for all
  using (exists (
    select 1 from notebooks
    where notebooks.id = notebook_sources.notebook_id
    and notebooks.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from notebooks
    where notebooks.id = notebook_sources.notebook_id
    and notebooks.owner_id = auth.uid()
  ));

-- Messages: same pattern.
create policy "Users manage messages in their own notebooks"
  on notebook_messages for all
  using (exists (
    select 1 from notebooks
    where notebooks.id = notebook_messages.notebook_id
    and notebooks.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from notebooks
    where notebooks.id = notebook_messages.notebook_id
    and notebooks.owner_id = auth.uid()
  ));

-- Notes: same pattern.
create policy "Users manage notes in their own notebooks"
  on notebook_notes for all
  using (exists (
    select 1 from notebooks
    where notebooks.id = notebook_notes.notebook_id
    and notebooks.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from notebooks
    where notebooks.id = notebook_notes.notebook_id
    and notebooks.owner_id = auth.uid()
  ));

-- NOTE: base64_data stores small/medium files inline for simplicity in this
-- first version. For larger PDFs, switch to Supabase Storage (a `source-files`
-- bucket) and store a storage path instead — ask me and I'll wire that up.
