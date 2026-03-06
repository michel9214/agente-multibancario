-- AlterTable
ALTER TABLE "movements" ADD COLUMN     "reason_id" TEXT;

-- CreateTable
CREATE TABLE "movement_reasons" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "default_direction" "MovementDirection" NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "movement_reasons_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "movement_reasons_name_key" ON "movement_reasons"("name");

-- AddForeignKey
ALTER TABLE "movements" ADD CONSTRAINT "movements_reason_id_fkey" FOREIGN KEY ("reason_id") REFERENCES "movement_reasons"("id") ON DELETE SET NULL ON UPDATE CASCADE;
