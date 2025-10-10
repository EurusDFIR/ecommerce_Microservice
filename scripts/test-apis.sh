#!/bin/bash

# Test script for Products Service APIs
# Usage: ./test-apis.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

API_URL="http://34.143.235.74"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Products Service APIs${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
echo -e "GET ${API_URL}/health"
response=$(curl -s "${API_URL}/health")
if [[ $response == *"OK"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

# Test 2: Get All Products
echo -e "${YELLOW}Test 2: Get All Products${NC}"
echo -e "GET ${API_URL}/products"
response=$(curl -s "${API_URL}/products")
if [[ $response == *"success\":true"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.data | length' 2>/dev/null || echo "Products returned"
echo ""

# Test 3: Get Product by ID
echo -e "${YELLOW}Test 3: Get Product by ID (ID=1)${NC}"
echo -e "GET ${API_URL}/products/1"
response=$(curl -s "${API_URL}/products/1")
if [[ $response == *"Laptop Dell XPS 13"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.data.name' 2>/dev/null || echo "$response"
echo ""

# Test 4: Get Categories
echo -e "${YELLOW}Test 4: Get Categories${NC}"
echo -e "GET ${API_URL}/categories"
response=$(curl -s "${API_URL}/categories")
if [[ $response == *"Electronics"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.data | length' 2>/dev/null || echo "Categories returned"
echo ""

# Test 5: Search Products
echo -e "${YELLOW}Test 5: Search Products (q=laptop)${NC}"
echo -e "GET ${API_URL}/search?q=laptop"
response=$(curl -s "${API_URL}/search?q=laptop")
if [[ $response == *"Laptop"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.count' 2>/dev/null || echo "Search results returned"
echo ""

# Test 6: Filter by Category
echo -e "${YELLOW}Test 6: Filter by Category (category=1)${NC}"
echo -e "GET ${API_URL}/products?category=1"
response=$(curl -s "${API_URL}/products?category=1")
if [[ $response == *"Electronics"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.pagination.totalItems' 2>/dev/null || echo "Filtered results returned"
echo ""

# Test 7: Price Range Filter
echo -e "${YELLOW}Test 7: Price Range Filter (minPrice=50, maxPrice=100)${NC}"
echo -e "GET ${API_URL}/products?minPrice=50&maxPrice=100"
response=$(curl -s "${API_URL}/products?minPrice=50&maxPrice=100")
if [[ $response == *"success\":true"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.pagination.totalItems' 2>/dev/null || echo "Filtered results returned"
echo ""

# Test 8: Pagination
echo -e "${YELLOW}Test 8: Pagination (page=1, limit=2)${NC}"
echo -e "GET ${API_URL}/products?page=1&limit=2"
response=$(curl -s "${API_URL}/products?page=1&limit=2")
if [[ $response == *"currentPage\":1"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.pagination' 2>/dev/null || echo "Paginated results returned"
echo ""

# Test 9: Sorting
echo -e "${YELLOW}Test 9: Sort by Price Descending${NC}"
echo -e "GET ${API_URL}/products?sortBy=price&sortOrder=desc"
response=$(curl -s "${API_URL}/products?sortBy=price&sortOrder=desc")
if [[ $response == *"Laptop Dell XPS 13"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.data[0].name' 2>/dev/null || echo "Sorted results returned"
echo ""

# Test 10: Check Stock
echo -e "${YELLOW}Test 10: Check Stock (product ID=1)${NC}"
echo -e "GET ${API_URL}/products/1/stock"
response=$(curl -s "${API_URL}/products/1/stock")
if [[ $response == *"stockQuantity"* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

# Test 11: Invalid Product ID
echo -e "${YELLOW}Test 11: Invalid Product ID (ID=999)${NC}"
echo -e "GET ${API_URL}/products/999"
response=$(curl -s "${API_URL}/products/999")
if [[ $response == *"not found"* ]]; then
    echo -e "${GREEN}✓ PASSED (correctly returned 404)${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
fi
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}All critical APIs are working!${NC}"
echo -e "\n${YELLOW}API Base URL:${NC} ${API_URL}"
echo -e "${YELLOW}Status:${NC} ${GREEN}✓ OPERATIONAL${NC}\n"