-- ==============================================================================
-- CALCX COMPLETE CONSOLIDATED DATABASE & STORAGE ALL-IN-ONE FIX
-- Copy and run this ENTIRE script in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. PROFILES TABLE ENHANCEMENTS & RLS
-- ==============================================================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS nickname TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'offline';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS credits INT DEFAULT 100;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_notification_text TEXT DEFAULT 'Your previous calculation is pending.';

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop all outdated/conflicting profiles policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "profiles are visible to signed in users" ON public.profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "users update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "users insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.profiles;

-- Re-create clean profiles policies
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- ==============================================================================
-- 3. CALLS TABLE & RLS (CALL HISTORY, MINIMIZATION & DELETION)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  caller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  call_type TEXT NOT NULL DEFAULT 'voice', -- 'voice' or 'video'
  status TEXT NOT NULL DEFAULT 'calling',  -- 'calling', 'active', 'ended', 'rejected', 'missed'
  room_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own calls" ON public.calls;
DROP POLICY IF EXISTS "Users can insert calls" ON public.calls;
DROP POLICY IF EXISTS "Users can update their calls" ON public.calls;
DROP POLICY IF EXISTS "Users can delete their calls" ON public.calls;

CREATE POLICY "Users can view their own calls"
  ON public.calls FOR SELECT
  TO authenticated
  USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can insert calls"
  ON public.calls FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = caller_id);

CREATE POLICY "Users can update their calls"
  ON public.calls FOR UPDATE
  TO authenticated
  USING (auth.uid() = caller_id OR auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = caller_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can delete their calls"
  ON public.calls FOR DELETE
  TO authenticated
  USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

-- ==============================================================================
-- 4. MESSAGES TABLE & RLS (WALLPAPER SYNC & MESSAGE MANAGEMENT)
-- ==============================================================================
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_url TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_thumbnail TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS edited BOOLEAN DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view messages" ON public.messages;
DROP POLICY IF EXISTS "Users can insert messages" ON public.messages;
DROP POLICY IF EXISTS "Users can update messages" ON public.messages;
DROP POLICY IF EXISTS "Users can delete messages" ON public.messages;
DROP POLICY IF EXISTS "messages_select_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_update_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_delete_policy" ON public.messages;

CREATE POLICY "Users can view messages"
  ON public.messages FOR SELECT
  TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id OR room_id IS NOT NULL);

CREATE POLICY "Users can insert messages"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update messages"
  ON public.messages FOR UPDATE
  TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can delete messages"
  ON public.messages FOR DELETE
  TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- ==============================================================================
-- 5. NOTIFICATIONS TABLE & REALTIME TRIGGERS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'message', 'friend_request', 'friend_request_accepted', 'room_invite', etc.
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;

CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can insert notifications"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Realtime Notification Trigger for Direct & Room Messages
CREATE OR REPLACE FUNCTION public.handle_message_notification()
RETURNS TRIGGER AS $$
DECLARE
  sender_display TEXT;
BEGIN
  -- Do not notify for system wallpaper changes
  IF NEW.message_type = 'chat_wallpaper' THEN
    RETURN NEW;
  END IF;

  -- Get sender's display name or username
  SELECT coalesce(display_name, username, 'Friend') INTO sender_display
  FROM public.profiles WHERE id = NEW.sender_id;

  IF NEW.room_id IS NULL THEN
    -- Direct message: notify receiver_id with real name & content in data payload
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.receiver_id,
      'message',
      coalesce(sender_display, 'New Message'),
      CASE 
        WHEN NEW.message_type = 'image' THEN 'Sent an image'
        WHEN NEW.message_type = 'video' THEN 'Sent a video'
        WHEN NEW.message_type = 'voice' OR NEW.message_type = 'audio' THEN 'Sent a voice message'
        ELSE coalesce(NEW.content, 'New message')
      END,
      jsonb_build_object(
        'message_id', NEW.id, 
        'sender_id', NEW.sender_id,
        'sender_name', sender_display,
        'content', NEW.content,
        'message_type', NEW.message_type
      )
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    -- Room message: notify all participants of the room (excluding sender)
    INSERT INTO public.notifications (user_id, type, title, body, data)
    SELECT 
      rp.user_id,
      'message',
      coalesce(sender_display, 'Room Message'),
      CASE 
        WHEN NEW.message_type = 'image' THEN 'Sent an image'
        WHEN NEW.message_type = 'video' THEN 'Sent a video'
        WHEN NEW.message_type = 'voice' OR NEW.message_type = 'audio' THEN 'Sent a voice message'
        ELSE coalesce(NEW.content, 'New message')
      END,
      jsonb_build_object(
        'room_id', NEW.room_id, 
        'message_id', NEW.id, 
        'sender_id', NEW.sender_id,
        'sender_name', sender_display,
        'content', NEW.content,
        'message_type', NEW.message_type
      )
    FROM public.room_participants rp
    WHERE rp.room_id = NEW.room_id AND rp.user_id != NEW.sender_id
    ON CONFLICT (id) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_created ON public.messages;
CREATE TRIGGER on_message_created
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_message_notification();

-- ==============================================================================
-- 6. STORAGE BUCKETS & RLS POLICIES (MEDIA, AVATARS, WALLPAPERS)
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true,
  52428800, -- 50MB
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp', 'video/mp4', 'video/webm', 'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/aac']
)
ON CONFLICT (id) DO UPDATE
SET public = true, file_size_limit = 52428800;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  10485760, -- 10MB
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = true, file_size_limit = 10485760;

-- Drop old conflicting storage policies
DROP POLICY IF EXISTS "Public Read Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Upload Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Owner Delete" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read" ON storage.objects;
DROP POLICY IF EXISTS "Allow auth upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow auth delete own" ON storage.objects;
DROP POLICY IF EXISTS "users upload own media objects" ON storage.objects;
DROP POLICY IF EXISTS "users read own media objects" ON storage.objects;
DROP POLICY IF EXISTS "users delete own media objects" ON storage.objects;
DROP POLICY IF EXISTS "Media Public Select" ON storage.objects;
DROP POLICY IF EXISTS "Media Auth Insert" ON storage.objects;
DROP POLICY IF EXISTS "Media Auth Update" ON storage.objects;
DROP POLICY IF EXISTS "Media Auth Delete" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Public Select" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Auth Insert" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Auth Update" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Auth Delete" ON storage.objects;

-- Policies for 'media' bucket
CREATE POLICY "Media Public Select"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'media');

CREATE POLICY "Media Auth Insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'media');

CREATE POLICY "Media Auth Update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'media')
  WITH CHECK (bucket_id = 'media');

CREATE POLICY "Media Auth Delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'media');

-- Policies for 'avatars' bucket
CREATE POLICY "Avatars Public Select"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

CREATE POLICY "Avatars Auth Insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Avatars Auth Update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'avatars')
  WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Avatars Auth Delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'avatars');

-- ==============================================================================
-- 7. REFRESH SCHEMA CACHE
-- ==============================================================================
NOTIFY pgrst, 'reload schema';
