-- Migration: Add is_featured column to properties table
-- Reason: Column referenced by PropertyModel.fromSupabase() but did not exist,
--         causing isFeatured = false for all properties → Featured Properties
--         section always empty on HomeScreen.

ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT false;

-- Seed: mark top 8 most-viewed approved properties as featured
UPDATE properties
   SET is_featured = true
 WHERE id IN (
   SELECT id
     FROM properties
    WHERE status = 'active'
      AND approval_status = 'approved'
    ORDER BY views DESC
    LIMIT 8
 );
