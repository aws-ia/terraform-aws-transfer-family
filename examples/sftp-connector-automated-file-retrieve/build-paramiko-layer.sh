#!/bin/bash
set -e

echo "Building paramiko layer for x86_64 Lambda runtime..."

# Build the Docker image
docker build -t paramiko-layer-builder .

# Create a temporary container and copy the zip file
CONTAINER_ID=$(docker create paramiko-layer-builder)
docker cp $CONTAINER_ID:/tmp/paramiko-layer.zip ./paramiko-layer.zip
docker rm $CONTAINER_ID

# Verify the zip file was created
if [ -f "paramiko-layer.zip" ]; then
    echo "✅ Paramiko layer built successfully: $(ls -lh paramiko-layer.zip)"
else
    echo "❌ Failed to create paramiko-layer.zip"
    exit 1
fi
