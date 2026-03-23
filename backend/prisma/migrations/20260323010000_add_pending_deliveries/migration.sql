-- CreateTable
CREATE TABLE "pending_deliveries" (
    "id" TEXT NOT NULL,
    "shift_id" TEXT NOT NULL,
    "entity_id" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "description" TEXT,
    "receipt_photo_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pending_deliveries_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "pending_deliveries" ADD CONSTRAINT "pending_deliveries_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "shifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pending_deliveries" ADD CONSTRAINT "pending_deliveries_entity_id_fkey" FOREIGN KEY ("entity_id") REFERENCES "banking_entities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
