# Users Service

## Overview

Authentication and user management microservice for the e-commerce platform.

## Features

- ✅ User registration
- ✅ User login with JWT
- ✅ Token verification (for inter-service communication)
- ✅ User profile management
- ✅ Role-based access (admin/customer)

## API Endpoints

### Public Endpoints:

- `POST /auth/register` - Register new user
- `POST /auth/login` - Login and get JWT token

### Protected Endpoints (require JWT):

- `GET /users/me` - Get current user info
- `GET /users` - List all users (admin only)

### Internal Endpoints (for service-to-service):

- `POST /auth/verify` - Verify JWT token
- `GET /users/:id` - Get user by ID

## Environment Variables

See `.env.example` for required configuration.

## Local Development

```bash
npm install
npm run dev
```

## Docker

```bash
docker build -t users-service:v1 .
docker run -p 8081:8081 users-service:v1
```

## Security

- Passwords hashed with bcrypt (10 rounds)
- JWT tokens with configurable expiration
- Non-root container user
- Security headers with Helmet.js

## Test Credentials

- Email: `admin@ecommerce.com` / Password: `admin123`
- Email: `customer@example.com` / Password: `customer123`
