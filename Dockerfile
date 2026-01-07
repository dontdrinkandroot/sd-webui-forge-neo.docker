# Use the NVIDIA CUDA 12.9.1 runtime image.
FROM nvidia/cuda:12.9.1-runtime-ubuntu24.04

ARG FORGE_VERSION=2.7

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
# Disables Python bytecode generation to minimize image size.
ENV PYTHONDONTWRITEBYTECODE=1

# Install uv (extremely fast Python package installer and resolver)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Install necessary runtime and build dependencies
# libgl1 and libglib2.0-0 are required by opencv-python
# libtcmalloc-minimal4t64 provides tcmalloc for better memory management
RUN apt-get update && apt-get install -y \
    git \
    libgl1 \
    libglib2.0-0 \
    libtcmalloc-minimal4t64 \
    supervisor \
    caddy \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Use tcmalloc for better memory management in Stable Diffusion.
ENV LD_PRELOAD=libtcmalloc_minimal.so.4

WORKDIR /app

# Install Python 3.11 via uv
RUN uv python install 3.11

# Clone Stable Diffusion WebUI Forge Neo
# This variant provides optimizations and new features over the classic WebUI.
# We remove the .git directory to save space.
RUN git clone --branch ${FORGE_VERSION} --single-branch https://github.com/Haoming02/sd-webui-forge-classic.git . \
    && rm -rf .git

# Add sageattention to requirements.txt
RUN echo "sageattention" >> requirements.txt

# Set uv cache directory for persistent builds and increase timeout for large packages.
ENV UV_CACHE_DIR=/root/.cache/uv
ENV UV_HTTP_TIMEOUT=600
ENV UV_LINK_MODE=copy

# Forge Neo environment variables to override defaults for CUDA 12.8 (compatible with 12.9.1)
ENV TORCH_INDEX_URL="https://download.pytorch.org/whl/cu128"
ENV TORCH_COMMAND="pip install torch==2.9.1+cu128 torchvision --index-url https://download.pytorch.org/whl/cu128"
#ENV XFORMERS_PACKAGE="xformers==0.0.33 --extra-index-url https://download.pytorch.org/whl/cu128"

# Create a virtual environment using uv for isolation with Python 3.11.
RUN uv venv --python 3.11 /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Pre-create necessary directories for persistent volumes and logging.
RUN mkdir -p models outputs local_estimations /var/log/supervisor /root/.cache/uv

# Configuration
COPY files/Caddyfile /etc/caddy/Caddyfile
COPY files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose HTTP (80) and HTTPS (443) ports for Caddy.
EXPOSE 80 443

# Default CLI arguments for Forge Neo. We add --uv to use uv for dependency installation.
# We also add --xformers, --sage and --bnb to match previously pre-installed packages.
ENV CLI_ARGS="--listen --port 7860 --enable-insecure-extension-access --api --uv --xformers --sage --bnb"
# AUTH_TOKEN: If set, Caddy will require this Bearer token for authentication.
ENV AUTH_TOKEN=""

# Use supervisord to run both Caddy and Forge-Neo as background services.
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

LABEL maintainer="dontdrinkandroot"
LABEL org.opencontainers.image.title="Stable Diffusion WebUI Forge Neo"
LABEL org.opencontainers.image.version="${FORGE_VERSION}-cuda"
LABEL org.opencontainers.image.description="Docker image for Stable Diffusion WebUI Forge Neo with CUDA 12.9.1 and Caddy proxy."
