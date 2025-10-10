const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 8080;

// Middleware
app.use(helmet()); // Security headers
app.use(cors()); // Enable CORS
app.use(morgan('combined')); // Logging
app.use(express.json()); // Parse JSON bodies
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded bodies

// Sample data - In production, this would come from database
const categories = [
    { id: 1, name: 'Electronics', description: 'Electronic devices and gadgets' },
    { id: 2, name: 'Clothing', description: 'Fashion and clothing items' },
    { id: 3, name: 'Books', description: 'Books and publications' },
    { id: 4, name: 'Home & Garden', description: 'Home improvement and garden items' }
];

const products = [
    {
        id: 1,
        name: 'Laptop Dell XPS 13',
        description: 'High-performance ultrabook with Intel Core i7 processor',
        price: 1299.99,
        categoryId: 1,
        stockQuantity: 25,
        imageUrl: 'https://example.com/images/laptop.jpg',
        isActive: true,
        createdAt: new Date('2024-01-15'),
        updatedAt: new Date('2024-10-01')
    },
    {
        id: 2,
        name: 'Wireless Mouse Logitech MX Master 3',
        description: 'Professional wireless mouse with advanced features',
        price: 99.99,
        categoryId: 1,
        stockQuantity: 50,
        imageUrl: 'https://example.com/images/mouse.jpg',
        isActive: true,
        createdAt: new Date('2024-02-10'),
        updatedAt: new Date('2024-09-15')
    },
    {
        id: 3,
        name: 'T-Shirt Cotton Blue',
        description: 'Comfortable cotton t-shirt in blue color',
        price: 24.99,
        categoryId: 2,
        stockQuantity: 100,
        imageUrl: 'https://example.com/images/tshirt.jpg',
        isActive: true,
        createdAt: new Date('2024-03-05'),
        updatedAt: new Date('2024-08-20')
    },
    {
        id: 4,
        name: 'JavaScript: The Definitive Guide',
        description: 'Comprehensive guide to JavaScript programming',
        price: 49.99,
        categoryId: 3,
        stockQuantity: 30,
        imageUrl: 'https://example.com/images/jsbook.jpg',
        isActive: true,
        createdAt: new Date('2024-01-20'),
        updatedAt: new Date('2024-07-10')
    },
    {
        id: 5,
        name: 'Garden Hose 50ft',
        description: 'Durable 50-foot garden hose for outdoor use',
        price: 35.99,
        categoryId: 4,
        stockQuantity: 20,
        imageUrl: 'https://example.com/images/hose.jpg',
        isActive: true,
        createdAt: new Date('2024-04-12'),
        updatedAt: new Date('2024-09-01')
    }
];

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'OK',
        service: 'Products Service',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Categories endpoints
app.get('/categories', (req, res) => {
    try {
        res.status(200).json({
            success: true,
            data: categories,
            count: categories.length
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: error.message
        });
    }
});

app.get('/categories/:id', (req, res) => {
    try {
        const categoryId = parseInt(req.params.id);
        const category = categories.find(c => c.id === categoryId);
        
        if (!category) {
            return res.status(404).json({
                success: false,
                message: 'Category not found'
            });
        }

        res.status(200).json({
            success: true,
            data: category
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: error.message
        });
    }
});

// Products endpoints
app.get('/products', (req, res) => {
    try {
        // Query parameters for filtering and pagination
        const {
            category,
            minPrice,
            maxPrice,
            search,
            page = 1,
            limit = 10,
            sortBy = 'name',
            sortOrder = 'asc'
        } = req.query;

        let filteredProducts = products.filter(p => p.isActive);

        // Filter by category
        if (category) {
            const categoryId = parseInt(category);
            filteredProducts = filteredProducts.filter(p => p.categoryId === categoryId);
        }

        // Filter by price range
        if (minPrice) {
            const min = parseFloat(minPrice);
            filteredProducts = filteredProducts.filter(p => p.price >= min);
        }
        if (maxPrice) {
            const max = parseFloat(maxPrice);
            filteredProducts = filteredProducts.filter(p => p.price <= max);
        }

        // Search in name and description
        if (search) {
            const searchTerm = search.toLowerCase();
            filteredProducts = filteredProducts.filter(p => 
                p.name.toLowerCase().includes(searchTerm) || 
                p.description.toLowerCase().includes(searchTerm)
            );
        }

        // Sort products
        filteredProducts.sort((a, b) => {
            let aValue = a[sortBy];
            let bValue = b[sortBy];
            
            if (typeof aValue === 'string') {
                aValue = aValue.toLowerCase();
                bValue = bValue.toLowerCase();
            }
            
            if (sortOrder === 'desc') {
                return bValue > aValue ? 1 : -1;
            }
            return aValue > bValue ? 1 : -1;
        });

        // Pagination
        const pageNum = parseInt(page);
        const limitNum = parseInt(limit);
        const startIndex = (pageNum - 1) * limitNum;
        const endIndex = startIndex + limitNum;
        
        const paginatedProducts = filteredProducts.slice(startIndex, endIndex);
        
        // Add category name to each product
        const productsWithCategory = paginatedProducts.map(product => ({
            ...product,
            categoryName: categories.find(c => c.id === product.categoryId)?.name || 'Unknown'
        }));

        res.status(200).json({
            success: true,
            data: productsWithCategory,
            pagination: {
                currentPage: pageNum,
                totalPages: Math.ceil(filteredProducts.length / limitNum),
                totalItems: filteredProducts.length,
                itemsPerPage: limitNum,
                hasNextPage: endIndex < filteredProducts.length,
                hasPrevPage: pageNum > 1
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: error.message
        });
    }
});

app.get('/products/:id', (req, res) => {
    try {
        const productId = parseInt(req.params.id);
        const product = products.find(p => p.id === productId && p.isActive);
        
        if (!product) {
            return res.status(404).json({
                success: false,
                message: 'Product not found'
            });
        }

        // Add category information
        const category = categories.find(c => c.id === product.categoryId);
        const productWithCategory = {
            ...product,
            category: category || null
        };

        res.status(200).json({
            success: true,
            data: productWithCategory
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: error.message
        });
    }
});

// Check stock endpoint (for other services to call)
app.get('/products/:id/stock', (req, res) => {
    try {
        const productId = parseInt(req.params.id);
        const product = products.find(p => p.id === productId && p.isActive);
        
        if (!product) {
            return res.status(404).json({
                success: false,
                message: 'Product not found'
            });
        }

        res.status(200).json({
            success: true,
            data: {
                productId: product.id,
                stockQuantity: product.stockQuantity,
                isInStock: product.stockQuantity > 0
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: error.message
        });
    }
});

// Search products endpoint
app.get('/search', (req, res) => {
    try {
        const { q: query } = req.query;
        
        if (!query) {
            return res.status(400).json({
                success: false,
                message: 'Search query is required'
            });
        }

        const searchTerm = query.toLowerCase();
        const searchResults = products.filter(p => 
            p.isActive && (
                p.name.toLowerCase().includes(searchTerm) || 
                p.description.toLowerCase().includes(searchTerm)
            )
        );

        // Add category name to each product
        const resultsWithCategory = searchResults.map(product => ({
            ...product,
            categoryName: categories.find(c => c.id === product.categoryId)?.name || 'Unknown'
        }));

        res.status(200).json({
            success: true,
            data: resultsWithCategory,
            count: resultsWithCategory.length,
            query: query
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: error.message
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
    console.log(`Products Service listening on port ${port}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
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