alter table messages
  add column if not exists reply_to_message_id uuid references messages(id) on delete set null,
  add column if not exists reactions jsonb not null default '{}'::jsonb,
  add column if not exists edited_at timestamptz,
  add column if not exists deleted_at timestamptz;

create index if not exists messages_reply_to_message_id_idx
  on messages(reply_to_message_id);

create index if not exists messages_chat_created_at_idx
  on messages(chat_id, created_at);

create or replace function prevent_message_owner_changes()
returns trigger
language plpgsql
as $$
begin
  if new.sender_id <> old.sender_id or new.chat_id <> old.chat_id then
    raise exception 'message ownership fields cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists messages_protect_owner_fields on messages;
create trigger messages_protect_owner_fields
before update on messages
for each row execute function prevent_message_owner_changes();
