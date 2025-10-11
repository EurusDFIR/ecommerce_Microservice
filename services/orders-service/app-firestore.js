const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const axios = require('axios');
const { Firestore } = require('@google-cloud/firestore');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 8082;

// ============================================
// Firestore Configuration
// ============================================

const firestore = new Firestore({
    projectId: process.env.GCP_PROJECT_ID || 'ecommerce-micro-0037',
    databaseId: '(default)'
});

// Collections
const cartsCollection = firestore.collection('carts');
const ordersCollection = firestore.collection('orders');

console.log('✓ Firestore initialized');

// ============================================
// Service URLs
// ============================================

const PRODUCTS_SERVICE_URL = process.env.PRODUCTS_SERVICE_URL || 'http://products-service:80';
const USERS_SERVICE_URL = process.env.USERS_SERVICE_URL || 'http://users-service:80';

// ============================================
// Middleware
// ============================================

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

// ============================================
// Helper Functions
// ============================================

// Verify JWT token with users-service
async function verifyToken(token) {
    try {
        const response = await axios.post(`${USERS_SERVICE_URL}/auth/verify`, { token });
        // users-service returns {success: true, data: {id, email, role}}
        return response.data.success ? response.data.data : null;
    } catch (error) {
        console.error('Token verification failed:', error.message);
        return null;
    }
}

// Fetch product details from products-service
async function fetchProduct(productId) {
    try {
        const response = await axios.get(`${PRODUCTS_SERVICE_URL}/products/${productId}`);
        // Handle both wrapped and direct response formats
        return response.data.data || response.data;
    } catch (error) {
        console.error(`Failed to fetch product ${productId}:`, error.message);
        return null;
    }
}

// Check product stock
async function checkStock(productId, quantity) {
    try {
        const response = await axios.get(`${PRODUCTS_SERVICE_URL}/products/${productId}/stock`);
        // Handle both wrapped and direct response formats
        const stock = response.data.data || response.data;
        return stock.stockQuantity >= quantity;
    } catch (error) {
        console.error(`Failed to check stock for product ${productId}:`, error.message);
        return false;
    }
}

// Reserve product stock
async function reserveStock(productId, quantity, orderId) {
    try {
        const response = await axios.post(`${PRODUCTS_SERVICE_URL}/products/${productId}/reserve`, {
            quantity,
            orderId
        });
        return response.data.success;
    } catch (error) {
        console.error(`Failed to reserve stock for product ${productId}:`, error.message);
        return false;
    }
}

// Authentication middleware
const authenticateUser = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }

    const user = await verifyToken(token);
    if (!user) {
        return res.status(403).json({ error: 'Invalid or expired token' });
    }

    req.user = user;
    next();
};

// ============================================
// Health Check
// ============================================

app.get('/health', async (req, res) => {
    try {
        // Test Firestore connection
        await ordersCollection.limit(1).get();
        
        res.json({
            status: 'healthy',
            service: 'orders-service',
            timestamp: new Date().toISOString(),
            database: 'firestore-connected',
            version: '2.0.0'
        });
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            database: 'firestore-error',
            error: error.message
        });
    }
});

// ============================================
// Shopping Cart Endpoints
// ============================================

/**
 * GET /cart
 * Get user's shopping cart
 */
app.get('/cart', authenticateUser, async (req, res) => {
    try {
        const userId = req.user.userId.toString();
        const cartDoc = await cartsCollection.doc(userId).get();

        if (!cartDoc.exists) {
            return res.json({ cart: { items: [], totalAmount: 0 } });
        }

        const cartData = cartDoc.data();
        
        // Enrich with product details
        const itemsWithDetails = await Promise.all(
            cartData.items.map(async (item) => {
                const product = await fetchProduct(item.productId);
                return {
                    ...item,
                    productName: product?.name,
                    productImage: product?.image_url,
                    currentPrice: product?.price,
                    inStock: product?.stock_quantity > 0
                };
            })
        );

        // Recalculate total
        const totalAmount = itemsWithDetails.reduce((sum, item) => 
            sum + (item.currentPrice || item.price) * item.quantity, 0
        );

        res.json({
            cart: {
                items: itemsWithDetails,
                totalAmount: parseFloat(totalAmount.toFixed(2)),
                updatedAt: cartData.updatedAt
            }
        });
    } catch (error) {
        console.error('Get cart error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /cart/items
 * Add item to cart
 */
app.post('/cart/items', authenticateUser, async (req, res) => {
    try {
        const { productId, quantity } = req.body;
        const userId = req.user.userId.toString();

        if (!productId || !quantity || quantity <= 0) {
            return res.status(400).json({ error: 'Invalid productId or quantity' });
        }

        // Fetch product details
        const product = await fetchProduct(productId);
        if (!product) {
            return res.status(404).json({ error: 'Product not found' });
        }

        // Check stock
        const hasStock = await checkStock(productId, quantity);
        if (!hasStock) {
            return res.status(400).json({ error: 'Insufficient stock' });
        }

        const cartRef = cartsCollection.doc(userId);
        const cartDoc = await cartRef.get();

        let cartData;
        if (!cartDoc.exists) {
            // Create new cart
            cartData = {
                userId: parseInt(userId),
                items: [{
                    productId: parseInt(productId),
                    quantity: parseInt(quantity),
                    price: product.price,
                    addedAt: new Date().toISOString()
                }],
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
            };
        } else {
            // Update existing cart
            cartData = cartDoc.data();
            const existingItemIndex = cartData.items.findIndex(
                item => item.productId === parseInt(productId)
            );

            if (existingItemIndex >= 0) {
                cartData.items[existingItemIndex].quantity += parseInt(quantity);
            } else {
                cartData.items.push({
                    productId: parseInt(productId),
                    quantity: parseInt(quantity),
                    price: product.price,
                    addedAt: new Date().toISOString()
                });
            }
            cartData.updatedAt = new Date().toISOString();
        }

        await cartRef.set(cartData);

        res.json({
            message: 'Item added to cart',
            cart: cartData
        });
    } catch (error) {
        console.error('Add to cart error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * PUT /cart/items/:productId
 * Update cart item quantity
 */
app.put('/cart/items/:productId', authenticateUser, async (req, res) => {
    try {
        const { productId } = req.params;
        const { quantity } = req.body;
        const userId = req.user.userId.toString();

        if (quantity < 0) {
            return res.status(400).json({ error: 'Invalid quantity' });
        }

        const cartRef = cartsCollection.doc(userId);
        const cartDoc = await cartRef.get();

        if (!cartDoc.exists) {
            return res.status(404).json({ error: 'Cart not found' });
        }

        const cartData = cartDoc.data();
        const itemIndex = cartData.items.findIndex(
            item => item.productId === parseInt(productId)
        );

        if (itemIndex < 0) {
            return res.status(404).json({ error: 'Item not in cart' });
        }

        if (quantity === 0) {
            // Remove item
            cartData.items.splice(itemIndex, 1);
        } else {
            // Check stock
            const hasStock = await checkStock(productId, quantity);
            if (!hasStock) {
                return res.status(400).json({ error: 'Insufficient stock' });
            }
            cartData.items[itemIndex].quantity = parseInt(quantity);
        }

        cartData.updatedAt = new Date().toISOString();
        await cartRef.set(cartData);

        res.json({
            message: 'Cart updated',
            cart: cartData
        });
    } catch (error) {
        console.error('Update cart error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * DELETE /cart/items/:productId
 * Remove item from cart
 */
app.delete('/cart/items/:productId', authenticateUser, async (req, res) => {
    try {
        const { productId } = req.params;
        const userId = req.user.userId.toString();

        const cartRef = cartsCollection.doc(userId);
        const cartDoc = await cartRef.get();

        if (!cartDoc.exists) {
            return res.status(404).json({ error: 'Cart not found' });
        }

        const cartData = cartDoc.data();
        cartData.items = cartData.items.filter(
            item => item.productId !== parseInt(productId)
        );
        cartData.updatedAt = new Date().toISOString();

        await cartRef.set(cartData);

        res.json({ message: 'Item removed from cart' });
    } catch (error) {
        console.error('Remove from cart error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ============================================
// Orders Endpoints
// ============================================

/**
 * POST /orders
 * Create order from cart
 */
app.post('/orders', authenticateUser, async (req, res) => {
    try {
        const { shippingAddress, paymentMethod = 'cod' } = req.body;
        const userId = req.user.userId.toString();

        if (!shippingAddress || !shippingAddress.street || !shippingAddress.city) {
            return res.status(400).json({ error: 'Invalid shipping address' });
        }

        // Get cart
        const cartDoc = await cartsCollection.doc(userId).get();
        if (!cartDoc.exists || cartDoc.data().items.length === 0) {
            return res.status(400).json({ error: 'Cart is empty' });
        }

        const cartData = cartDoc.data();

        // Validate and reserve stock
        const orderItems = [];
        let totalAmount = 0;

        for (const cartItem of cartData.items) {
            const product = await fetchProduct(cartItem.productId);
            if (!product) {
                return res.status(400).json({ 
                    error: `Product ${cartItem.productId} not found` 
                });
            }

            const hasStock = await checkStock(cartItem.productId, cartItem.quantity);
            if (!hasStock) {
                return res.status(400).json({ 
                    error: `Insufficient stock for ${product.name}` 
                });
            }

            orderItems.push({
                productId: cartItem.productId,
                productName: product.name,
                quantity: cartItem.quantity,
                price: product.price,
                subtotal: product.price * cartItem.quantity
            });

            totalAmount += product.price * cartItem.quantity;
        }

        // Create order
        const orderData = {
            userId: parseInt(userId),
            items: orderItems,
            totalAmount: parseFloat(totalAmount.toFixed(2)),
            shippingAddress,
            paymentMethod,
            status: 'pending',
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };

        const orderRef = await ordersCollection.add(orderData);
        const orderId = orderRef.id;

        // Reserve stock for each item
        for (const item of orderItems) {
            await reserveStock(item.productId, item.quantity, orderId);
        }

        // Clear cart
        await cartsCollection.doc(userId).delete();

        res.status(201).json({
            message: 'Order created successfully',
            order: {
                id: orderId,
                ...orderData
            }
        });
    } catch (error) {
        console.error('Create order error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /orders
 * Get user's order history
 */
app.get('/orders', authenticateUser, async (req, res) => {
    try {
        const userId = req.user.userId;

        const ordersSnapshot = await ordersCollection
            .where('userId', '==', userId)
            .orderBy('createdAt', 'desc')
            .get();

        const orders = ordersSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        res.json({ orders });
    } catch (error) {
        console.error('Get orders error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /orders/:id
 * Get order details
 */
app.get('/orders/:id', authenticateUser, async (req, res) => {
    try {
        const { id } = req.params;
        const orderDoc = await ordersCollection.doc(id).get();

        if (!orderDoc.exists) {
            return res.status(404).json({ error: 'Order not found' });
        }

        const orderData = orderDoc.data();

        // Check ownership
        if (orderData.userId !== req.user.userId && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Access denied' });
        }

        res.json({
            id: orderDoc.id,
            ...orderData
        });
    } catch (error) {
        console.error('Get order error:', error);
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

app.listen(port, () => {
    console.log(`🚀 Orders Service (Firestore) running on port ${port}`);
    console.log(`📊 Database: Firestore`);
    console.log(`🔗 Health check: http://localhost:${port}/health`);
});
