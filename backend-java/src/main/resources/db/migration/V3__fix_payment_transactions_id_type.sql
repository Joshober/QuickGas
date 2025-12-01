-- Fix payment_transactions.id column type from SERIAL (INTEGER) to BIGSERIAL (BIGINT)
-- This matches Hibernate's expectation for @GeneratedValue(strategy = GenerationType.IDENTITY)

-- First, drop the existing sequence and primary key constraint
ALTER TABLE payment_transactions DROP CONSTRAINT IF EXISTS payment_transactions_pkey;

-- Create a new sequence for BIGINT
CREATE SEQUENCE IF NOT EXISTS payment_transactions_id_seq AS BIGINT;

-- Alter the column to BIGINT
ALTER TABLE payment_transactions 
    ALTER COLUMN id TYPE BIGINT USING id::BIGINT;

-- Set the default to use the new sequence
ALTER TABLE payment_transactions 
    ALTER COLUMN id SET DEFAULT nextval('payment_transactions_id_seq');

-- Set the sequence to start from the current max value
SELECT setval('payment_transactions_id_seq', COALESCE((SELECT MAX(id) FROM payment_transactions), 1), true);

-- Recreate the primary key constraint
ALTER TABLE payment_transactions 
    ADD CONSTRAINT payment_transactions_pkey PRIMARY KEY (id);

