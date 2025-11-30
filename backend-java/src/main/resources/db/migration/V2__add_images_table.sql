-- Images table for storing delivery photos and other images
CREATE TABLE IF NOT EXISTS images (
    id VARCHAR(255) PRIMARY KEY,
    order_id VARCHAR(255),
    image_type VARCHAR(50) NOT NULL, -- 'delivery_photo', 'profile_picture', etc.
    file_name VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    file_size BIGINT NOT NULL,
    image_data BYTEA NOT NULL, -- Binary image data
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_images_order_id ON images(order_id);
CREATE INDEX IF NOT EXISTS idx_images_type ON images(image_type);
CREATE INDEX IF NOT EXISTS idx_images_created_at ON images(created_at DESC);

-- Trigger to update updated_at
CREATE TRIGGER update_images_updated_at BEFORE UPDATE ON images
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Update orders table to reference image by ID instead of storing base64
ALTER TABLE orders 
    ADD COLUMN IF NOT EXISTS delivery_photo_id VARCHAR(255),
    ADD CONSTRAINT fk_orders_delivery_photo 
        FOREIGN KEY (delivery_photo_id) REFERENCES images(id) ON DELETE SET NULL;

