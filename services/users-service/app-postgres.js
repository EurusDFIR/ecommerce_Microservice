const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
require('dotenv').config();

// Demo: Trigger CD workflow for presentation
const app = express();
const port = process.env.PORT || 8081;

// ============================================
// Database Configuration
// ============================================

// PostgreSQL Connection Pool
const pool = new Pool({
    host: process.env.DB_HOST || '/cloudsql/' + process.env.CLOUD_SQL_CONNECTION_NAME,
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'users_db',
    user: process.env.DB_USER || 'users_service_user',
    password: process.env.DB_PASSWORD,
    max: 20, // Maximum pool size
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Test database connection
pool.on('connect', () => {
    console.log('✓ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
    console.error('Unexpected database error:', err);
    process.exit(-1);
});

// ============================================
// Middleware
// ============================================

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';

// ============================================
// Helper Functions
// ============================================

const generateToken = (user) => {
    return jwt.sign(
        {
            id: user.id,  // Changed from userId to id for consistency
            email: user.email,
            role: user.role
        },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRES_IN }
    );
};

// JWT Authentication Middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: 'Invalid or expired token' });
        }
        req.user = user;
        next();
    });
};

// Admin role check middleware
const requireAdmin = (req, res, next) => {
    if (req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Admin access required' });
    }
    next();
};

// ============================================
// Health Check Endpoint
// ============================================

app.get('/health', async (req, res) => {
    try {
        // Check database connection
        await pool.query('SELECT 1');
        res.json({
            status: 'healthy',
            service: 'users-service',
            timestamp: new Date().toISOString(),
            database: 'connected',
            version: '2.0.0'
        });
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            service: 'users-service',
            database: 'disconnected',
            error: error.message
        });
    }
});

// ============================================
// Authentication Endpoints
// ============================================

/**
 * POST /auth/register
 * Register a new user
 */
app.post('/auth/register', async (req, res) => {
    try {
        const { email, password, firstName, lastName } = req.body;

        // Validation
        if (!email || !password || !firstName || !lastName) {
            return res.status(400).json({
                error: 'Missing required fields',
                required: ['email', 'password', 'firstName', 'lastName']
            });
        }

        // Validate email format
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({ error: 'Invalid email format' });
        }

        // Validate password strength
        if (password.length < 6) {
            return res.status(400).json({ error: 'Password must be at least 6 characters' });
        }

        // Check if user already exists
        const existingUser = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [email.toLowerCase()]
        );

        if (existingUser.rows.length > 0) {
            return res.status(409).json({ error: 'Email already registered' });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Insert new user
        const result = await pool.query(
            `INSERT INTO users (email, password_hash, first_name, last_name, role)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id, email, first_name, last_name, role, created_at`,
            [email.toLowerCase(), hashedPassword, firstName, lastName, 'customer']
        );

        const newUser = result.rows[0];

        // Generate JWT token
        const token = generateToken(newUser);

        // Store session
        const tokenHash = require('crypto').createHash('sha256').update(token).digest('hex');
        await pool.query(
            `INSERT INTO user_sessions (user_id, token_hash, expires_at, user_agent, ip_address)
             VALUES ($1, $2, NOW() + INTERVAL '24 hours', $3, $4)`,
            [newUser.id, tokenHash, req.get('user-agent'), req.ip]
        );

        // Log audit trail
        await pool.query(
            `INSERT INTO user_audit_log (user_id, action, details, ip_address)
             VALUES ($1, $2, $3, $4)`,
            [newUser.id, 'register', JSON.stringify({ email }), req.ip]
        );

        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            data: {
                user: {
                    id: newUser.id,
                    email: newUser.email,
                    firstName: newUser.first_name,
                    lastName: newUser.last_name,
                    role: newUser.role,
                    createdAt: newUser.created_at
                },
                token
            }
        });
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /auth/login
 * User login
 */
app.post('/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password required' });
        }

        // Find user
        const result = await pool.query(
            `SELECT id, email, password_hash, first_name, last_name, role, is_active
             FROM users
             WHERE email = $1`,
            [email.toLowerCase()]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const user = result.rows[0];

        // Check if account is active
        if (!user.is_active) {
            return res.status(403).json({ error: 'Account is disabled' });
        }

        // Verify password
        const validPassword = await bcrypt.compare(password, user.password_hash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Update last login
        await pool.query(
            'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
            [user.id]
        );

        // Generate token
        const token = generateToken(user);

        // Store session
        const tokenHash = require('crypto').createHash('sha256').update(token).digest('hex');
        await pool.query(
            `INSERT INTO user_sessions (user_id, token_hash, expires_at, user_agent, ip_address)
             VALUES ($1, $2, NOW() + INTERVAL '24 hours', $3, $4)`,
            [user.id, tokenHash, req.get('user-agent'), req.ip]
        );

        // Log audit trail
        await pool.query(
            `INSERT INTO user_audit_log (user_id, action, ip_address)
             VALUES ($1, $2, $3)`,
            [user.id, 'login', req.ip]
        );

        res.json({
            success: true,
            message: 'Login successful',
            data: {
                user: {
                    id: user.id,
                    email: user.email,
                    firstName: user.first_name,
                    lastName: user.last_name,
                    role: user.role
                },
                token
            }
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /auth/verify
 * Verify JWT token (used by other services)
 */
app.post('/auth/verify', async (req, res) => {
    try {
        const { token } = req.body;

        if (!token) {
            return res.status(400).json({ error: 'Token required' });
        }

        jwt.verify(token, JWT_SECRET, async (err, decoded) => {
            if (err) {
                return res.status(401).json({ valid: false, error: 'Invalid token' });
            }

            // Check if session exists and not expired
            const tokenHash = require('crypto').createHash('sha256').update(token).digest('hex');
            const session = await pool.query(
                `SELECT id FROM user_sessions
                 WHERE token_hash = $1 AND expires_at > NOW()`,
                [tokenHash]
            );

            if (session.rows.length === 0) {
                return res.status(401).json({ valid: false, error: 'Session expired or invalid' });
            }

            res.json({
                success: true,
                data: {
                    userId: decoded.id,  // Map id to userId for compatibility
                    email: decoded.email,
                    role: decoded.role
                }
            });
        });
    } catch (error) {
        console.error('Token verification error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /auth/logout
 * Logout user (invalidate token)
 */
app.post('/auth/logout', authenticateToken, async (req, res) => {
    try {
        const token = req.headers['authorization'].split(' ')[1];
        const tokenHash = require('crypto').createHash('sha256').update(token).digest('hex');

        // Delete session
        await pool.query(
            'DELETE FROM user_sessions WHERE token_hash = $1',
            [tokenHash]
        );

        // Log audit trail
        await pool.query(
            `INSERT INTO user_audit_log (user_id, action, ip_address)
             VALUES ($1, $2, $3)`,
            [req.user.userId, 'logout', req.ip]
        );

        res.json({ message: 'Logged out successfully' });
    } catch (error) {
        console.error('Logout error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ============================================
// User Management Endpoints
// ============================================

/**
 * GET /users/me
 * Get current user profile
 */
app.get('/users/me', authenticateToken, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, email, first_name, last_name, role, created_at, last_login, email_verified
             FROM users
             WHERE id = $1`,
            [req.user.userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const user = result.rows[0];

        res.json({
            id: user.id,
            email: user.email,
            firstName: user.first_name,
            lastName: user.last_name,
            role: user.role,
            createdAt: user.created_at,
            lastLogin: user.last_login,
            emailVerified: user.email_verified
        });
    } catch (error) {
        console.error('Get user error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * PUT /users/me
 * Update current user profile
 */
app.put('/users/me', authenticateToken, async (req, res) => {
    try {
        const { firstName, lastName } = req.body;
        
        const result = await pool.query(
            `UPDATE users
             SET first_name = COALESCE($1, first_name),
                 last_name = COALESCE($2, last_name)
             WHERE id = $3
             RETURNING id, email, first_name, last_name, role`,
            [firstName, lastName, req.user.userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const user = result.rows[0];

        // Log audit trail
        await pool.query(
            `INSERT INTO user_audit_log (user_id, action, details)
             VALUES ($1, $2, $3)`,
            [req.user.userId, 'profile_update', JSON.stringify({ firstName, lastName })]
        );

        res.json({
            message: 'Profile updated successfully',
            user: {
                id: user.id,
                email: user.email,
                firstName: user.first_name,
                lastName: user.last_name,
                role: user.role
            }
        });
    } catch (error) {
        console.error('Update user error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /users (Admin only)
 * List all users
 */
app.get('/users', authenticateToken, requireAdmin, async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const offset = (page - 1) * limit;

        const result = await pool.query(
            `SELECT id, email, first_name, last_name, role, created_at, last_login, is_active
             FROM users
             ORDER BY created_at DESC
             LIMIT $1 OFFSET $2`,
            [limit, offset]
        );

        const countResult = await pool.query('SELECT COUNT(*) FROM users');
        const total = parseInt(countResult.rows[0].count);

        res.json({
            users: result.rows.map(user => ({
                id: user.id,
                email: user.email,
                firstName: user.first_name,
                lastName: user.last_name,
                role: user.role,
                createdAt: user.created_at,
                lastLogin: user.last_login,
                isActive: user.is_active
            })),
            pagination: {
                page,
                limit,
                total,
                totalPages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        console.error('List users error:', error);
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

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('SIGTERM received, closing server...');
    await pool.end();
    process.exit(0);
});

app.listen(port, () => {
    console.log(`🚀 Users Service (PostgreSQL) running on port ${port}`);
    console.log(`📊 Database: ${process.env.DB_NAME || 'users_db'}`);
    console.log(`🔗 Health check: http://localhost:${port}/health`);
});
