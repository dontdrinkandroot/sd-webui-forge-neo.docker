# --- Stage 1: Builder ---
# Use the NVIDIA CUDA 12.8.1 runtime image as the builder base.
FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04 AS builder

# Build-time environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install build-only dependencies (git is needed for cloning, python3-venv for venv creation)
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    python3-venv \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install uv (extremely fast Python package installer and resolver)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# Clone Stable Diffusion WebUI Forge Neo (tag 2.7)
# This variant provides optimizations and new features over the classic WebUI.
# We remove the .git directory to save space before copying to the runtime stage.
RUN git clone --branch 2.7 --single-branch https://github.com/Haoming02/sd-webui-forge-classic.git . \
    && rm -rf .git

# Set uv cache directory for persistent builds and increase timeout for large packages.
ENV UV_CACHE_DIR=/root/.cache/uv
ENV UV_HTTP_TIMEOUT=600
ENV UV_LINK_MODE=copy

# Create a virtual environment using uv for isolation.
RUN uv venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Install PyTorch, TorchVision and all requirements in one block to optimize layers.
# We use sageattention as supported optimization.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install \
    torch==2.7.1+cu128 \
    torchvision==0.22.1+cu128 \
    --extra-index-url https://download.pytorch.org/whl/cu128 \
    && uv pip install -r requirements.txt \
    && uv pip install \
    xformers==0.0.33 \
    bitsandbytes==0.49.0 \
    gradio==4.40.0 \
    gradio_imageslider==0.0.20 \
    gradio_rangeslider==0.0.8 \
    packaging==24.2 \
    sageattention

# --- Stage 2: Runtime ---
# Final production image
FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04

# Run-time environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
# Disables Python bytecode generation to minimize image size.
ENV PYTHONDONTWRITEBYTECODE=1
ENV PATH="/app/venv/bin:$PATH"

# Install only necessary runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update && apt-get install -y \
    python3 \
    # libgl1 and libglib2.0-0 are required by opencv-python (e.g., for autocrop) \
    libgl1 \
    libglib2.0-0 \
    libgoogle-perftools4 \
    libtcmalloc-minimal4 \
    supervisor \
    caddy \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Use tcmalloc for better memory management in Stable Diffusion.
ENV LD_PRELOAD=libtcmalloc_minimal.so.4

WORKDIR /app

# Copy the application and the pre-installed virtual environment from the builder
COPY --from=builder /app /app

# Pre-create necessary directories for persistent volumes and logging.
RUN mkdir -p models outputs local_estimations /var/log/supervisor

# Configuration
COPY Caddyfile /etc/caddy/Caddyfile
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose HTTP (80) and HTTPS (443) ports for Caddy.
EXPOSE 80 443

# Default CLI arguments for Forge Neo
ENV CLI_ARGS="--listen --port 7860 --enable-insecure-extension-access --api"
# AUTH_TOKEN: If set, Caddy will require this Bearer token for authentication.
ENV AUTH_TOKEN=""

# Use supervisord to run both Caddy and Forge-Neo as background services.
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

LABEL maintainer="dontdrinkandroot"
LABEL org.opencontainers.image.title="Stable Diffusion WebUI Forge Neo"
LABEL org.opencontainers.image.version="2.7-cuda"
LABEL org.opencontainers.image.description="Docker image for Stable Diffusion WebUI Forge Neo with CUDA 12.8.1 and Caddy proxy."
