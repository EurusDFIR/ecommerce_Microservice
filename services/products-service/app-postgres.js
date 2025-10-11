const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 8080;

// ============================================
// Database Configuration
// ============================================

const pool = new Pool({
    host: process.env.DB_HOST || '/cloudsql/' + process.env.CLOUD_SQL_CONNECTION_NAME,
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'products_db',
    user: process.env.DB_USER || 'products_service_user',
    password: process.env.DB_PASSWORD,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

pool.on('connect', () => {
    console.log('✓ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
    console.error('Unexpected database error:', err);
});

// ============================================
// Middleware
// ============================================

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

// ============================================
// Health Check
// ============================================

app.get('/health', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.json({
            status: 'healthy',
            service: 'products-service',
            timestamp: new Date().toISOString(),
            database: 'connected',
            version: '2.0.0'
        });
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            database: 'disconnected',
            error: error.message
        });
    }
});

// ============================================
// Products Endpoints
// ============================================

/**
 * GET /products
 * List products with filtering, pagination, sorting
 */
app.get('/products', async (req, res) => {
    try {
        const {
            category_id,
            min_price,
            max_price,
            search,
            tags,
            is_featured,
            page = 1,
            limit = 20,
            sort_by = 'created_at',
            sort_order = 'DESC'
        } = req.query;

        // Build query dynamically
        let queryText = 'SELECT p.*, c.name as category_name FROM products p LEFT JOIN categories c ON p.category_id = c.id WHERE p.is_active = true';
        const queryParams = [];
        let paramCount = 1;

        if (category_id) {
            queryText += ` AND p.category_id = $${paramCount}`;
            queryParams.push(category_id);
            paramCount++;
        }

        if (min_price) {
            queryText += ` AND p.price >= $${paramCount}`;
            queryParams.push(min_price);
            paramCount++;
        }

        if (max_price) {
            queryText += ` AND p.price <= $${paramCount}`;
            queryParams.push(max_price);
            paramCount++;
        }

        if (search) {
            queryText += ` AND (p.name ILIKE $${paramCount} OR p.description ILIKE $${paramCount})`;
            queryParams.push(`%${search}%`);
            paramCount++;
        }

        if (tags) {
            queryText += ` AND p.tags && $${paramCount}`;
            queryParams.push(tags.split(','));
            paramCount++;
        }

        if (is_featured) {
            queryText += ` AND p.is_featured = $${paramCount}`;
            queryParams.push(is_featured === 'true');
            paramCount++;
        }

        // Add sorting
        const allowedSortFields = ['created_at', 'price', 'name', 'sale_count', 'view_count'];
        const sortField = allowedSortFields.includes(sort_by) ? sort_by : 'created_at';
        const sortDir = sort_order.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';
        queryText += ` ORDER BY p.${sortField} ${sortDir}`;

        // Add pagination
        const offset = (parseInt(page) - 1) * parseInt(limit);
        queryText += ` LIMIT $${paramCount} OFFSET $${paramCount + 1}`;
        queryParams.push(parseInt(limit), offset);

        // Execute query
        const result = await pool.query(queryText, queryParams);

        // Get total count
        let countQuery = 'SELECT COUNT(*) FROM products p WHERE p.is_active = true';
        const countParams = queryParams.slice(0, -2); // Remove LIMIT and OFFSET params
        if (countParams.length > 0) {
            // Rebuild WHERE clause for count
            countQuery = queryText.split('ORDER BY')[0].replace(/SELECT .* FROM/, 'SELECT COUNT(*) FROM');
        }
        const countResult = await pool.query(countQuery, countParams);
        const total = parseInt(countResult.rows[0].count);

        res.json({
            products: result.rows,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total,
                totalPages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        console.error('Get products error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /products/:id
 * Get product details
 */
app.get('/products/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `SELECT p.*, c.name as category_name, c.slug as category_slug
             FROM products p
             LEFT JOIN categories c ON p.category_id = c.id
             WHERE p.id = $1 AND p.is_active = true`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Product not found' });
        }

        // Increment view count
        await pool.query(
            'UPDATE products SET view_count = view_count + 1 WHERE id = $1',
            [id]
        );

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Get product error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /products/:id/stock
 * Check product stock
 */
app.get('/products/:id/stock', async (req, res) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            'SELECT stock_quantity, low_stock_threshold FROM products WHERE id = $1',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Product not found' });
        }

        const product = result.rows[0];
        const inStock = product.stock_quantity > 0;
        const lowStock = product.stock_quantity <= product.low_stock_threshold;

        res.json({
            productId: parseInt(id),
            stockQuantity: product.stock_quantity,
            inStock,
            lowStock
        });
    } catch (error) {
        console.error('Stock check error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /categories
 * List all categories
 */
app.get('/categories', async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT c.*, 
                    (SELECT COUNT(*) FROM products WHERE category_id = c.id AND is_active = true) as product_count
             FROM categories c
             WHERE c.is_active = true
             ORDER BY c.sort_order, c.name`
        );

        res.json({ categories: result.rows });
    } catch (error) {
        console.error('Get categories error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /search
 * Full-text search
 */
app.get('/search', async (req, res) => {
    try {
        const { q, limit = 20 } = req.query;

        if (!q) {
            return res.status(400).json({ error: 'Search query required' });
        }

        const result = await pool.query(
            `SELECT p.*, c.name as category_name,
                    ts_rank(to_tsvector('english', p.name || ' ' || COALESCE(p.description, '')), plainto_tsquery('english', $1)) as rank
             FROM products p
             LEFT JOIN categories c ON p.category_id = c.id
             WHERE p.is_active = true
               AND (to_tsvector('english', p.name || ' ' || COALESCE(p.description, '')) @@ plainto_tsquery('english', $1)
                    OR p.name ILIKE $2
                    OR p.tags && ARRAY[$1])
             ORDER BY rank DESC, p.sale_count DESC
             LIMIT $3`,
            [q, `%${q}%`, parseInt(limit)]
        );

        res.json({
            query: q,
            results: result.rows,
            count: result.rows.length
        });
    } catch (error) {
        console.error('Search error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /products/:id/reserve
 * Reserve stock for order (called by orders-service)
 */
app.post('/products/:id/reserve', async (req, res) => {
    try {
        const { id } = req.params;
        const { quantity, orderId } = req.body;

        if (!quantity || quantity <= 0) {
            return res.status(400).json({ error: 'Invalid quantity' });
        }

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // Check stock
            const stockResult = await client.query(
                'SELECT stock_quantity FROM products WHERE id = $1 FOR UPDATE',
                [id]
            );

            if (stockResult.rows.length === 0) {
                await client.query('ROLLBACK');
                return res.status(404).json({ error: 'Product not found' });
            }

            const currentStock = stockResult.rows[0].stock_quantity;
            if (currentStock < quantity) {
                await client.query('ROLLBACK');
                return res.status(400).json({ error: 'Insufficient stock', available: currentStock });
            }

            // Update stock
            await client.query(
                'UPDATE products SET stock_quantity = stock_quantity - $1 WHERE id = $2',
                [quantity, id]
            );

            // Record stock movement
            await client.query(
                `INSERT INTO stock_movements (product_id, quantity, movement_type, reference_id, note)
                 VALUES ($1, $2, $3, $4, $5)`,
                [id, -quantity, 'sale', orderId, `Reserved for order ${orderId}`]
            );

            await client.query('COMMIT');

            res.json({
                success: true,
                productId: parseInt(id),
                reservedQuantity: quantity,
                orderId
            });
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    } catch (error) {
        console.error('Reserve stock error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ============================================
// Error Handling
// ============================================

app.use((req, res) => {
    res.status(404).json({ error: 'Endpoint not found' });
});

app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

// ============================================
// Server Start
// ============================================

process.on('SIGTERM', async () => {
    console.log('SIGTERM received, closing server...');
    await pool.end();
    process.exit(0);
});

app.listen(port, () => {
    console.log(`🚀 Products Service (PostgreSQL) running on port ${port}`);
    console.log(`📊 Database: ${process.env.DB_NAME || 'products_db'}`);
    console.log(`🔗 Health check: http://localhost:${port}/health`);
});
