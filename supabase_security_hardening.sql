-- Lodha Inspiro backend security hardening
-- Target Supabase project: Arijitsharmawebs's Project
-- These definitions are safe to re-run and preserve the existing app behavior.

create or replace function public.check_email_exists(lookup_email text)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  return exists (select 1 from auth.users where email = lookup_email);
end;
$$;

create or replace function public.prevent_message_owner_changes()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.sender_id <> old.sender_id or new.chat_id <> old.chat_id then
    raise exception 'message ownership fields cannot be changed';
  end if;
  return new;
end;
$$;
