# =============================================================================
# Task Manager API - Production Dockerfile
# Multi-stage build for optimized image size and security
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Dependencies
# -----------------------------------------------------------------------------
FROM node:20-alpine AS deps

WORKDIR /app

# Copy package files for dependency installation
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# -----------------------------------------------------------------------------
# Stage 2: Production
# -----------------------------------------------------------------------------
FROM node:20-alpine AS production

# Add labels for container metadata (OCI standard)
LABEL org.opencontainers.image.title="Task Manager API"
LABEL org.opencontainers.image.description="C4 Project - CRUD Task Manager REST API"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="C4 Project"

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Create non-root user for security (C4 best practice)
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001 -G nodejs

WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy application source code
COPY --chown=nodeuser:nodejs src/ ./src/
COPY --chown=nodeuser:nodejs package*.json ./

# Switch to non-root user
USER nodeuser

# Expose application port
EXPOSE 3000

# Health check for container orchestration (C4/C5 requirement)
# Uses /health endpoint for liveness, /ready for readiness is handled by K8s
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start the application
CMD ["node", "src/index.js"]
