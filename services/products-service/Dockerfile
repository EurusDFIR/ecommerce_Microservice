# Sử dụng base image Node.js chính thức
FROM node:18-slim

# Thiết lập metadata
LABEL maintainer="your-email@example.com"
LABEL version="1.0.0"
LABEL description="Products Service for E-commerce Microservices"

# Tạo thư mục làm việc trong container
WORKDIR /app

# Tạo user không có root privileges để chạy ứng dụng
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy package.json và package-lock.json để tận dụng Docker layer caching
COPY package*.json ./

# Cài đặt dependencies
RUN npm install --production && npm cache clean --force

# Copy toàn bộ source code
COPY . .

# Thay đổi ownership của thư mục /app cho user appuser
RUN chown -R appuser:appuser /app

# Chuyển sang user appuser (không chạy với root)
USER appuser

# Mở port 8080 để bên ngoài có thể truy cập
EXPOSE 8080

# Health check để kiểm tra container có hoạt động không
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Lệnh để chạy ứng dụng khi container khởi động
CMD ["node", "app.js"]