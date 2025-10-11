# Sử dụng base image Node.js chính thức
FROM node:18-slim

# Thiết lập metadata
LABEL maintainer="your-email@example.com"
LABEL version="1.0.0"
LABEL description="Users Service for E-commerce Microservices"

# Tạo thư mục làm việc trong container
WORKDIR /app

# Tạo user không có root privileges
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy package.json và package-lock.json
COPY package*.json ./

# Cài đặt dependencies
RUN npm install --production && npm cache clean --force

# Copy toàn bộ source code
COPY . .

# Thay đổi ownership
RUN chown -R appuser:appuser /app

# Chuyển sang user appuser
USER appuser

# Mở port 8081
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

# Lệnh để chạy ứng dụng
CMD ["node", "app.js"]