const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const axios = require('axios');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 8083;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Service URLs (sẽ dùng Kubernetes service names)
const PRODUCTS_SERVICE_URL = process.env.PRODUCTS_SERVICE_URL || 'http://localhost:8080';
const USERS_SERVICE_URL = process.env.USERS_SERVICE_URL || 'http://localhost:8081';

// In-memory orders storage (sẽ thay bằng Firestore)
const orders = [];
let orderIdCounter = 1;

// Shopping carts storage
const carts = new Map();

// Helper function để verify JWT token
const verifyToken = async (token) => {
    try {
        const response = await axios.post(`${USERS_SERVICE_URL}/auth/verify`, { token });
        return response.data.data;
    } catch (error) {
        return null;
    }
};

// Middleware xác thực JWT
const authenticateToken = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({
            success: false,
            message: 'Access token is required'
        });
    }

    const user = await verifyToken(token);
    if (!user) {
        return res.status(403).json({
            success: false,
            message: 'Invalid or expired token'
        });
    }

    req.user = user;
    next();
};

// Helper function để fetch product từ Products Service
const fetchProduct = async (productId) => {
    try {
        const response = await axios.get(`${PRODUCTS_SERVICE_URL}/products/${productId}`);
        return response.data.data;
    } catch (error) {
        console.error(`Error fetching product ${productId}:`, error.message);
        return null;
    }
};

// Helper function để check stock
const checkStock = async (productId) => {
    try {
        const response = await axios.get(`${PRODUCTS_SERVICE_URL}/products/${productId}/stock`);
        return response.data.data;
    } catch (error) {
        console.error(`Error checking stock for product ${productId}:`, error.message);
        return null;
    }
};

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'OK',
        service: 'Orders Service',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        dependencies: {
            productsService: PRODUCTS_SERVICE_URL,
            usersService: USERS_SERVICE_URL
        }
    });
});

// GET /cart - Lấy giỏ hàng hiện tại
app.get('/cart', authenticateToken, (req, res) => {
    try {
        const userId = req.user.id;
        const cart = carts.get(userId) || { userId, items: [], totalAmount: 0 };

        res.status(200).json({
            success: true,
            data: cart
        });
    } catch (error) {
        console.error('Get cart error:', error);
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// POST /cart/items - Thêm sản phẩm vào giỏ hàng
app.post('/cart/items', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { productId, quantity } = req.body;

        // Validation
        if (!productId || !quantity || quantity <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Product ID and valid quantity are required'
            });
        }

        // Verify product exists và lấy thông tin
        const product = await fetchProduct(productId);
        if (!product) {
            return res.status(404).json({
                success: false,
                message: 'Product not found'
            });
        }

        // Check stock
        const stockInfo = await checkStock(productId);
        if (!stockInfo || !stockInfo.isInStock || stockInfo.stockQuantity < quantity) {
            return res.status(400).json({
                success: false,
                message: 'Insufficient stock',
                availableStock: stockInfo ? stockInfo.stockQuantity : 0
            });
        }

        // Lấy hoặc tạo cart
        let cart = carts.get(userId);
        if (!cart) {
            cart = {
                userId,
                items: [],
                totalAmount: 0,
                updatedAt: new Date()
            };
        }

        // Kiểm tra product đã có trong cart chưa
        const existingItemIndex = cart.items.findIndex(item => item.productId === productId);
        
        if (existingItemIndex >= 0) {
            // Update quantity
            cart.items[existingItemIndex].quantity += quantity;
        } else {
            // Add new item
            cart.items.push({
                productId,
                productName: product.name,
                price: product.price,
                quantity,
                addedAt: new Date()
            });
        }

        // Calculate total
        cart.totalAmount = cart.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        cart.updatedAt = new Date();

        carts.set(userId, cart);

        res.status(200).json({
            success: true,
            message: 'Item added to cart',
            data: cart
        });
    } catch (error) {
        console.error('Add to cart error:', error);
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// PUT /cart/items/:productId - Cập nhật số lượng
app.put('/cart/items/:productId', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const productId = parseInt(req.params.productId);
        const { quantity } = req.body;

        if (!quantity || quantity < 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid quantity is required'
            });
        }

        const cart = carts.get(userId);
        if (!cart) {
            return res.status(404).json({
                success: false,
                message: 'Cart not found'
            });
        }

        const itemIndex = cart.items.findIndex(item => item.productId === productId);
        if (itemIndex < 0) {
            return res.status(404).json({
                success: false,
                message: 'Item not found in cart'
            });
        }

        if (quantity === 0) {
            // Remove item
            cart.items.splice(itemIndex, 1);
        } else {
            // Check stock
            const stockInfo = await checkStock(productId);
            if (!stockInfo || stockInfo.stockQuantity < quantity) {
                return res.status(400).json({
                    success: false,
                    message: 'Insufficient stock',
                    availableStock: stockInfo ? stockInfo.stockQuantity : 0
                });
            }

            // Update quantity
            cart.items[itemIndex].quantity = quantity;
        }

        // Recalculate total
        cart.totalAmount = cart.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        cart.updatedAt = new Date();

        carts.set(userId, cart);

        res.status(200).json({
            success: true,
            message: 'Cart updated',
            data: cart
        });
    } catch (error) {
        console.error('Update cart error:', error);
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// DELETE /cart/items/:productId - Xóa sản phẩm khỏi giỏ
app.delete('/cart/items/:productId', authenticateToken, (req, res) => {
    try {
        const userId = req.user.id;
        const productId = parseInt(req.params.productId);

        const cart = carts.get(userId);
        if (!cart) {
            return res.status(404).json({
                success: false,
                message: 'Cart not found'
            });
        }

        const itemIndex = cart.items.findIndex(item => item.productId === productId);
        if (itemIndex < 0) {
            return res.status(404).json({
                success: false,
                message: 'Item not found in cart'
            });
        }

        cart.items.splice(itemIndex, 1);
        cart.totalAmount = cart.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        cart.updatedAt = new Date();

        carts.set(userId, cart);

        res.status(200).json({
            success: true,
            message: 'Item removed from cart',
            data: cart
        });
    } catch (error) {
        console.error('Delete from cart error:', error);
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// POST /orders - Tạo đơn hàng từ giỏ hàng
app.post('/orders', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { shippingAddress } = req.body;

        if (!shippingAddress) {
            return res.status(400).json({
                success: false,
                message: 'Shipping address is required'
            });
        }

        // Lấy cart
        const cart = carts.get(userId);
        if (!cart || cart.items.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Cart is empty'
            });
        }

        // Verify tất cả products vẫn còn stock
        for (const item of cart.items) {
            const stockInfo = await checkStock(item.productId);
            if (!stockInfo || stockInfo.stockQuantity < item.quantity) {
                return res.status(400).json({
                    success: false,
                    message: `Insufficient stock for product: ${item.productName}`,
                    productId: item.productId,
                    available: stockInfo ? stockInfo.stockQuantity : 0,
                    requested: item.quantity
                });
            }
        }

        // Tạo order
        const order = {
            id: orderIdCounter++,
            userId,
            userEmail: req.user.email,
            items: [...cart.items],
            totalAmount: cart.totalAmount,
            shippingAddress,
            status: 'pending',
            createdAt: new Date(),
            updatedAt: new Date()
        };

        orders.push(order);

        // Clear cart
        carts.delete(userId);

        res.status(201).json({
            success: true,
            message: 'Order created successfully',
            data: order
        });
    } catch (error) {
        console.error('Create order error:', error);
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// GET /orders - Lấy lịch sử đơn hàng
app.get('/orders', authenticateToken, (req, res) => {
    try {
        const userId = req.user.id;
        const userOrders = orders.filter(order => order.userId === userId);

        res.status(200).json({
            success: true,
            data: userOrders,
            count: userOrders.length
        });
    } catch (error) {
        console.error('Get orders error:', error);
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// GET /orders/:id - Lấy chi tiết đơn hàng
app.get('/orders/:id', authenticateToken, (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const order = orders.find(o => o.id === orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify user owns this order
        if (order.userId !== req.user.id) {
            return res.status(403).json({
                success: false,
                message: 'Access denied'
            });
        }

        res.status(200).json({
            success: true,
            data: order
        });
    } catch (error) {
        console.error('Get order error:', error);
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        success: false,
        message: 'Something went wrong!',
        error: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
    });
});

// Handle 404 routes
app.use((req, res) => {
    res.status(404).json({
        success: false,
        message: 'Route not found'
    });
});

// Start server
app.listen(port, '0.0.0.0', () => {
    console.log(`Orders Service listening on port ${port}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Products Service: ${PRODUCTS_SERVICE_URL}`);
    console.log(`Users Service: ${USERS_SERVICE_URL}`);
    console.log(`Health check: http://localhost:${port}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});