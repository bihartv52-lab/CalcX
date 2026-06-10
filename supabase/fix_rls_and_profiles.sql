-- ============================================================
-- CALCX DATABASE FIX: RLS RECURSION & PROFILES SYNC
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql)
-- ============================================================

-- 1. Fix the infinite recursion on room_participants
-- Drop the old recursive policy
DROP POLICY IF EXISTS "Users can view room participants" ON room_participants;

-- Re-create it using a simple non-recursive check
CREATE POLICY "Users can view room participants"
  ON room_participants FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- 2. Migrate/Sync existing user data from public.users to public.profiles
-- The app queries public.profiles, but you entered usernames in public.users.
-- This query copies them over so they are searchable and usable in the app.
INSERT INTO public.profiles (id, username, display_name, status)
SELECT id, username, username, 'offline'
FROM public.users
ON CONFLICT (id) DO UPDATE
SET username = EXCLUDED.username,
    display_name = EXCLUDED.username;

-- 3. Update the handle_new_user trigger to populate both tables automatically on signup
-- This ensures that when a new user registers, they are created in BOTH public.profiles and public.users.
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
DECLARE
  username_val TEXT;
BEGIN
  username_val := coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1));
  
  -- Insert into profiles (used by current app code)
  INSERT INTO public.profiles (id, username, display_name, status)
  VALUES (new.id, username_val, username_val, 'offline')
  ON CONFLICT (id) DO NOTHING;
  
  -- Insert into users (legacy/extra compatibility)
  INSERT INTO public.users (id, username)
  VALUES (new.id, username_val)
  ON CONFLICT (id) DO NOTHING;
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-enable trigger (in case it got detached)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
