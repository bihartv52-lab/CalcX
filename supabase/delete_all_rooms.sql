-- ==========================================================
-- SCRIPT: Remove All Existing Groups / Rooms
-- This wipes all room messages, room participants, and room rows.
-- ==========================================================

BEGIN;

-- 1. Remove messages associated with rooms
DELETE FROM messages
WHERE room_id IS NOT NULL;

-- 2. Remove participants in rooms
DELETE FROM room_participants;

-- 3. Remove all rooms
DELETE FROM rooms;

COMMIT;
