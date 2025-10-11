-- Products Database Schema
-- This script creates tables for the products-service

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    slug VARCHAR(100) UNIQUE NOT NULL,
    parent_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    image_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categories_slug ON categories(slug);
CREATE INDEX idx_categories_parent_id ON categories(parent_id);
CREATE INDEX idx_categories_active ON categories(is_active);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    slug VARCHAR(255) UNIQUE NOT NULL,
    sku VARCHAR(100) UNIQUE,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    compare_at_price DECIMAL(10, 2) CHECK (compare_at_price >= price),
    cost_price DECIMAL(10, 2) CHECK (cost_price >= 0),
    stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0),
    low_stock_threshold INTEGER DEFAULT 10,
    weight DECIMAL(8, 2),
    dimensions JSONB, -- {length, width, height}
    image_url VARCHAR(500),
    images JSONB, -- Array of image URLs
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    tags TEXT[], -- Array of tags
    metadata JSONB, -- Additional flexible data
    view_count INTEGER DEFAULT 0,
    sale_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for products
CREATE INDEX idx_products_slug ON products(slug);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_active ON products(is_active);
CREATE INDEX idx_products_featured ON products(is_featured);
CREATE INDEX idx_products_stock ON products(stock_quantity);
CREATE INDEX idx_products_name_search ON products USING gin(to_tsvector('english', name));
CREATE INDEX idx_products_tags ON products USING gin(tags);
CREATE INDEX idx_products_created_at ON products(created_at DESC);

-- Product variants table (for products with multiple options like size, color)
CREATE TABLE IF NOT EXISTS product_variants (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    sku VARCHAR(100) UNIQUE NOT NULL,
    option1_name VARCHAR(50), -- e.g., "Size"
    option1_value VARCHAR(50), -- e.g., "Large"
    option2_name VARCHAR(50), -- e.g., "Color"
    option2_value VARCHAR(50), -- e.g., "Red"
    option3_name VARCHAR(50),
    option3_value VARCHAR(50),
    price DECIMAL(10, 2),
    compare_at_price DECIMAL(10, 2),
    stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0),
    image_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_product_variants_product_id ON product_variants(product_id);
CREATE INDEX idx_product_variants_sku ON product_variants(sku);

-- Product reviews table
CREATE TABLE IF NOT EXISTS product_reviews (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL, -- Reference to users in users_db
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(200),
    comment TEXT,
    is_verified_purchase BOOLEAN DEFAULT false,
    is_approved BOOLEAN DEFAULT false,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX idx_product_reviews_user_id ON product_reviews(user_id);
CREATE INDEX idx_product_reviews_rating ON product_reviews(rating);
CREATE INDEX idx_product_reviews_approved ON product_reviews(is_approved);

-- Stock movements table (inventory tracking)
CREATE TABLE IF NOT EXISTS stock_movements (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    variant_id INTEGER REFERENCES product_variants(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL, -- Positive for additions, negative for removals
    movement_type VARCHAR(50) NOT NULL, -- 'purchase', 'sale', 'adjustment', 'return'
    reference_id VARCHAR(100), -- Order ID, purchase order ID, etc.
    note TEXT,
    created_by INTEGER, -- User ID who made the change
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_stock_movements_product_id ON stock_movements(product_id);
CREATE INDEX idx_stock_movements_created_at ON stock_movements(created_at DESC);
CREATE INDEX idx_stock_movements_type ON stock_movements(movement_type);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for auto-updating updated_at
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_product_variants_updated_at BEFORE UPDATE ON product_variants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_product_reviews_updated_at BEFORE UPDATE ON product_reviews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update product stock after stock movement
CREATE OR REPLACE FUNCTION update_product_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.variant_id IS NULL THEN
        UPDATE products 
        SET stock_quantity = stock_quantity + NEW.quantity
        WHERE id = NEW.product_id;
    ELSE
        UPDATE product_variants
        SET stock_quantity = stock_quantity + NEW.quantity
        WHERE id = NEW.variant_id;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER stock_movement_update_stock AFTER INSERT ON stock_movements
    FOR EACH ROW EXECUTE FUNCTION update_product_stock();

-- Insert sample categories
INSERT INTO categories (name, slug, description, sort_order) VALUES
    ('Electronics', 'electronics', 'Electronic devices and accessories', 1),
    ('Laptops', 'laptops', 'Laptops and notebooks', 10),
    ('Accessories', 'accessories', 'Computer accessories', 20),
    ('Smartphones', 'smartphones', 'Mobile phones and tablets', 30),
    ('Audio', 'audio', 'Headphones and speakers', 40)
ON CONFLICT (slug) DO NOTHING;

-- Update parent categories
UPDATE categories SET parent_id = (SELECT id FROM categories WHERE slug = 'electronics')
WHERE slug IN ('laptops', 'accessories', 'smartphones', 'audio');

-- Insert sample products
INSERT INTO products (name, description, slug, sku, category_id, price, compare_at_price, stock_quantity, image_url, tags, is_featured) VALUES
    (
        'Gaming Laptop Pro X1',
        'High-performance gaming laptop with RTX 4080, 32GB RAM, 1TB SSD. Perfect for gaming and content creation.',
        'gaming-laptop-pro-x1',
        'LAPTOP-001',
        (SELECT id FROM categories WHERE slug = 'laptops'),
        1899.99,
        2299.99,
        15,
        'https://example.com/laptop1.jpg',
        ARRAY['gaming', 'laptop', 'nvidia', 'high-performance'],
        true
    ),
    (
        'Wireless Gaming Mouse',
        'Ergonomic wireless mouse with RGB lighting and 16000 DPI sensor.',
        'wireless-gaming-mouse',
        'MOUSE-001',
        (SELECT id FROM categories WHERE slug = 'accessories'),
        79.99,
        99.99,
        50,
        'https://example.com/mouse1.jpg',
        ARRAY['mouse', 'gaming', 'wireless', 'rgb'],
        true
    ),
    (
        'Mechanical Keyboard RGB',
        'Full-size mechanical keyboard with Cherry MX switches and customizable RGB lighting.',
        'mechanical-keyboard-rgb',
        'KEYBOARD-001',
        (SELECT id FROM categories WHERE slug = 'accessories'),
        149.99,
        179.99,
        30,
        'https://example.com/keyboard1.jpg',
        ARRAY['keyboard', 'mechanical', 'gaming', 'rgb'],
        false
    ),
    (
        'Noise-Cancelling Headphones',
        'Premium wireless headphones with active noise cancellation and 30-hour battery life.',
        'noise-cancelling-headphones',
        'HEADPHONE-001',
        (SELECT id FROM categories WHERE slug = 'audio'),
        299.99,
        349.99,
        25,
        'https://example.com/headphone1.jpg',
        ARRAY['headphones', 'wireless', 'noise-cancelling', 'premium'],
        true
    ),
    (
        '4K Webcam Pro',
        'Professional 4K webcam with auto-focus and dual microphones for streaming and video calls.',
        '4k-webcam-pro',
        'WEBCAM-001',
        (SELECT id FROM categories WHERE slug = 'accessories'),
        129.99,
        159.99,
        40,
        'https://example.com/webcam1.jpg',
        ARRAY['webcam', '4k', 'streaming', 'video-call'],
        false
    )
ON CONFLICT (slug) DO NOTHING;

-- Grant permissions to products_service_user
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO products_service_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO products_service_user;

-- Comments for documentation
COMMENT ON TABLE categories IS 'Product categories with hierarchical structure';
COMMENT ON TABLE products IS 'Main products catalog';
COMMENT ON TABLE product_variants IS 'Product variations (size, color, etc.)';
COMMENT ON TABLE product_reviews IS 'Customer reviews and ratings';
COMMENT ON TABLE stock_movements IS 'Inventory movement history';

COMMENT ON COLUMN products.tags IS 'Array of searchable tags';
COMMENT ON COLUMN products.metadata IS 'Flexible JSON field for additional attributes';
COMMENT ON COLUMN products.dimensions IS 'Product dimensions in JSON: {length, width, height}';
