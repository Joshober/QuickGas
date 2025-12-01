-- Remove foreign key constraint from payment_transactions.order_id
-- Orders are stored in Firestore, not PostgreSQL, so the foreign key constraint
-- prevents payment transactions from being saved when orders don't exist in the database

ALTER TABLE payment_transactions 
    DROP CONSTRAINT IF EXISTS payment_transactions_order_id_fkey;

-- Keep order_id as a regular column for reference, but without foreign key constraint
-- This allows payment transactions to reference orders in Firestore

