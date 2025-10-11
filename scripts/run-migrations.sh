#!/bin/bash

# Database Migration Script
# Runs SQL migration files against Cloud SQL databases

set -e

PROJECT_ID="ecommerce-micro-0037"
INSTANCE_NAME="ecommerce-postgres"
MIGRATIONS_DIR="./database/migrations"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Database Migration Runner            ${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Check if Cloud SQL Proxy is installed
if ! command -v cloud-sql-proxy &> /dev/null; then
    echo -e "${RED}Error: cloud-sql-proxy not found${NC}"
    echo -e "${YELLOW}Install it with: curl -o cloud-sql-proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64${NC}"
    echo -e "${YELLOW}Or: brew install cloud-sql-proxy (on macOS)${NC}"
    exit 1
fi

# Get connection name
CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --format="value(connectionName)" --project=$PROJECT_ID)
echo -e "${GREEN}Connection Name: ${YELLOW}$CONNECTION_NAME${NC}\n"

# Start Cloud SQL Proxy in background
echo -e "${YELLOW}Starting Cloud SQL Proxy...${NC}"
cloud-sql-proxy --port=5432 $CONNECTION_NAME &
PROXY_PID=$!

# Wait for proxy to start
sleep 3

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Stopping Cloud SQL Proxy...${NC}"
    kill $PROXY_PID 2>/dev/null || true
}

trap cleanup EXIT

# Migration function
run_migration() {
    local DB_NAME=$1
    local DB_USER=$2
    local DB_PASSWORD=$3
    local SQL_FILE=$4
    
    echo -e "${YELLOW}Running migration: ${SQL_FILE}${NC}"
    echo -e "  Database: ${GREEN}${DB_NAME}${NC}"
    
    PGPASSWORD=$DB_PASSWORD psql \
        -h localhost \
        -p 5432 \
        -U $DB_USER \
        -d $DB_NAME \
        -f $SQL_FILE
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Migration completed successfully${NC}\n"
    else
        echo -e "${RED}✗ Migration failed${NC}\n"
        exit 1
    fi
}

# Run migrations
echo -e "${GREEN}[1/2] Migrating Users Database...${NC}"
run_migration \
    "users_db" \
    "users_service_user" \
    "UsersService2024!" \
    "${MIGRATIONS_DIR}/001_users_schema.sql"

echo -e "${GREEN}[2/2] Migrating Products Database...${NC}"
run_migration \
    "products_db" \
    "products_service_user" \
    "ProductsService2024!" \
    "${MIGRATIONS_DIR}/002_products_schema.sql"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  All migrations completed!            ${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Databases are ready for use!${NC}"
