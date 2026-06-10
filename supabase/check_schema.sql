-- ============================================
-- CHECK CURRENT SCHEMA
-- Run this to see what you currently have
-- ============================================

-- Check all tables
SELECT 'TABLES:' as info;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Check rooms table structure
SELECT 'ROOMS TABLE COLUMNS:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'rooms'
ORDER BY ordinal_position;

-- Check if room_members exists and what it is
SELECT 'ROOM_MEMBERS INFO:' as info;
SELECT table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'room_members';

-- Check room_participants if it exists
SELECT 'ROOM_PARTICIPANTS COLUMNS:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'room_participants'
ORDER BY ordinal_position;

-- Check messages table structure
SELECT 'MESSAGES TABLE COLUMNS:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'messages'
ORDER BY ordinal_position;
