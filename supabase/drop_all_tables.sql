-- ============================================
-- DROP ALL TABLES - FRESH START
-- CAUTION: This will delete ALL data!
-- ============================================

-- Disable triggers temporarily
SET session_replication_role = 'replica';

-- Drop tables in correct order (respecting foreign keys)
DROP TABLE IF EXISTS room_music_queue CASCADE;
DROP TABLE IF EXISTS media_files CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS calls CASCADE;

-- Drop room_members (could be table or view)
DROP TABLE IF EXISTS room_members CASCADE;
DROP VIEW IF EXISTS room_members CASCADE;

-- Drop room_participants
DROP TABLE IF EXISTS room_participants CASCADE;

-- Drop rooms
DROP TABLE IF EXISTS rooms CASCADE;

-- Drop messaging tables
DROP TABLE IF EXISTS typing_indicators CASCADE;
DROP TABLE IF EXISTS message_reads CASCADE;
DROP TABLE IF EXISTS message_reactions CASCADE;
DROP TABLE IF EXISTS messages CASCADE;

-- Drop friends tables
DROP TABLE IF EXISTS friends CASCADE;
DROP TABLE IF EXISTS friend_requests CASCADE;

-- Drop profiles
DROP TABLE IF EXISTS profiles CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS generate_invite_code() CASCADE;

-- Re-enable triggers
SET session_replication_role = 'origin';

-- Verify all tables are dropped
SELECT 'Tables remaining:' as status;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- If the above query returns no rows, you're ready to run complete_schema_updated.sql
