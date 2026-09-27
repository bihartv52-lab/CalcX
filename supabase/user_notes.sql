-- User Notes (Instagram-style notes with RiTune music & local audio attachment)
begin;

create table if not exists public.user_notes (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    content text not null,
    song_title text,
    song_artist text,
    song_artwork text,
    song_url text,
    is_local_song boolean not null default false,
    audience text not null default 'mutual' check (audience in ('mutual', 'close_friends', 'selected_friends', 'everyone')),
    mentioned_user_id uuid references public.profiles(id) on delete set null,
    mentioned_username text,
    mentioned_display_name text,
    mentioned_avatar_url text,
    allowed_user_ids text[] default '{}',
    created_at timestamptz not null default now(),
    expires_at timestamptz not null default (now() + interval '24 hours'),
    constraint one_active_note_per_user unique (user_id)
);

-- Backward-compatible column additions for existing tables
alter table public.user_notes add column if not exists mentioned_user_id uuid references public.profiles(id) on delete set null;
alter table public.user_notes add column if not exists mentioned_username text;
alter table public.user_notes add column if not exists mentioned_display_name text;
alter table public.user_notes add column if not exists mentioned_avatar_url text;
alter table public.user_notes add column if not exists allowed_user_ids text[] default '{}';
alter table public.user_notes drop constraint if exists user_notes_audience_check;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'user_notes_audience_check') then
    alter table public.user_notes add constraint user_notes_audience_check check (audience in ('mutual', 'close_friends', 'selected_friends', 'everyone'));
  end if;
end;
$$;

create index if not exists idx_user_notes_user_id on public.user_notes(user_id);
create index if not exists idx_user_notes_expires_at on public.user_notes(expires_at);
create index if not exists idx_user_notes_mentioned on public.user_notes(mentioned_user_id);

-- Close Friends table for private notes audience
create table if not exists public.close_friends (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    friend_id uuid not null references public.profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    constraint unique_user_close_friend unique (user_id, friend_id)
);

create index if not exists idx_close_friends_user on public.close_friends(user_id);

alter table public.user_notes enable row level security;
alter table public.close_friends enable row level security;

-- Policies for user_notes
drop policy if exists "Notes are readable by all authenticated users" on public.user_notes;
create policy "Notes are readable by all authenticated users"
    on public.user_notes for select
    to authenticated, anon
    using (expires_at > now());

drop policy if exists "Users can manage their own note" on public.user_notes;
create policy "Users can manage their own note"
    on public.user_notes for all
    to authenticated, anon
    using (true)
    with check (true);

-- Policies for close_friends
drop policy if exists "Users can manage their close friends" on public.close_friends;
create policy "Users can manage their close friends"
    on public.close_friends for all
    to authenticated, anon
    using (true)
    with check (true);

-- Add to Realtime publication
alter table public.user_notes replica identity full;
do $$
begin
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'user_notes'
    ) then
        alter publication supabase_realtime add table public.user_notes;
    end if;
end;
$$;

commit;
