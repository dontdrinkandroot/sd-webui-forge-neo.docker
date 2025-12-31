# Use NVIDIA CUDA 12.8 base image to support recent NVIDIA GPUs.
# Ubuntu 22.04 is used as the base OS for stability and compatibility.
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# Build-time and Run-time environment variables
# DEBIAN_FRONTEND=noninteractive: Prevents interactive prompts during apt-get calls.
ENV DEBIAN_FRONTEND=noninteractive
# PYTHONUNBUFFERED=1: Ensures python output is sent directly to the terminal without buffering.
ENV PYTHONUNBUFFERED=1
# PIP_NO_CACHE_DIR=1: Disables pip cache to keep the image size smaller.
ENV PIP_NO_CACHE_DIR=1

RUN apt-get update

RUN apt-get install -y \
      curl \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update

# Install system dependencies
# Includes essential tools (git, wget, curl), python environment, 
# graphics libraries (libgl1, libglib2.0-0), and memory allocators (libgoogle-perftools4).
# supervisord is used to manage multiple processes (Caddy and Forge-Neo).
RUN apt-get install -y \
    git \
    python3 \
    python3-venv \
    python3-pip \
    libgl1 \
    libglib2.0-0 \
    libgoogle-perftools4 \
    libtcmalloc-minimal4 \
    wget \
    supervisor \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    caddy \
    && rm -rf /var/lib/apt/lists/*

# LD_PRELOAD: Use tcmalloc for better memory management, which is recommended for Stable Diffusion.
ENV LD_PRELOAD=libtcmalloc_minimal.so.4

# Install uv (extremely fast Python package installer and resolver) 
# to speed up the build process and ensure reproducible environments.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set the working directory for the application
WORKDIR /app

# Clone Stable Diffusion WebUI Forge Neo (tag 2.7)
# This variant provides optimizations and new features over the classic WebUI.
RUN git clone --branch 2.7 --single-branch https://github.com/Haoming02/sd-webui-forge-classic.git .

# Set uv cache directory for persistent builds if using Docker build cache.
ENV UV_CACHE_DIR=/root/.cache/uv
# Increase timeout for downloading large NVIDIA packages
ENV UV_HTTP_TIMEOUT=600

# Create and activate a virtual environment using uv for isolation.
RUN uv venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Install PyTorch and TorchVision with CUDA 12.8 support.
# We explicitly use the cu128 extra-index-url to match our NVIDIA base image 
# and ensure optimal performance on modern GPUs.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install \
    torch==2.7.1+cu128 \
    torchvision==0.22.1+cu128 \
    --extra-index-url https://download.pytorch.org/whl/cu128

# Install the primary requirements defined by Forge Neo.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install -r requirements.txt

# Install additional packages and optimizations:
# xformers/bitsandbytes: Memory and speed optimizations for SD.
# gradio*: UI components used by Forge.
# sageattention: Supported optimization for improved attention mechanism performance.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install \
    xformers==0.0.33 \
    bitsandbytes==0.49.0 \
    gradio==4.40.0 \
    gradio_imageslider==0.0.20 \
    gradio_rangeslider==0.0.8 \
    packaging==24.2 \
    sageattention

# Pre-create necessary directories for persistent volumes and logging.
# - models: for checkpoints, LoRAs, etc.
# - outputs: for generated images.
# - local_estimations: for Forge specific metadata.
RUN mkdir -p models outputs local_estimations /var/log/supervisor

# Copy configuration files for process management and proxying.
COPY Caddyfile /etc/caddy/Caddyfile
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose HTTP (80) and HTTPS (443) ports for Caddy.
# Caddy proxies requests to the Forge-Neo instance running on 7860.
EXPOSE 80 443

# Default CLI arguments for Forge Neo:
# --listen: Allows connections from outside the container.
# --port 7860: Internal port for the WebUI.
# --enable-insecure-extension-access: Required for some extension functionality in Docker.
# --api: Exposes the API for external integrations.
ENV CLI_ARGS="--listen --port 7860 --enable-insecure-extension-access --api"

# AUTH_TOKEN: If set, Caddy will require this Bearer token for authentication.
ENV AUTH_TOKEN=""

# Use supervisord to run both Caddy and Forge-Neo as background services.
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

LABEL maintainer="dontdrinkandroot"
LABEL org.opencontainers.image.title="Stable Diffusion WebUI Forge Neo"
LABEL org.opencontainers.image.version="2.7-cuda"
LABEL org.opencontainers.image.description="Docker image for Stable Diffusion WebUI Forge Neo with CUDA 12.8 and Caddy proxy."
