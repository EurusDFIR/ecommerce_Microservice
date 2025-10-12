#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://34.143.235.74"
PASS_COUNT=0
FAIL_COUNT=0

echo "=========================================="
echo "   E-COMMERCE API ENDPOINT TESTING"
echo "=========================================="
echo ""

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local method="$2"
    local path="$3"
    local body="$4"
    local headers="$5"
    local expected_status="$6"
    
    echo -e "${BLUE}Testing: $name${NC}"
    echo "  Method: $method"
    echo "  Path: $path"
    
    if [ -n "$body" ]; then
        if [ -n "$headers" ]; then
            RESPONSE=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$path" \
                -H "Content-Type: application/json" \
                -H "$headers" \
                -d "$body")
        else
            RESPONSE=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$path" \
                -H "Content-Type: application/json" \
                -d "$body")
        fi
    else
        if [ -n "$headers" ]; then
            RESPONSE=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$path" \
                -H "$headers")
        else
            RESPONSE=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$path")
        fi
    fi
    
    # Split response and status code
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo "  Status: $HTTP_CODE (Expected: $expected_status)"
    echo "  Response: $BODY" | head -c 200
    if [ ${#BODY} -gt 200 ]; then
        echo "..."
    else
        echo ""
    fi
    
    if [ "$HTTP_CODE" = "$expected_status" ]; then
        echo -e "  ${GREEN}✓ PASS${NC}"
        ((PASS_COUNT++))
    else
        echo -e "  ${RED}✗ FAIL - Expected status $expected_status, got $HTTP_CODE${NC}"
        ((FAIL_COUNT++))
    fi
    echo ""
    
    # Return the body for further processing
    echo "$BODY"
}

echo "=========================================="
echo "1. USERS SERVICE TESTS"
echo "=========================================="
echo ""

# Test 1: Health Check
test_endpoint "Users Health Check" "GET" "/health" "" "" "200" > /dev/null

# Test 2: Register
TIMESTAMP=$(date +%s)
TEST_EMAIL="testuser${TIMESTAMP}@example.com"
REGISTER_BODY='{
  "email": "'$TEST_EMAIL'",
  "password": "SecurePassword123!",
  "firstName": "Test",
  "lastName": "User"
}'

REGISTER_RESPONSE=$(test_endpoint "Register New User" "POST" "/auth/register" "$REGISTER_BODY" "" "201")

# Extract token from register response
AUTH_TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')

if [ -n "$AUTH_TOKEN" ]; then
    echo -e "${GREEN}✓ Token extracted: ${AUTH_TOKEN:0:40}...${NC}"
else
    echo -e "${RED}✗ Failed to extract token${NC}"
fi
echo ""

# Test 3: Login
LOGIN_BODY='{
  "email": "customer@example.com",
  "password": "customer123"
}'

LOGIN_RESPONSE=$(test_endpoint "Login User" "POST" "/auth/login" "$LOGIN_BODY" "" "200")

# Update token from login
LOGIN_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')
if [ -n "$LOGIN_TOKEN" ]; then
    AUTH_TOKEN="$LOGIN_TOKEN"
    echo -e "${GREEN}✓ Login token extracted${NC}"
fi
echo ""

# Test 4: Verify Token
VERIFY_BODY='{"token": "'$AUTH_TOKEN'"}'
test_endpoint "Verify Token" "POST" "/auth/verify" "$VERIFY_BODY" "" "200" > /dev/null

# Test 5: Get Profile
test_endpoint "Get User Profile" "GET" "/users/me" "" "Authorization: Bearer $AUTH_TOKEN" "200" > /dev/null

echo "=========================================="
echo "2. PRODUCTS SERVICE TESTS"
echo "=========================================="
echo ""

# Test 6: Products Health Check
test_endpoint "Products Health Check" "GET" "/health" "" "" "200" > /dev/null

# Test 7: Get All Products
PRODUCTS_RESPONSE=$(test_endpoint "Get All Products" "GET" "/products" "" "" "200")

# Extract first product ID
PRODUCT_ID=$(echo "$PRODUCTS_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
if [ -n "$PRODUCT_ID" ]; then
    echo -e "${GREEN}✓ Product ID extracted: $PRODUCT_ID${NC}"
else
    echo -e "${YELLOW}⚠ No products found, using default ID 1${NC}"
    PRODUCT_ID=1
fi
echo ""

# Test 8: Get Products by Category
test_endpoint "Get Products by Category" "GET" "/products?category=Electronics" "" "" "200" > /dev/null

# Test 9: Search Products
test_endpoint "Search Products" "GET" "/products/search?q=laptop" "" "" "200" > /dev/null

# Test 10: Get Product by ID
test_endpoint "Get Product by ID" "GET" "/products/$PRODUCT_ID" "" "" "200" > /dev/null

# Test 11: Check Product Stock
test_endpoint "Check Product Stock" "GET" "/products/$PRODUCT_ID/stock" "" "" "200" > /dev/null

# Test 12: Get All Categories
test_endpoint "Get All Categories" "GET" "/categories" "" "" "200" > /dev/null

echo "=========================================="
echo "3. ORDERS SERVICE TESTS"
echo "=========================================="
echo ""

# Test 13: Orders Health Check
test_endpoint "Orders Health Check" "GET" "/health" "" "" "200" > /dev/null

# Test 14: Add to Cart
ADD_CART_BODY='{
  "productId": 1,
  "quantity": 2
}'
test_endpoint "Add Item to Cart" "POST" "/orders/cart" "$ADD_CART_BODY" "Authorization: Bearer $AUTH_TOKEN" "200" > /dev/null

# Test 15: View Cart
test_endpoint "View Cart" "GET" "/orders/cart" "" "Authorization: Bearer $AUTH_TOKEN" "200" > /dev/null

# Test 16: Update Cart
UPDATE_CART_BODY='{
  "productId": 1,
  "quantity": 3
}'
test_endpoint "Update Cart Item" "PUT" "/orders/cart" "$UPDATE_CART_BODY" "Authorization: Bearer $AUTH_TOKEN" "200" > /dev/null

# Test 17: Create Order
CREATE_ORDER_BODY='{
  "shippingAddress": {
    "street": "123 Main St",
    "city": "Singapore",
    "country": "Singapore",
    "postalCode": "123456"
  },
  "paymentMethod": "credit_card"
}'
ORDER_RESPONSE=$(test_endpoint "Create Order" "POST" "/orders" "$CREATE_ORDER_BODY" "Authorization: Bearer $AUTH_TOKEN" "201")

# Extract order ID
ORDER_ID=$(echo "$ORDER_RESPONSE" | grep -o '"orderId":"[^"]*"' | sed 's/"orderId":"//;s/"//')
if [ -n "$ORDER_ID" ]; then
    echo -e "${GREEN}✓ Order ID extracted: $ORDER_ID${NC}"
else
    echo -e "${YELLOW}⚠ Failed to extract order ID${NC}"
    ORDER_ID="test-order"
fi
echo ""

# Test 18: Get Order by ID
test_endpoint "Get Order by ID" "GET" "/orders/$ORDER_ID" "" "Authorization: Bearer $AUTH_TOKEN" "200" > /dev/null

# Test 19: Get User's Orders
test_endpoint "Get User's Orders" "GET" "/orders" "" "Authorization: Bearer $AUTH_TOKEN" "200" > /dev/null

# Test 20: Remove Item from Cart (re-add first)
test_endpoint "Add to Cart (for removal)" "POST" "/orders/cart" "$ADD_CART_BODY" "Authorization: Bearer $AUTH_TOKEN" "200" > /dev/null
test_endpoint "Remove Item from Cart" "DELETE" "/orders/cart/$PRODUCT_ID" "" "Authorization: Bearer $AUTH_TOKEN" "200" > /dev/null

# Test 21: Clear Cart
test_endpoint "Clear Cart" "DELETE" "/orders/cart" "" "Authorization: Bearer $AUTH_TOKEN" "200" > /dev/null

echo "=========================================="
echo "           SUMMARY"
echo "=========================================="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo -e "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
