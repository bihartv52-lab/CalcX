-- CalcX Supabase schema. Run this in the Supabase SQL editor.

create extension if not exists "pgcrypto";

create type friendship_status as enum ('pending', 'accepted', 'blocked');
create type chat_type as enum ('direct', 'group');
create type message_type as enum ('text', 'image', 'video', 'audio', 'voice', 'system');
create type room_visibility as enum ('public', 'private');
create type room_role as enum ('host', 'moderator', 'member');
create type call_type as enum ('audio', 'video', 'screen');
create type call_status as enum ('missed', 'completed', 'declined');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 24),
  display_name text not null,
  avatar_url text,
  bio text,
  is_online boolean not null default false,
  last_seen_at timestamptz,
  fcm_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create table public.chats (
  id uuid primary key default gen_random_uuid(),
  type chat_type not null default 'direct',
  title text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.chat_members (
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  unread_count integer not null default 0,
  last_read_message_id uuid,
  joined_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

create table public.media (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text unique not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes <= 52428800),
  view_once boolean not null default false,
  viewed_by uuid[] not null default '{}',
  expires_at timestamptz not null default (now() + interval '24 hours'),
  created_at timestamptz not null default now()
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message_type message_type not null default 'text',
  body text,
  media_id uuid references public.media(id) on delete set null,
  reply_to_id uuid references public.messages(id) on delete set null,
  reactions jsonb not null default '{}'::jsonb,
  seen_by uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  edited_at timestamptz
);

create table public.typing_events (
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  is_typing boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 80),
  host_id uuid not null references public.profiles(id) on delete cascade,
  visibility room_visibility not null default 'private',
  invite_code text unique default encode(gen_random_bytes(6), 'hex'),
  media_url text,
  playback_state jsonb not null default '{"position_ms":0,"is_playing":false}'::jsonb,
  livekit_room text unique default encode(gen_random_bytes(10), 'hex'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role room_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table public.calls (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  peer_id uuid references public.profiles(id) on delete set null,
  room_id uuid references public.rooms(id) on delete set null,
  call_type call_type not null,
  status call_status not null,
  duration_seconds integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null default 'CalcX',
  body text not null default 'Your previous calculation is pending.',
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index profiles_username_idx on public.profiles using btree (lower(username));
create index friendships_lookup_idx on public.friendships (requester_id, addressee_id, status);
create index chat_members_user_idx on public.chat_members (user_id, chat_id);
create index messages_chat_created_idx on public.messages (chat_id, created_at desc);
create index media_expiry_idx on public.media (expires_at);
create index rooms_visibility_idx on public.rooms (visibility, created_at desc);
create index room_members_user_idx on public.room_members (user_id, room_id);
create index calls_owner_created_idx on public.calls (owner_id, created_at desc);
create index notifications_user_created_idx on public.notifications (user_id, created_at desc);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'media',
  'media',
  false,
  52428800,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'video/mp4',
    'video/quicktime',
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'audio/webm'
  ]
) on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;
alter table public.typing_events enable row level security;
alter table public.media enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.calls enable row level security;
alter table public.notifications enable row level security;

create policy "users upload own media objects"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "users read own media objects"
on storage.objects for select
to authenticated
using (
  bucket_id = 'media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "users delete own media objects"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "profiles are visible to signed in users"
on public.profiles for select
to authenticated
using (true);

create policy "users update own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "users insert own profile"
on public.profiles for insert
to authenticated
with check (auth.uid() = id);

create policy "friendships visible to participants"
on public.friendships for select
to authenticated
using (auth.uid() in (requester_id, addressee_id));

create policy "users create friend requests"
on public.friendships for insert
to authenticated
with check (auth.uid() = requester_id);

create policy "participants update friendships"
on public.friendships for update
to authenticated
using (auth.uid() in (requester_id, addressee_id));

create policy "members see their chat memberships"
on public.chat_members for select
to authenticated
using (auth.uid() = user_id);

create policy "chat members see chats"
on public.chats for select
to authenticated
using (
  exists (
    select 1 from public.chat_members cm
    where cm.chat_id = id and cm.user_id = auth.uid()
  )
);

create policy "users can create chats"
on public.chats for insert
to authenticated
with check (auth.uid() = created_by);

create policy "chat members see messages"
on public.messages for select
to authenticated
using (
  exists (
    select 1 from public.chat_members cm
    where cm.chat_id = messages.chat_id and cm.user_id = auth.uid()
  )
);

create policy "chat members send messages"
on public.messages for insert
to authenticated
with check (
  auth.uid() = sender_id and exists (
    select 1 from public.chat_members cm
    where cm.chat_id = messages.chat_id and cm.user_id = auth.uid()
  )
);

create policy "typing visible to chat members"
on public.typing_events for select
to authenticated
using (
  exists (
    select 1 from public.chat_members cm
    where cm.chat_id = typing_events.chat_id and cm.user_id = auth.uid()
  )
);

create policy "typing owned by user"
on public.typing_events for insert
to authenticated
with check (auth.uid() = user_id);

create policy "media visible to owner or message chat members"
on public.media for select
to authenticated
using (
  auth.uid() = owner_id or exists (
    select 1
    from public.messages m
    join public.chat_members cm on cm.chat_id = m.chat_id
    where m.media_id = media.id and cm.user_id = auth.uid()
  )
);

create policy "users insert own media"
on public.media for insert
to authenticated
with check (auth.uid() = owner_id);

create policy "public rooms visible"
on public.rooms for select
to authenticated
using (
  visibility = 'public' or exists (
    select 1 from public.room_members rm
    where rm.room_id = id and rm.user_id = auth.uid()
  )
);

create policy "users create hosted rooms"
on public.rooms for insert
to authenticated
with check (auth.uid() = host_id);

create policy "hosts update rooms"
on public.rooms for update
to authenticated
using (auth.uid() = host_id);

create policy "room members visible to members"
on public.room_members for select
to authenticated
using (
  exists (
    select 1 from public.room_members mine
    where mine.room_id = room_members.room_id and mine.user_id = auth.uid()
  )
);

create policy "users join rooms as self"
on public.room_members for insert
to authenticated
with check (auth.uid() = user_id);

create policy "users see own calls"
on public.calls for select
to authenticated
using (auth.uid() = owner_id);

create policy "users create own call records"
on public.calls for insert
to authenticated
with check (auth.uid() = owner_id);

create policy "users see own notifications"
on public.notifications for select
to authenticated
using (auth.uid() = user_id);

-- Enable realtime subscriptions safely
DO $$
DECLARE
    tbl text;
    tables_to_add text[] := ARRAY[
        'profiles', 
        'friendships', 
        'chat_members', 
        'messages', 
        'typing_events', 
        'rooms', 
        'room_members', 
        'calls', 
        'notifications'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables_to_add LOOP
        IF EXISTS (
            SELECT 1 FROM pg_class WHERE relname = tbl AND relnamespace = 'public'::regnamespace
        ) AND NOT EXISTS (
            SELECT 1 FROM pg_publication_rel pr 
            JOIN pg_publication p ON p.oid = pr.prpubid 
            JOIN pg_class c ON c.oid = pr.prrelid 
            WHERE p.pubname = 'supabase_realtime' AND c.relname = tbl
        ) THEN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
        END IF;
    END LOOP;
END $$;
