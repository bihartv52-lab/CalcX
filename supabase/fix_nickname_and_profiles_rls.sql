-- ============================================================
-- CALCX DATABASE FIX: NICKNAME COLUMN & PROFILES RLS POLICY
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql
-- ============================================================

-- 1. Add the missing 'nickname' column to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS nickname TEXT;

-- 2. Also ensure other optional profile columns exist
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'offline';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS credits INT DEFAULT 100;

-- 3. Enable RLS on profiles (standard security)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. Drop all existing old/conflicting policies on public.profiles
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "profiles are visible to signed in users" ON public.profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "users update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "users insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.profiles;

-- 5. Re-create clean, fully working policies for profiles:

-- SELECT: Anyone can view profiles (including nickname, display_name, avatar, status)
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  TO public
  USING (true);

-- UPDATE: Users can update their own profile (nickname, bio, display_name, avatar)
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- INSERT: Users can insert their own profile
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- 6. Refresh PostgREST schema cache so the new column is immediately accessible
NOTIFY pgrst, 'reload schema';
