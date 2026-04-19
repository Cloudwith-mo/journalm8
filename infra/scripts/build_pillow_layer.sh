#!/bin/bash

# Deterministic Python 3.13-compatible Pillow layer builder using Lambda runtime image
# This script builds a Pillow wheel in the exact Lambda Python 3.13 runtime environment
# and packages it as a Lambda layer zip file.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}"
LAYER_ZIP="${OUTPUT_DIR}/pillow_layer.zip"

echo "Building Pillow layer for Lambda Python 3.13..."
echo "Output: ${LAYER_ZIP}"

# Create temporary build directory
BUILD_DIR=$(mktemp -d)
trap "rm -rf ${BUILD_DIR}" EXIT

LAYER_DIR="${BUILD_DIR}/layer"
mkdir -p "${LAYER_DIR}/python"

# Use the official AWS Lambda Python 3.13 runtime image to build the wheel
# This ensures cp313 compatibility with the exact runtime environment
docker run --rm \
  -v "${LAYER_DIR}:/layer" \
  public.ecr.aws/lambda/python:3.13 \
  /bin/bash -c "
    set -e
    pip install --quiet Pillow==10.4.0 -t /layer/python --only-binary=:all:
    echo 'Pillow layer built successfully in Lambda Python 3.13 runtime'
    find /layer/python -name '*.dist-info' -type d -exec ls -la {} \;
  "

# Create the layer zip
cd "${LAYER_DIR}"
zip -q -r "${LAYER_ZIP}" python/

echo "✓ Pillow layer created: ${LAYER_ZIP}"
ls -lh "${LAYER_ZIP}"

# Verify the zip contains Python packages
echo "✓ Layer contents:"
unzip -l "${LAYER_ZIP}" | head -20
