-- ============================================
-- COMPLETE RESET AND FRESH INSTALLATION
-- This will drop everything and recreate
-- ============================================

-- STEP 1: Drop everything
SET session_replication_role = 'replica';

DROP TABLE IF EXISTS room_music_queue CASCADE;
DROP TABLE IF EXISTS media_files CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS calls CASCADE;
DROP TABLE IF EXISTS room_members CASCADE;
DROP VIEW IF EXISTS room_members CASCADE;
DROP TABLE IF EXISTS room_participants CASCADE;
DROP TABLE IF EXISTS rooms CASCADE;
DROP TABLE IF EXISTS typing_indicators CASCADE;
DROP TABLE IF EXISTS message_reads CASCADE;
DROP TABLE IF EXISTS message_reactions CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS friends CASCADE;
DROP TABLE IF EXISTS friend_requests CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS generate_invite_code() CASCADE;

SET session_replication_role = 'origin';

-- STEP 2: Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- STEP 3: Create all tables
-- (Copy the rest from complete_schema_updated.sql starting from "CREATE TABLE IF NOT EXISTS profiles")
