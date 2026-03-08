-- Fix shift timestamps to March 7th (opening 7AM, closing 2PM Peru time = UTC-5)
-- and recalculate discrepancy with corrected formula

-- Update shift timestamps and recalculated discrepancy
UPDATE "shifts"
SET
  "started_at" = '2026-03-07T12:00:00.000Z',
  "closed_at" = '2026-03-07T19:00:00.000Z',
  "created_at" = '2026-03-07T12:00:00.000Z',
  "updated_at" = '2026-03-07T19:00:00.000Z',
  "discrepancy" = 372.93
WHERE "id" = '5c4132e3-0192-4469-96ef-4bb7d269eb1a';

-- Update OPENING balance entries to 7:00 AM Peru (12:00 UTC)
UPDATE "balance_entries"
SET "created_at" = '2026-03-07T12:00:00.000Z'
WHERE "shift_id" = '5c4132e3-0192-4469-96ef-4bb7d269eb1a'
  AND "type" = 'OPENING';

-- Update CLOSING balance entries to 2:00 PM Peru (19:00 UTC)
UPDATE "balance_entries"
SET "created_at" = '2026-03-07T19:00:00.000Z'
WHERE "shift_id" = '5c4132e3-0192-4469-96ef-4bb7d269eb1a'
  AND "type" = 'CLOSING';

-- Update movements to mid-shift (~9:00 AM and ~9:15 AM Peru = 14:00 and 14:15 UTC)
UPDATE "movements"
SET "created_at" = '2026-03-07T14:00:00.000Z'
WHERE "id" = '0e5d90e1-573d-419b-818d-bc51a9fb2b9d';

UPDATE "movements"
SET "created_at" = '2026-03-07T14:15:00.000Z'
WHERE "id" = '3e02c9d3-b8ce-4cb5-a434-8db41012ea81';

-- Update commission entries to closing time
UPDATE "commission_entries"
SET "created_at" = '2026-03-07T19:00:00.000Z'
WHERE "shift_id" = '5c4132e3-0192-4469-96ef-4bb7d269eb1a';
