-- ============================================
-- CALCX DATABASE MIGRATION FIX
-- Run this to update existing database
-- ============================================

-- First, let's check what tables exist and fix them

-- ============================================
-- FIX ROOMS TABLE
-- ============================================

-- Add visibility column if it doesn't exist (replacing is_public)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='rooms' AND column_name='visibility') THEN
        ALTER TABLE rooms ADD COLUMN visibility TEXT DEFAULT 'public';
        
        -- Migrate data from is_public if it exists
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='rooms' AND column_name='is_public') THEN
            UPDATE rooms SET visibility = CASE WHEN is_public THEN 'public' ELSE 'private' END;
        END IF;
    END IF;
END $$;

-- Rename current_media_url to media_url if needed
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name='rooms' AND column_name='current_media_url') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name='rooms' AND column_name='media_url') THEN
        ALTER TABLE rooms RENAME COLUMN current_media_url TO media_url;
    END IF;
END $$;

-- Add media_url if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='rooms' AND column_name='media_url') THEN
        ALTER TABLE rooms ADD COLUMN media_url TEXT;
    END IF;
END $$;

-- Add playback_state JSONB column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='rooms' AND column_name='playback_state') THEN
        ALTER TABLE rooms ADD COLUMN playback_state JSONB;
    END IF;
END $$;

-- Drop old columns if they exist
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name='rooms' AND column_name='is_public') THEN
        ALTER TABLE rooms DROP COLUMN is_public;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name='rooms' AND column_name='media_position') THEN
        ALTER TABLE rooms DROP COLUMN media_position;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name='rooms' AND column_name='media_playing') THEN
        ALTER TABLE rooms DROP COLUMN media_playing;
    END IF;
END $$;

-- ============================================
-- CREATE OR UPDATE ROOM_PARTICIPANTS TABLE
-- ============================================

-- Create room_participants if it doesn't exist
CREATE TABLE IF NOT EXISTS room_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member',
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(room_id, user_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_room_participants_room ON room_participants(room_id);
CREATE INDEX IF NOT EXISTS idx_room_participants_user ON room_participants(user_id);

-- Create room_members view as alias
CREATE OR REPLACE VIEW room_members AS SELECT * FROM room_participants;

-- ============================================
-- ADD INDEXES FOR PROFILES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_display_name ON profiles(display_name);

-- ============================================
-- ADD INDEX FOR ROOMS VISIBILITY
-- ============================================

CREATE INDEX IF NOT EXISTS idx_rooms_visibility ON rooms(visibility);

-- ============================================
-- UPDATE RLS POLICIES FOR ROOMS
-- ============================================

-- Drop old room policies
DROP POLICY IF EXISTS "Users can view public rooms" ON rooms;
DROP POLICY IF EXISTS "Users can create rooms" ON rooms;
DROP POLICY IF EXISTS "Hosts can update their rooms" ON rooms;
DROP POLICY IF EXISTS "Hosts can delete their rooms" ON rooms;

-- Create new policies with visibility field
CREATE POLICY "Users can view public rooms"
  ON rooms FOR SELECT
  USING (visibility = 'public' OR host_id = auth.uid() OR EXISTS (
    SELECT 1 FROM room_participants WHERE room_id = rooms.id AND user_id = auth.uid()
  ));

CREATE POLICY "Users can create rooms"
  ON rooms FOR INSERT
  WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Hosts can update their rooms"
  ON rooms FOR UPDATE
  USING (auth.uid() = host_id);

CREATE POLICY "Hosts can delete their rooms"
  ON rooms FOR DELETE
  USING (auth.uid() = host_id);

-- ============================================
-- UPDATE RLS POLICIES FOR ROOM_PARTICIPANTS
-- ============================================

-- Enable RLS
ALTER TABLE room_participants ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Users can view room participants" ON room_participants;
DROP POLICY IF EXISTS "Users can join rooms" ON room_participants;
DROP POLICY IF EXISTS "Users can leave rooms" ON room_participants;

-- Create new policies
CREATE POLICY "Users can view room participants"
  ON room_participants FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM room_participants rp WHERE rp.room_id = room_participants.room_id AND rp.user_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM rooms WHERE id = room_participants.room_id AND visibility = 'public'
  ));

CREATE POLICY "Users can join rooms"
  ON room_participants FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave rooms"
  ON room_participants FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- ENABLE REALTIME FOR ROOM_PARTICIPANTS
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE room_participants;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================

DO $$ 
BEGIN
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE 'Rooms table updated with visibility field';
    RAISE NOTICE 'room_participants table created';
    RAISE NOTICE 'room_members view created';
    RAISE NOTICE 'All policies updated';
END $$;
