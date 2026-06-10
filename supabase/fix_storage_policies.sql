-- ============================================================
-- CALCX DATABASE PATCH: STORAGE BUCKET & RLS POLICIES
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql)
-- ============================================================

-- 1. Ensure the 'media' bucket exists and is set to public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true,
  52428800, -- 50MB in bytes
  ARRAY['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'video/mp4', 'video/webm', 'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/aac']
)
ON CONFLICT (id) DO UPDATE
SET public = true, file_size_limit = 52428800;

-- 2. Drop existing policies on storage.objects for the media bucket to avoid conflicts
DROP POLICY IF EXISTS "Public Read Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Upload Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Owner Delete" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read" ON storage.objects;
DROP POLICY IF EXISTS "Allow auth upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow auth delete own" ON storage.objects;

-- 3. Create SELECT Policy: Allow public read access to the 'media' bucket
CREATE POLICY "Public Read Access"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'media');

-- 4. Create INSERT Policy: Allow authenticated users to upload to the 'media' bucket
-- Note: We allow them to insert files into their own user folder (matching auth.uid()::text)
CREATE POLICY "Authenticated Upload Access"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'media' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- 5. Create DELETE Policy: Allow authenticated users to delete their own files
CREATE POLICY "Authenticated Owner Delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'media' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );
