-- ==========================================================
-- COMPLETE UNIFIED DATABASE SCHEMA FOR CALCX (WITH GAMES & CREDITS)
-- Paste this script into your Supabase SQL Editor
-- ==========================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing views or tables to ensure clean compilation if re-run
DROP VIEW IF EXISTS public.room_members CASCADE;

-- ==========================================================
-- 1. PROFILES TABLE (Disguised Social Core)
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL CHECK (char_length(username) between 3 and 24),
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  is_online BOOLEAN NOT NULL DEFAULT false,
  last_seen_at TIMESTAMPTZ DEFAULT NOW(),
  fcm_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Credits System Integration (patch v3)
  credits INTEGER DEFAULT 100 CHECK (credits >= 0)
);

CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_display_name ON public.profiles(display_name);

-- ==========================================================
-- 2. FRIENDS & RELATIONS
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.friend_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(sender_id, receiver_id)
);

CREATE TABLE IF NOT EXISTS public.friends (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  friend_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friends_user ON public.friends(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_friend ON public.friends(friend_id);

-- ==========================================================
-- 3. MESSAGES & PRIVATE CHATS
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE, -- Nullable for room messages
  room_id UUID, -- Nullable for direct messages
  content TEXT,
  message_type TEXT DEFAULT 'text', -- 'text', 'image', 'video', 'audio', 'voice', 'system', 'kick', 'mute'
  media_url TEXT,
  media_thumbnail TEXT,
  reply_to UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  edited BOOLEAN DEFAULT FALSE,
  edited_at TIMESTAMPTZ,
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_room ON public.messages(room_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON public.messages(created_at DESC);

-- ==========================================================
-- 4. MESSAGE INTERACTIONS & READ STATUS
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(message_id, user_id, emoji)
);

CREATE TABLE IF NOT EXISTS public.message_reads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(message_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.typing_indicators (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  chat_with UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  room_id UUID,
  is_typing BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, chat_with, room_id)
);

-- ==========================================================
-- 5. PARTY ROOMS / GAME LOBBIES
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL CHECK (char_length(name) between 2 and 80),
  description TEXT,
  room_type TEXT DEFAULT 'party', -- 'party', 'game', 'watch', 'music'
  host_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  visibility TEXT DEFAULT 'private' CHECK (visibility IN ('public', 'private')),
  invite_code TEXT UNIQUE,
  max_participants INTEGER DEFAULT 50,
  media_url TEXT,
  playback_state JSONB DEFAULT '{"position_ms":0,"is_playing":false}'::JSONB,
  livekit_room TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.room_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role TEXT DEFAULT 'member', -- 'host', 'moderator', 'member'
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(room_id, user_id)
);

-- View representing room_members (aliases room_participants for backward compatibility)
CREATE OR REPLACE VIEW public.room_members AS 
SELECT room_id, user_id, role, joined_at FROM public.room_participants;

CREATE INDEX IF NOT EXISTS idx_rooms_host ON public.rooms(host_id);
CREATE INDEX IF NOT EXISTS idx_rooms_invite ON public.rooms(invite_code);
CREATE INDEX IF NOT EXISTS idx_room_participants_room ON public.room_participants(room_id);

-- ==========================================================
-- 6. VOICE / VIDEO CALLS logs
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.calls (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  caller_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
  call_type TEXT NOT NULL, -- 'audio', 'video', 'screen'
  status TEXT DEFAULT 'ringing', -- 'ringing', 'ongoing', 'ended', 'missed', 'rejected'
  room_name TEXT, -- Livekit room identifier
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  duration INTEGER DEFAULT 0
);

-- ==========================================================
-- 7. NOTIFICATIONS
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL, -- 'friend_request', 'message', 'call', 'room_invite'
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(user_id, read) WHERE read = FALSE;

-- ==========================================================
-- 8. GAME SESSIONS & CREDITS (GAMES PATCH)
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE NOT NULL,
  game_type TEXT NOT NULL, -- 'ludo', 'skribbl', 'xo'
  game_state JSONB NOT NULL DEFAULT '{}'::jsonb, -- Synced game coordinates, tokens
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'finished')),
  winner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(room_id, status)
);

CREATE TABLE IF NOT EXISTS public.credit_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  amount INTEGER NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================================
-- 8b. APP VERSION & CONFIGURATION
-- ==========================================================
CREATE TABLE IF NOT EXISTS public.app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL
);

-- Seed default version configuration (Local Version Code is 1)
INSERT INTO public.app_config (key, value)
VALUES (
  'version_config', 
  '{"latest_version_code": 1, "latest_version_name": "1.0.0", "download_url": "https://calcx-download.vercel.app"}'::jsonb
)
ON CONFLICT (key) DO NOTHING;

-- Enable RLS for Game & Credit Tables
ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Game sessions are visible to all users" 
  ON public.game_sessions FOR SELECT USING (true);

CREATE POLICY "Game sessions can be created by all" 
  ON public.game_sessions FOR INSERT WITH CHECK (true);

CREATE POLICY "Game sessions can be updated by all" 
  ON public.game_sessions FOR UPDATE USING (true);

CREATE POLICY "Users can read own transactions" 
  ON public.credit_transactions FOR SELECT 
  TO authenticated 
  USING (auth.uid() = user_id);

-- ==========================================================
-- 9. SAFE STORED PROCEDURES (Wagers, Bets and payouts)
-- ==========================================================

-- place_bet: safe atomic credit deduction for joining a lobby
CREATE OR REPLACE FUNCTION place_bet(player_id UUID, bet_amount INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
  current_balance INTEGER;
BEGIN
  -- Row lock profile to prevent race conditions / duplicate spends
  SELECT credits INTO current_balance 
  FROM public.profiles 
  WHERE id = player_id 
  FOR UPDATE;
  
  IF current_balance >= bet_amount THEN
    UPDATE public.profiles 
    SET credits = credits - bet_amount 
    WHERE id = player_id;
    
    INSERT INTO public.credit_transactions (user_id, amount, description)
    VALUES (player_id, -bet_amount, 'Bet Wager Placed');
    
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- reward_winner: safe reward credit additions
CREATE OR REPLACE FUNCTION reward_winner(player_id UUID, reward_amount INTEGER, game_name TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles 
  SET credits = credits + reward_amount 
  WHERE id = player_id;
  
  INSERT INTO public.credit_transactions (user_id, amount, description)
  VALUES (player_id, reward_amount, CONCAT('Winner Payout: ', game_name));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================================
-- 10. ROW LEVEL SECURITY (RLS) & TRIGGERS FOR CORE TABLES
-- ==========================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view their friend requests" ON public.friend_requests FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "Users can send friend requests" ON public.friend_requests FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Users can update received requests" ON public.friend_requests FOR UPDATE USING (auth.uid() = receiver_id);

CREATE POLICY "Users can view their friends" ON public.friends FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "Users can add friends" ON public.friends FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove friends" ON public.friends FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view their messages" ON public.messages FOR SELECT USING (
  auth.uid() = sender_id OR auth.uid() = receiver_id OR EXISTS (
    SELECT 1 FROM public.room_participants WHERE room_id = messages.room_id AND user_id = auth.uid()
  )
);
CREATE POLICY "Users can send messages" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Users can update own messages" ON public.messages FOR UPDATE USING (auth.uid() = sender_id);

CREATE POLICY "Users can view reactions" ON public.message_reactions FOR SELECT USING (true);
CREATE POLICY "Users can add reactions" ON public.message_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove own reactions" ON public.message_reactions FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view read receipts" ON public.message_reads FOR SELECT USING (true);
CREATE POLICY "Users can mark messages as read" ON public.message_reads FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view typing indicators" ON public.typing_indicators FOR SELECT USING (true);
CREATE POLICY "Users can update own typing status" ON public.typing_indicators FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view public rooms" ON public.rooms FOR SELECT USING (visibility = 'public' OR host_id = auth.uid() OR EXISTS (
  SELECT 1 FROM public.room_participants WHERE room_id = rooms.id AND user_id = auth.uid()
));
CREATE POLICY "Users can create rooms" ON public.rooms FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "Hosts can update their rooms" ON public.rooms FOR UPDATE USING (auth.uid() = host_id);
CREATE POLICY "Hosts can delete their rooms" ON public.rooms FOR DELETE USING (auth.uid() = host_id);

CREATE POLICY "Users can view room participants" ON public.room_participants FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Users can join rooms" ON public.room_participants FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can leave rooms" ON public.room_participants FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view their calls" ON public.calls FOR SELECT USING (auth.uid() = caller_id OR auth.uid() = receiver_id);
CREATE POLICY "Users can initiate calls" ON public.calls FOR INSERT WITH CHECK (auth.uid() = caller_id);
CREATE POLICY "Users can update their calls" ON public.calls FOR UPDATE USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- Timestamps update Column helper
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_friend_requests_updated_at BEFORE UPDATE ON public.friend_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_rooms_updated_at BEFORE UPDATE ON public.rooms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- User signup trigger (Auto-inserts auth.users metadata into public.profiles)
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name, credits)
  VALUES (
    new.id, 
    split_part(new.email, '@', 1), 
    split_part(new.email, '@', 1),
    100 -- Default Credits set to 100
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ==========================================================
-- 11. REAL-TIME PUBLICATION CONFIG
-- ==========================================================
DO $$
DECLARE
    tbl text;
    tables_to_add text[] := ARRAY[
        'messages', 
        'message_reactions', 
        'message_reads', 
        'typing_indicators', 
        'room_participants', 
        'rooms', 
        'calls', 
        'notifications', 
        'profiles',
        'game_sessions',
        'credit_transactions',
        'app_config'
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
