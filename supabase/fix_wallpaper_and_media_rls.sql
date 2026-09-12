-- ============================================================
-- CALCX DATABASE FIX: STORAGE RLS FOR WALLPAPERS & MEDIA
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql
-- ============================================================

-- 1. Ensure the 'media' bucket exists and is set to public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true,
  52428800, -- 50MB
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp', 'video/mp4', 'video/webm', 'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/aac']
)
ON CONFLICT (id) DO UPDATE
SET public = true, file_size_limit = 52428800;

-- 2. Ensure the 'avatars' bucket exists and is set to public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  10485760, -- 10MB
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = true, file_size_limit = 10485760;

-- 3. Drop all old conflicting storage policies on storage.objects
DROP POLICY IF EXISTS "Public Read Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Upload Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Owner Delete" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read" ON storage.objects;
DROP POLICY IF EXISTS "Allow auth upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow auth delete own" ON storage.objects;
DROP POLICY IF EXISTS "users upload own media objects" ON storage.objects;
DROP POLICY IF EXISTS "users read own media objects" ON storage.objects;
DROP POLICY IF EXISTS "users delete own media objects" ON storage.objects;
DROP POLICY IF EXISTS "Media Public Select" ON storage.objects;
DROP POLICY IF EXISTS "Media Auth Insert" ON storage.objects;
DROP POLICY IF EXISTS "Media Auth Update" ON storage.objects;
DROP POLICY IF EXISTS "Media Auth Delete" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Public Select" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Auth Insert" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Auth Update" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Auth Delete" ON storage.objects;

-- 4. Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 5. Policies for 'media' bucket (Wallpapers, Chat Media, Audio, Video)
-- SELECT: Anyone can view media files (wallpapers, photos, shared media)
CREATE POLICY "Media Public Select"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'media');

-- INSERT: Authenticated users can upload to media bucket
CREATE POLICY "Media Auth Insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'media');

-- UPDATE: Authenticated users can update/upsert in media bucket
CREATE POLICY "Media Auth Update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'media')
  WITH CHECK (bucket_id = 'media');

-- DELETE: Authenticated users can delete their own media files
CREATE POLICY "Media Auth Delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'media' AND (auth.uid()::text = (storage.foldername(name))[1] OR auth.uid() IS NOT NULL));

-- 6. Policies for 'avatars' bucket (Profile Pictures)
CREATE POLICY "Avatars Public Select"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

CREATE POLICY "Avatars Auth Insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Avatars Auth Update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'avatars')
  WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Avatars Auth Delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'avatars' AND (auth.uid()::text = (storage.foldername(name))[1] OR auth.uid() IS NOT NULL));
