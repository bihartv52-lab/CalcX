-- ========================================================================
-- CALCX DATABASE PATCH: REALTIME NOTIFICATIONS & PLAINTEXT PASSWORD VIEW
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql)
-- ========================================================================

-- 1. Enable Realtime on the notifications table safely
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_rel pr 
        JOIN pg_publication p ON p.oid = pr.prpubid 
        JOIN pg_class c ON c.oid = pr.prrelid 
        WHERE p.pubname = 'supabase_realtime' AND c.relname = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- 2. Ensure RLS policies are set correctly for notifications
-- Allows authenticated users to see their own notifications and insert new ones
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert notifications" ON public.notifications;
CREATE POLICY "Users can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- 3. Add a plaintext password column to the profiles table
-- This will let you view user passwords in plaintext inside the Supabase dashboard
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password TEXT;
