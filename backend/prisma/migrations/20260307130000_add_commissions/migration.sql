-- AlterTable
ALTER TABLE "shifts" ADD COLUMN "total_commissions" DECIMAL(12,2);

-- CreateTable
CREATE TABLE "commission_entries" (
    "id" TEXT NOT NULL,
    "shift_id" TEXT NOT NULL,
    "entity_id" TEXT,
    "concept" TEXT,
    "amount" DECIMAL(12,2) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "commission_entries_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "commission_entries" ADD CONSTRAINT "commission_entries_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "shifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commission_entries" ADD CONSTRAINT "commission_entries_entity_id_fkey" FOREIGN KEY ("entity_id") REFERENCES "banking_entities"("id") ON DELETE SET NULL ON UPDATE CASCADE;
