-- AlterEnum
ALTER TYPE "ShiftStatus" ADD VALUE 'PRECLOSED';

-- AlterTable
ALTER TABLE "shifts" ADD COLUMN "discrepancy_note" TEXT;
ALTER TABLE "shifts" ADD COLUMN "discrepancy_photo_url" TEXT;
