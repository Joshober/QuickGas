-- Add stripe_account_id column to users table for Stripe Connect integration
ALTER TABLE users ADD COLUMN IF NOT EXISTS stripe_account_id VARCHAR(255);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_stripe_account_id ON users(stripe_account_id) WHERE stripe_account_id IS NOT NULL;

