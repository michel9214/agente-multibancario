-- CreateEnum
CREATE TYPE "Role" AS ENUM ('OWNER', 'OPERATOR');

-- CreateEnum
CREATE TYPE "ShiftStatus" AS ENUM ('OPEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "BalanceType" AS ENUM ('OPENING', 'CLOSING');

-- CreateEnum
CREATE TYPE "MovementType" AS ENUM ('CASH_INJECTION', 'BALANCE_INJECTION', 'ATM_WITHDRAWAL', 'PERSONAL_PAYMENT', 'BUSINESS_PAYMENT', 'OTHER');

-- CreateEnum
CREATE TYPE "MovementDirection" AS ENUM ('IN', 'OUT');

-- CreateEnum
CREATE TYPE "EntityType" AS ENUM ('BANK', 'INTERMEDIARY', 'FINTECH');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "full_name" TEXT NOT NULL,
    "role" "Role" NOT NULL DEFAULT 'OPERATOR',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "banking_entities" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "EntityType" NOT NULL DEFAULT 'BANK',
    "color" TEXT NOT NULL DEFAULT '#1976D2',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "banking_entities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shifts" (
    "id" TEXT NOT NULL,
    "operator_id" TEXT NOT NULL,
    "status" "ShiftStatus" NOT NULL DEFAULT 'OPEN',
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closed_at" TIMESTAMP(3),
    "starting_cash" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "ending_cash" DECIMAL(12,2),
    "total_opening_balance" DECIMAL(12,2),
    "total_closing_balance" DECIMAL(12,2),
    "total_movements" DECIMAL(12,2),
    "discrepancy" DECIMAL(12,2),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "shifts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "balance_entries" (
    "id" TEXT NOT NULL,
    "shift_id" TEXT NOT NULL,
    "entity_id" TEXT NOT NULL,
    "type" "BalanceType" NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "receipt_photo_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "balance_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "movements" (
    "id" TEXT NOT NULL,
    "shift_id" TEXT NOT NULL,
    "type" "MovementType" NOT NULL,
    "direction" "MovementDirection" NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "description" TEXT,
    "receipt_photo_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "movements_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "banking_entities_name_key" ON "banking_entities"("name");

-- CreateIndex
CREATE UNIQUE INDEX "balance_entries_shift_id_entity_id_type_key" ON "balance_entries"("shift_id", "entity_id", "type");

-- AddForeignKey
ALTER TABLE "shifts" ADD CONSTRAINT "shifts_operator_id_fkey" FOREIGN KEY ("operator_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "balance_entries" ADD CONSTRAINT "balance_entries_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "shifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "balance_entries" ADD CONSTRAINT "balance_entries_entity_id_fkey" FOREIGN KEY ("entity_id") REFERENCES "banking_entities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "movements" ADD CONSTRAINT "movements_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "shifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
