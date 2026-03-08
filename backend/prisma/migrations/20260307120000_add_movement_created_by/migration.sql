-- AlterTable
ALTER TABLE "movements" ADD COLUMN "created_by_id" TEXT;

-- AddForeignKey
ALTER TABLE "movements" ADD CONSTRAINT "movements_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
