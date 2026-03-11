-- Fix last closed shift closedAt to March 10, 8:30 PM Peru time (UTC-5)
UPDATE shifts
SET closed_at = '2026-03-11 01:30:00'::timestamp,
    updated_at = '2026-03-11 01:30:00'::timestamp
WHERE id = '2dd0255f-af00-4b87-8482-d8e8375bf3c2';
