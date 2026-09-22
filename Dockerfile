# ==============================================================================
# Stage 1: Build & Dependency Resolution
# ==============================================================================
FROM python:3.12-slim AS builder

WORKDIR /build

# Install build tools if required, compile wheels in dedicated venv
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY app/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ==============================================================================
# Stage 2: Final Secure Production Runtime
# ==============================================================================
FROM python:3.12-slim AS runner

# Build-time arguments
ARG APP_VERSION="v1.0"

# OCI standard container metadata
LABEL org.opencontainers.image.title="GitOps Demo App" \
      org.opencontainers.image.description="Lightweight microservice with version badge for ArgoCD GitOps" \
      org.opencontainers.image.authors="Raunakg2005" \
      org.opencontainers.image.version="${APP_VERSION}"

WORKDIR /app

# Security best practice: Create a dedicated non-root user & group (UID 10001)
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/false -m -d /home/appuser appuser

# Copy virtualenv from builder stage
COPY --from=builder /opt/venv /opt/venv

# Set runtime environment variables
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_VERSION="${APP_VERSION}" \
    PORT=8080

# Copy application source code with non-root ownership
COPY --chown=appuser:appgroup app/ /app/

# Container Healthcheck
HEALTHCHECK --interval=20s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8080/health').getcode() == 200 else 1)"

# Switch to non-root user
USER 10001:10001

# Expose microservice HTTP port
EXPOSE 8080

# Execute with production WSGI server Gunicorn (2 workers for concurrency)
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
