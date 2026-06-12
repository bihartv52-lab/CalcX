-- SQL PATCH: Add email tracking to profiles and update trigger to support username login
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard)

-- 1. Add email column to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. Update the handle_new_user trigger function to auto-sync email and support conflicts
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
DECLARE
  username_val TEXT;
BEGIN
  username_val := coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1));
  
  -- Insert into profiles (used by current app code)
  INSERT INTO public.profiles (id, username, display_name, status, email)
  VALUES (new.id, username_val, username_val, 'offline', new.email)
  ON CONFLICT (id) DO UPDATE SET 
    email = EXCLUDED.email,
    username = EXCLUDED.username,
    display_name = EXCLUDED.display_name;
  
  -- Insert into users (legacy/extra compatibility)
  INSERT INTO public.users (id, username)
  VALUES (new.id, username_val)
  ON CONFLICT (id) DO NOTHING;
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
