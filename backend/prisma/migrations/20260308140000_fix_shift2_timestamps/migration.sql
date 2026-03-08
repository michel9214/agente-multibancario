-- Fix shift 2 (SUSANA) timestamps to simulate March 7th afternoon
-- Opening: 2:10 PM Peru (UTC-5) = 19:10 UTC March 7
-- Closing: 8:35 PM Peru (UTC-5) = 01:35 UTC March 8

-- Update shift timestamps
UPDATE "shifts"
SET "started_at" = '2026-03-07T19:10:00.000Z',
    "closed_at" = '2026-03-08T01:35:00.000Z',
    "created_at" = '2026-03-07T19:10:00.000Z',
    "updated_at" = '2026-03-08T01:35:00.000Z'
WHERE "id" = 'c24f63d6-2c38-4615-be12-8ea53301440b';

-- Update OPENING balance entries to opening time (no updated_at column)
UPDATE "balance_entries"
SET "created_at" = '2026-03-07T19:10:00.000Z'
WHERE "shift_id" = 'c24f63d6-2c38-4615-be12-8ea53301440b'
  AND "type" = 'OPENING';

-- Update CLOSING balance entries to closing time
UPDATE "balance_entries"
SET "created_at" = '2026-03-08T01:35:00.000Z'
WHERE "shift_id" = 'c24f63d6-2c38-4615-be12-8ea53301440b'
  AND "type" = 'CLOSING';

-- Update movement to be during the shift (~2:15 PM Peru = 19:15 UTC March 7)
UPDATE "movements"
SET "created_at" = '2026-03-07T19:15:00.000Z'
WHERE "shift_id" = 'c24f63d6-2c38-4615-be12-8ea53301440b';

-- Update commission entries to closing time
UPDATE "commission_entries"
SET "created_at" = '2026-03-08T01:35:00.000Z'
WHERE "shift_id" = 'c24f63d6-2c38-4615-be12-8ea53301440b';
