-- Migration: create_storage_rls.sql
-- This migration sets up Row Level Security policies for storage buckets (avatars, property-media)

-- Enable RLS on the storage.objects table
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy for avatars bucket: any authenticated user can upload, and anyone can download public avatars
CREATE POLICY "avatars_read_public"
ON storage.objects
FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "avatars_write_authenticated"
ON storage.objects
FOR INSERT
WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

-- Policy for property-media bucket: only the owner (user_id in metadata) can read/write
CREATE POLICY "property_media_owner_access"
ON storage.objects
FOR SELECT USING (
  bucket_id = 'property-media' AND (metadata->>'owner_id') = auth.uid()
);

CREATE POLICY "property_media_owner_write"
ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'property-media' AND (metadata->>'owner_id') = auth.uid()
);

-- Ensure policies are applied
ALTER TABLE storage.objects FORCE ROW LEVEL SECURITY;
