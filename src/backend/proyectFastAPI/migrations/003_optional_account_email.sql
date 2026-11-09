-- Account forms use the fields from the screen flow and do not collect email.
-- Preserve existing addresses for compatibility without inventing new ones.
ALTER TABLE Admn ALTER COLUMN admn_email DROP NOT NULL;
ALTER TABLE Staff ALTER COLUMN staff_email DROP NOT NULL;
ALTER TABLE Parents ALTER COLUMN par_email DROP NOT NULL;
