# Supabase Database Installation Guide

## Option 1: Migration (If you have existing data)

Use this if you already have tables and want to keep your data.

### Steps:
1. Go to Supabase Dashboard → SQL Editor
2. Copy the contents of `migration_fix.sql`
3. Paste and run it
4. Check for success messages

**File:** `supabase/migration_fix.sql`

---

## Option 2: Fresh Installation (Recommended for new setup)

Use this if you're starting fresh or want to reset everything.

### Steps:

#### Step 1: Drop All Existing Tables (CAUTION: This deletes all data!)

```sql
-- Drop all tables in correct order (respecting foreign keys)
DROP TABLE IF EXISTS room_music_queue CASCADE;
DROP TABLE IF EXISTS media_files CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS calls CASCADE;
DROP TABLE IF EXISTS room_participants CASCADE;
DROP VIEW IF EXISTS room_members CASCADE;
DROP TABLE IF EXISTS rooms CASCADE;
DROP TABLE IF EXISTS typing_indicators CASCADE;
DROP TABLE IF EXISTS message_reads CASCADE;
DROP TABLE IF EXISTS message_reactions CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS friends CASCADE;
DROP TABLE IF EXISTS friend_requests CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS generate_invite_code() CASCADE;
```

#### Step 2: Run Complete Schema

1. Go to Supabase Dashboard → SQL Editor
2. Copy the contents of `complete_schema_updated.sql`
3. Paste and run it
4. Verify all tables are created

**File:** `supabase/complete_schema_updated.sql`

---

## Verification

After running either option, verify your setup:

### Check Tables Exist:
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

You should see:
- calls
- friend_requests
- friends
- media_files
- message_reactions
- message_reads
- messages
- notifications
- profiles
- room_music_queue
- room_participants
- rooms
- typing_indicators

### Check Rooms Table Structure:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'rooms';
```

You should see:
- id (uuid)
- name (text)
- description (text)
- room_type (text)
- host_id (uuid)
- **visibility** (text) ← Important!
- invite_code (text)
- max_participants (integer)
- **media_url** (text) ← Important!
- **playback_state** (jsonb) ← Important!
- created_at (timestamp)
- updated_at (timestamp)

### Check room_participants Table:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'room_participants';
```

You should see:
- id (uuid)
- room_id (uuid)
- user_id (uuid)
- role (text)
- joined_at (timestamp)

### Check room_members View:
```sql
SELECT * FROM room_members LIMIT 1;
```

Should work without errors (even if empty).

---

## Common Errors and Fixes

### Error: "column receiver_id does not exist"

**Cause:** Old schema has different column names in messages table.

**Fix:** Run migration_fix.sql OR drop and recreate tables.

### Error: "relation room_participants does not exist"

**Cause:** Table not created yet.

**Fix:** Run complete_schema_updated.sql

### Error: "column is_public does not exist"

**Cause:** Code expects 'visibility' but database has 'is_public'.

**Fix:** Run migration_fix.sql to update the column.

### Error: "permission denied for table"

**Cause:** RLS policies not set up correctly.

**Fix:** Re-run the policy creation section from complete_schema_updated.sql

---

## Testing Your Setup

After installation, test with these queries:

### 1. Create a test room:
```sql
INSERT INTO rooms (name, host_id, visibility)
VALUES ('Test Room', auth.uid(), 'public')
RETURNING *;
```

### 2. Join the room:
```sql
INSERT INTO room_participants (room_id, user_id, role)
VALUES ('<room_id_from_above>', auth.uid(), 'host')
RETURNING *;
```

### 3. Query public rooms:
```sql
SELECT * FROM rooms WHERE visibility = 'public';
```

### 4. Check room_members view:
```sql
SELECT * FROM room_members;
```

All queries should work without errors!

---

## Which Option Should I Choose?

### Choose Migration (Option 1) if:
- ✅ You have existing users/data
- ✅ You want to keep your data
- ✅ You just need to update the schema

### Choose Fresh Installation (Option 2) if:
- ✅ You're setting up for the first time
- ✅ You don't have important data yet
- ✅ You want a clean start
- ✅ Migration didn't work

---

## After Installation

1. ✅ Verify all tables exist
2. ✅ Test room creation in SQL Editor
3. ✅ Build and test the Flutter app
4. ✅ Try creating a room in the app
5. ✅ Try joining a room in the app

---

## Need Help?

If you encounter errors:
1. Copy the exact error message
2. Check which table/column is mentioned
3. Verify that table exists with correct columns
4. Re-run the appropriate SQL script

---

**Ready to install! Choose your option and follow the steps above.** 🚀
