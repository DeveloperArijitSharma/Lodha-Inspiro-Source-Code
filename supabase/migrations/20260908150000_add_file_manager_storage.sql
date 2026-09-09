create table if not exists public.file_manager_files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete cascade,
  name text not null,
  storage_path text not null unique,
  extension text not null,
  mime_type text not null default 'application/octet-stream',
  size_bytes bigint not null default 0,
  category text not null default 'other' check (category in ('school_work','personal','ai_work','notebook_notes','documents','images','other')),
  visibility text not null default 'personal' check (visibility in ('personal','school')),
  ai_supported boolean not null default false,
  content_text text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.file_manager_files enable row level security;

create index if not exists file_manager_files_owner_idx on public.file_manager_files(owner_id, created_at desc);
create index if not exists file_manager_files_category_idx on public.file_manager_files(category, created_at desc);

create policy "file_manager_select_own_or_school"
on public.file_manager_files for select to authenticated
using (visibility = 'school' or owner_id = auth.uid());

create policy "file_manager_insert_own"
on public.file_manager_files for insert to authenticated
with check (
  owner_id = auth.uid()
  and (visibility = 'personal' or coalesce((auth.jwt() -> 'user_metadata' ->> 'role'), '') = 'teacher')
);

create policy "file_manager_update_own_or_teacher_school"
on public.file_manager_files for update to authenticated
using (owner_id = auth.uid() or (visibility = 'school' and coalesce((auth.jwt() -> 'user_metadata' ->> 'role'), '') = 'teacher'))
with check (owner_id = auth.uid() or (visibility = 'school' and coalesce((auth.jwt() -> 'user_metadata' ->> 'role'), '') = 'teacher'));

create policy "file_manager_delete_own_or_teacher_school"
on public.file_manager_files for delete to authenticated
using (owner_id = auth.uid() or (visibility = 'school' and coalesce((auth.jwt() -> 'user_metadata' ->> 'role'), '') = 'teacher'));

insert into storage.buckets (id, name, public)
values ('file-manager', 'file-manager', false)
on conflict (id) do nothing;

create policy "file_manager_storage_select"
on storage.objects for select to authenticated
using (
  bucket_id = 'file-manager'
  and (name like 'school/%' or (storage.foldername(name))[1] = auth.uid()::text)
);

create policy "file_manager_storage_insert_own_or_teacher_school"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'file-manager'
  and ((storage.foldername(name))[1] = auth.uid()::text
    or ((storage.foldername(name))[1] = 'school' and coalesce((auth.jwt() -> 'user_metadata' ->> 'role'), '') = 'teacher'))
);

create policy "file_manager_storage_update_own_or_teacher_school"
on storage.objects for update to authenticated
using (
  bucket_id = 'file-manager'
  and ((storage.foldername(name))[1] = auth.uid()::text
    or ((storage.foldername(name))[1] = 'school' and coalesce((auth.jwt() -> 'user_metadata' ->> 'role'), '') = 'teacher'))
)
with check (
  bucket_id = 'file-manager'
  and ((storage.foldername(name))[1] = auth.uid()::text
    or ((storage.foldername(name))[1] = 'school' and coalesce((auth.jwt() -> 'user_metadata' ->> 'role'), '') = 'teacher'))
);

create policy "file_manager_storage_delete_own_or_teacher_school"
on storage.objects for delete to authenticated
using (
  bucket_id = 'file-manager'
  and ((storage.foldername(name))[1] = auth.uid()::text
    or ((storage.foldername(name))[1] = 'school' and coalesce((auth.jwt() -> 'user_metadata' ->> 'role'), '') = 'teacher'))
);

create or replace function public.set_file_manager_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists file_manager_files_updated_at on public.file_manager_files;
create trigger file_manager_files_updated_at
before update on public.file_manager_files
for each row execute function public.set_file_manager_updated_at();
