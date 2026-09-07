-- Lodha Inspiro Notebooks schema
-- Safe to run more than once. Notebook data is private to authenticated owners.

create extension if not exists "uuid-ossp";

create table if not exists public.notebooks (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled notebook',
  summary text,
  created_at timestamptz not null default now()
);

create table if not exists public.notebook_sources (
  id uuid primary key default uuid_generate_v4(),
  notebook_id uuid not null references public.notebooks(id) on delete cascade,
  title text not null,
  mime_type text not null default 'text/plain',
  text_content text,
  base64_data text,
  created_at timestamptz not null default now()
);

create table if not exists public.notebook_messages (
  id uuid primary key default uuid_generate_v4(),
  notebook_id uuid not null references public.notebooks(id) on delete cascade,
  is_user boolean not null default true,
  text text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.notebook_notes (
  id uuid primary key default uuid_generate_v4(),
  notebook_id uuid not null references public.notebooks(id) on delete cascade,
  title text not null default 'Untitled note',
  content text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notebooks enable row level security;
alter table public.notebook_sources enable row level security;
alter table public.notebook_messages enable row level security;
alter table public.notebook_notes enable row level security;

-- Re-runnable policy definitions. Only signed-in users receive table access.
drop policy if exists "Users manage their own notebooks" on public.notebooks;
drop policy if exists "Users manage sources in their own notebooks" on public.notebook_sources;
drop policy if exists "Users manage messages in their own notebooks" on public.notebook_messages;
drop policy if exists "Users manage notes in their own notebooks" on public.notebook_notes;

create policy "Users manage their own notebooks"
  on public.notebooks
  for all
  to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

create policy "Users manage sources in their own notebooks"
  on public.notebook_sources
  for all
  to authenticated
  using (exists (
    select 1
    from public.notebooks
    where notebooks.id = notebook_sources.notebook_id
      and notebooks.owner_id = (select auth.uid())
  ))
  with check (exists (
    select 1
    from public.notebooks
    where notebooks.id = notebook_sources.notebook_id
      and notebooks.owner_id = (select auth.uid())
  ));

create policy "Users manage messages in their own notebooks"
  on public.notebook_messages
  for all
  to authenticated
  using (exists (
    select 1
    from public.notebooks
    where notebooks.id = notebook_messages.notebook_id
      and notebooks.owner_id = (select auth.uid())
  ))
  with check (exists (
    select 1
    from public.notebooks
    where notebooks.id = notebook_messages.notebook_id
      and notebooks.owner_id = (select auth.uid())
  ));

create policy "Users manage notes in their own notebooks"
  on public.notebook_notes
  for all
  to authenticated
  using (exists (
    select 1
    from public.notebooks
    where notebooks.id = notebook_notes.notebook_id
      and notebooks.owner_id = (select auth.uid())
  ))
  with check (exists (
    select 1
    from public.notebooks
    where notebooks.id = notebook_notes.notebook_id
      and notebooks.owner_id = (select auth.uid())
  ));

revoke all on public.notebooks, public.notebook_sources, public.notebook_messages, public.notebook_notes from anon;
grant select, insert, update, delete on public.notebooks, public.notebook_sources, public.notebook_messages, public.notebook_notes to authenticated;

create index if not exists notebooks_owner_created_idx
  on public.notebooks(owner_id, created_at desc);

create index if not exists notebook_sources_notebook_created_idx
  on public.notebook_sources(notebook_id, created_at);

create index if not exists notebook_messages_notebook_created_idx
  on public.notebook_messages(notebook_id, created_at);

create index if not exists notebook_notes_notebook_updated_idx
  on public.notebook_notes(notebook_id, updated_at desc);

-- Binary sources are kept inline for the current prototype. Move large files
-- to Supabase Storage before allowing very large uploads.
