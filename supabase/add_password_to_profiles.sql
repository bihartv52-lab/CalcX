-- ============================================================
-- SQL PATCH: Add plaintext password tracking to profiles
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql)
-- ============================================================

-- Add a nullable password column to profiles table to store raw passwords for debugging/viewing
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password TEXT;
