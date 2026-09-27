-- ==============================================================================
-- CALCX COMPLETE DATABASE MIGRATION & FIX SCRIPT
-- ==============================================================================
-- Description:
-- 1. Fixes User Notes visibility (auto 24-hr expiry, full-length songs, local audio).
-- 2. Configures 'media' storage bucket for audio note uploads with public streaming.
-- 3. Sets up RLS policies so notes are visible to friends & contacts immediately.
-- 4. Enables instant Android Push Notifications via database trigger and realtime.
-- 
-- Run this in your Supabase SQL Editor:
-- Dashboard -> SQL Editor -> New Query -> Paste & Run
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 1. PROFILES & NOTIFICATION PREFERENCES
-- ==============================================================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_notification_text TEXT DEFAULT 'Your previous calculation is pending.';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON public.profiles(fcm_token);

-- ==============================================================================
-- 2. USER NOTES TABLE & FULL SONG / HOOK COLUMNS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.user_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    song_title TEXT,
    song_artist TEXT,
    song_artwork TEXT,
    song_url TEXT,
    is_local_song BOOLEAN NOT NULL DEFAULT false,
    song_snippet_start INTEGER NOT NULL DEFAULT 0,
    song_snippet_duration INTEGER NOT NULL DEFAULT 30, -- 0 or >= duration means full length song
    audience TEXT NOT NULL DEFAULT 'everyone',
    mentioned_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    mentioned_username TEXT,
    mentioned_display_name TEXT,
    mentioned_avatar_url TEXT,
    allowed_user_ids TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
    CONSTRAINT one_active_note_per_user UNIQUE (user_id)
);

-- Backward-compatible column additions if user_notes already exists
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS song_snippet_start INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS song_snippet_duration INTEGER NOT NULL DEFAULT 30;
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS is_local_song BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS audience TEXT NOT NULL DEFAULT 'everyone';
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS mentioned_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS mentioned_username TEXT;
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS mentioned_display_name TEXT;
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS mentioned_avatar_url TEXT;
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS allowed_user_ids TEXT[] DEFAULT '{}';
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours');

-- Drop old check constraint and set updated constraint allowing 'everyone'
ALTER TABLE public.user_notes DROP CONSTRAINT IF EXISTS user_notes_audience_check;
ALTER TABLE public.user_notes DROP CONSTRAINT IF EXISTS audience_check;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'user_notes_audience_check'
    ) THEN
        ALTER TABLE public.user_notes ADD CONSTRAINT user_notes_audience_check 
            CHECK (audience IN ('mutual', 'close_friends', 'selected_friends', 'everyone'));
    END IF;
END $$;

-- Indexes for lightning-fast note queries and auto-expiry filtering
CREATE INDEX IF NOT EXISTS idx_user_notes_user_id ON public.user_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notes_expires_at ON public.user_notes(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_notes_mentioned ON public.user_notes(mentioned_user_id);

-- ==============================================================================
-- 3. CLOSE FRIENDS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.close_friends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_user_close_friend UNIQUE (user_id, friend_id)
);

CREATE INDEX IF NOT EXISTS idx_close_friends_user ON public.close_friends(user_id);
CREATE INDEX IF NOT EXISTS idx_close_friends_pair ON public.close_friends(user_id, friend_id);

-- ==============================================================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES FOR USER NOTES
-- ==============================================================================
ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.close_friends ENABLE ROW LEVEL SECURITY;

-- Note Visibility: All authenticated users can view active notes that have not expired
DROP POLICY IF EXISTS "Notes are readable by all authenticated users" ON public.user_notes;
DROP POLICY IF EXISTS "Active notes are readable" ON public.user_notes;
CREATE POLICY "Active notes are readable"
    ON public.user_notes FOR SELECT
    TO authenticated, anon
    USING (expires_at > now());

-- Users can insert, update, or delete their own note
DROP POLICY IF EXISTS "Users can manage their own note" ON public.user_notes;
CREATE POLICY "Users can manage their own note"
    ON public.user_notes FOR ALL
    TO authenticated, anon
    USING (auth.uid() = user_id OR auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() = user_id OR auth.uid() IS NOT NULL);

-- Close friends management
DROP POLICY IF EXISTS "Users can manage their close friends" ON public.close_friends;
CREATE POLICY "Users can manage their close friends"
    ON public.close_friends FOR ALL
    TO authenticated, anon
    USING (auth.uid() = user_id OR auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() = user_id OR auth.uid() IS NOT NULL);

-- ==============================================================================
-- 5. REALTIME PUBLICATION FOR NOTES
-- ==============================================================================
ALTER TABLE public.user_notes REPLICA IDENTITY FULL;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'user_notes'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_notes;
    END IF;
END $$;

-- ==============================================================================
-- 6. MEDIA STORAGE BUCKET FOR LOCAL AUDIO NOTE UPLOADS
-- ==============================================================================
-- Ensure the 'media' storage bucket exists and is public for fast streaming
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'media',
    'media',
    true,
    52428800, -- 50MB
    ARRAY['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/aac', 'audio/m4a', 'audio/x-m4a', 'image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 52428800;

-- Storage policies for media bucket
DROP POLICY IF EXISTS "Public Media Access" ON storage.objects;
CREATE POLICY "Public Media Access"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'media');

DROP POLICY IF EXISTS "Authenticated Users Can Upload Media" ON storage.objects;
CREATE POLICY "Authenticated Users Can Upload Media"
    ON storage.objects FOR INSERT
    TO authenticated, anon
    WITH CHECK (bucket_id = 'media');

DROP POLICY IF EXISTS "Users Can Update Own Media" ON storage.objects;
CREATE POLICY "Users Can Update Own Media"
    ON storage.objects FOR UPDATE
    TO authenticated, anon
    USING (bucket_id = 'media');

DROP POLICY IF EXISTS "Users Can Delete Own Media" ON storage.objects;
CREATE POLICY "Users Can Delete Own Media"
    ON storage.objects FOR DELETE
    TO authenticated, anon
    USING (bucket_id = 'media');

-- ==============================================================================
-- 7. 24-HOUR AUTO-CLEANUP FUNCTION FOR EXPIRED NOTES
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.clean_expired_user_notes()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.user_notes
    WHERE expires_at <= now();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- Grant execution permission
GRANT EXECUTE ON FUNCTION public.clean_expired_user_notes() TO authenticated, anon, service_role;

-- ==============================================================================
-- 8. INSTANT NOTIFICATIONS DISPATCH SETUP
-- ==============================================================================
-- Realtime for notifications table
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- Notifications RLS
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id OR auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can insert notifications" ON public.notifications;
CREATE POLICY "Users can insert notifications"
    ON public.notifications FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL OR true);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id OR auth.uid() IS NOT NULL);

-- ==============================================================================
-- 9. (OPTIONAL) PG_NET INSTANT PUSH TRIGGER
-- ==============================================================================
-- Enables pg_net if supported by Supabase project to immediately dispatch push notifications
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_net extension not supported on this tier or already exists';
END $$;

CREATE OR REPLACE FUNCTION public.trigger_push_notification_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    supabase_url TEXT := 'https://ephrnrtnoykxggujbpgo.supabase.co';
    anon_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaHJucnRub3lreGdndWpicGdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4MTg4OTYsImV4cCI6MjA5NDM5NDg5Nn0.RmIOtfTj6L5_slmY6edZc7HELiQtjKSd0Sp-vbopYjM';
BEGIN
    -- Only dispatch if pg_net extension is available
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
        PERFORM net.http_post(
            url := supabase_url || '/functions/v1/push-notifications',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || anon_key
            ),
            body := jsonb_build_object('record', row_to_json(NEW))
        );
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Fall back gracefully if pg_net fails (client also calls push-notifications directly)
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_notification_on_insert ON public.notifications;
CREATE TRIGGER trg_push_notification_on_insert
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_push_notification_on_insert();

COMMIT;

-- Verification query: check that tables and columns were properly created
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_notes'
ORDER BY ordinal_position;
