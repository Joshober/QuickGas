-- Routes table (for tracking driver routes)
CREATE TABLE IF NOT EXISTS routes (
    id BIGSERIAL PRIMARY KEY,
    route_id VARCHAR(255) NOT NULL UNIQUE,
    driver_id VARCHAR(255) NOT NULL,
    order_ids TEXT, -- JSON array of order IDs
    status VARCHAR(50) NOT NULL DEFAULT 'planning',
    polyline TEXT, -- Google Maps encoded polyline
    waypoints TEXT, -- JSON array of waypoints
    total_distance DOUBLE PRECISION,
    total_duration DOUBLE PRECISION,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_routes_driver_id ON routes(driver_id);
CREATE INDEX IF NOT EXISTS idx_routes_status ON routes(status);
CREATE INDEX IF NOT EXISTS idx_routes_route_id ON routes(route_id);
CREATE INDEX IF NOT EXISTS idx_routes_created_at ON routes(created_at DESC);

-- Trigger to auto-update updated_at
CREATE TRIGGER update_routes_updated_at BEFORE UPDATE ON routes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

