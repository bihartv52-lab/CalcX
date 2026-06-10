-- CalcX Supabase Database Schema
-- Run this in your Supabase SQL Editor

-- Users table (extends auth.users)
CREATE TABLE public.users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Friendships
CREATE TABLE public.friendships (
  user_id_1 UUID REFERENCES public.users(id) ON DELETE CASCADE,
  user_id_2 UUID REFERENCES public.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id_1, user_id_2)
);

-- Chats (groups or DMs)
CREATE TABLE public.chats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  is_group BOOLEAN DEFAULT FALSE,
  name TEXT, -- Nullable, used for groups
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat Members
CREATE TABLE public.chat_members (
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (chat_id, user_id)
);

-- Messages
CREATE TABLE public.messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  body TEXT,
  message_type TEXT DEFAULT 'text', -- 'text', 'image', 'video', 'audio', 'view_once'
  media_url TEXT,
  reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Typing Events (volatile table for realtime)
CREATE TABLE public.typing_events (
  chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  is_typing BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (chat_id, user_id)
);

-- Party Rooms
CREATE TABLE public.rooms (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  host_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  is_private BOOLEAN DEFAULT FALSE,
  current_media_url TEXT,
  current_playback_time NUMERIC DEFAULT 0,
  is_playing BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Room Members
CREATE TABLE public.room_members (
  room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (room_id, user_id)
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.typing_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;

-- Basic RLS Policies
CREATE POLICY "Users can view everyone" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update themselves" ON public.users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can read their own chats" ON public.chats FOR SELECT USING (
  auth.uid() IN (SELECT user_id FROM public.chat_members WHERE chat_id = id)
);

CREATE POLICY "Users can read messages in their chats" ON public.messages FOR SELECT USING (
  auth.uid() IN (SELECT user_id FROM public.chat_members WHERE chat_id = public.messages.chat_id)
);

CREATE POLICY "Users can insert messages in their chats" ON public.messages FOR INSERT WITH CHECK (
  auth.uid() IN (SELECT user_id FROM public.chat_members WHERE chat_id = public.messages.chat_id)
);

-- Enable realtime subscriptions safely
DO $$
DECLARE
    tbl text;
    tables_to_add text[] := ARRAY[
        'messages', 
        'typing_events', 
        'rooms', 
        'chat_members'
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

-- Triggers to auto-create user record on auth.users signup
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, username)
  VALUES (new.id, split_part(new.email, '@', 1));
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
