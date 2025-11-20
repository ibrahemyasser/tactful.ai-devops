FROM node:18-alpine

WORKDIR /app

# Copy package files and install dependencies as root
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application files
COPY . .

# Create non-root user and change ownership
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

EXPOSE 8081

CMD ["node", "server.js"]
