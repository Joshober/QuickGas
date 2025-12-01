-- Driver payments table (for tracking driver payouts)
CREATE TABLE IF NOT EXISTS driver_payments (
    id BIGSERIAL PRIMARY KEY,
    driver_id VARCHAR(255) NOT NULL,
    order_id VARCHAR(255) NOT NULL,
    route_id VARCHAR(255),
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'usd',
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    stripe_payout_id VARCHAR(255),
    stripe_transfer_id VARCHAR(255),
    paid_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_driver_payments_driver_id ON driver_payments(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_payments_order_id ON driver_payments(order_id);
CREATE INDEX IF NOT EXISTS idx_driver_payments_status ON driver_payments(status);
CREATE INDEX IF NOT EXISTS idx_driver_payments_created_at ON driver_payments(created_at DESC);

-- Trigger to auto-update updated_at
CREATE TRIGGER update_driver_payments_updated_at BEFORE UPDATE ON driver_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

