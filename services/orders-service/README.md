# Orders Service

## Overview

Shopping cart and order management microservice for the e-commerce platform.

## Features

- ✅ Shopping cart management
- ✅ Add/remove items from cart
- ✅ Update item quantities
- ✅ Create orders from cart
- ✅ Order history
- ✅ Inter-service communication with Products & Users services

## API Endpoints

### Cart Management (require JWT):

- `GET /cart` - Get current cart
- `POST /cart/items` - Add item to cart
- `PUT /cart/items/:productId` - Update quantity
- `DELETE /cart/items/:productId` - Remove item

### Order Management (require JWT):

- `POST /orders` - Create order from cart
- `GET /orders` - Get order history
- `GET /orders/:id` - Get order details

## Dependencies

- **Products Service**: Verify products, check stock
- **Users Service**: Verify JWT tokens

## Environment Variables

```
PRODUCTS_SERVICE_URL=http://products-service:80
USERS_SERVICE_URL=http://users-service:80
```

## Local Development

```bash
npm install
npm run dev
```

## Docker

```bash
docker build -t orders-service:v1 .
docker run -p 8083:8083 \
  -e PRODUCTS_SERVICE_URL=http://localhost:8080 \
  -e USERS_SERVICE_URL=http://localhost:8081 \
  orders-service:v1
```

## Inter-Service Communication

- Uses HTTP requests via axios
- Kubernetes service DNS resolution
- Automatic retry on failures
- Error handling for service unavailability

## Data Storage

- In-memory storage (demo)
- Ready for Firestore integration
- Cart data per user
- Order history per user
