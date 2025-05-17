FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04

# Argument for PyTorch CUDA nightly index URL
# USER ACTION: Verify and use the correct URL from pytorch.org for nightly builds
# that support your GPU architecture and are compatible with CUDA 12.8 runtime.
# The user suggested aiming for a cu128 equivalent if available.
ARG PYTORCH_NIGHTLY_CUDA_INDEX_URL="https://download.pytorch.org/whl/nightly/cu128"

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
# Added curl for healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1 \
    ffmpeg \
    python3 \
    python3-pip \
    python3-dev \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Install Python dependencies from requirements.txt first
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Uninstall any existing torch versions to ensure a clean slate
RUN pip3 uninstall -y torch torchvision torchaudio

# Install specific PyTorch nightly version for newer GPU architectures using the ARG
# Using --pre for preview/nightly builds
RUN pip3 install --pre torch torchvision torchaudio --index-url ${PYTORCH_NIGHTLY_CUDA_INDEX_URL}

# Copy application code
# This is placed after pip installs to leverage Docker build cache better
COPY . .

# Create required directories (ensure they exist, -p flag helps)
RUN mkdir -p model_cache reference_audio outputs voices

# Expose the port the application will run on
EXPOSE 8003

# Healthcheck to verify the server is responding
# Adjust start-period if your model loading takes longer (e.g., 90s or 120s)
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
  CMD curl --fail http://localhost:8003/docs || exit 1

# Command to run the application
CMD ["python3", "server.py"]
