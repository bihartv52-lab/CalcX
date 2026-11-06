-- ============================================================
-- CALCX INSTAGRAM-GRADE SECURITY & BLUE TICK UPDATE
-- Run this script in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/_/sql
-- ============================================================

-- ============================================================
-- 1. FORCE LOGOUT EVERYONE & SESSION RESET
-- Invalidate all existing auth sessions across all devices
-- ============================================================
DELETE FROM auth.sessions;
DELETE FROM auth.refresh_tokens;

-- Add security tracking columns to public.profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS force_logout_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS active_chat_device_id TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS active_chat_device_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS active_chat_updated_at TIMESTAMPTZ DEFAULT NOW();

-- Update force_logout_at to current timestamp so any legacy sessions are rejected
UPDATE public.profiles SET force_logout_at = NOW();

-- ============================================================
-- 2. INSTAGRAM-STYLE LOGGED-IN DEVICES ("WHERE YOU'RE LOGGED IN")
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  device_id TEXT NOT NULL,
  device_name TEXT NOT NULL,
  device_os TEXT NOT NULL,
  ip_address TEXT,
  is_active_chat BOOLEAN DEFAULT FALSE,
  last_active TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_device_id ON public.user_devices(device_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_last_active ON public.user_devices(last_active DESC);

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own devices" ON public.user_devices;
CREATE POLICY "Users can view own devices" ON public.user_devices
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own devices" ON public.user_devices;
CREATE POLICY "Users can insert own devices" ON public.user_devices
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own devices" ON public.user_devices;
CREATE POLICY "Users can update own devices" ON public.user_devices
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own devices" ON public.user_devices;
CREATE POLICY "Users can delete own devices" ON public.user_devices
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- ============================================================
-- 3. FIX BLUE TICK ISSUE: DIRECT IS_READ COLUMN & RLS FIX
-- ============================================================
-- Ensure is_read and read_at exist directly on public.messages
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_messages_unread ON public.messages(receiver_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_messages_direct_pair ON public.messages(sender_id, receiver_id, created_at DESC);

-- Allow receivers to update is_read and read_at on messages sent to them
DROP POLICY IF EXISTS "Receivers can mark messages as read" ON public.messages;
CREATE POLICY "Receivers can mark messages as read" ON public.messages
  FOR UPDATE TO authenticated
  USING (auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = receiver_id);

-- Fix message_reads table and RLS policies
CREATE TABLE IF NOT EXISTS public.message_reads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_message_reads_msg ON public.message_reads(message_id);
CREATE INDEX IF NOT EXISTS idx_message_reads_user ON public.message_reads(user_id);

ALTER TABLE public.message_reads ENABLE ROW LEVEL SECURITY;

-- CRITICAL FIX FOR BLUE TICKS:
-- Senders MUST be able to SELECT read receipts for their sent messages!
DROP POLICY IF EXISTS "Users can view read receipts" ON public.message_reads;
CREATE POLICY "Users can view read receipts" ON public.message_reads
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can mark messages as read" ON public.message_reads;
CREATE POLICY "Users can mark messages as read" ON public.message_reads
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4. REALTIME REPLICATION CONFIGURATION
-- Ensure all relevant tables broadcast events over websockets
-- ============================================================
DO $$
BEGIN
  -- Add tables to supabase_realtime publication if not already added
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'user_devices'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_devices;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'message_reads'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reads;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL; -- Ignore publication errors if already enabled
END $$;
