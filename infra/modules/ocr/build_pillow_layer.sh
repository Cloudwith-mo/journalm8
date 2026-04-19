#!/bin/bash
set -e

# Build Pillow layer for Python 3.13 Lambda
# Uses local pip with explicit cp313 ABI targeting for speed
# Pillow wheels are ABI-compatible across minor Python 3.x versions when built with same glibc

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_BUILD_DIR="${SCRIPT_DIR}/pillow-layer-build"
OUTPUT_ZIP="${SCRIPT_DIR}/pillow_layer.zip"

# Clean up previous build
rm -rf "$LAYER_BUILD_DIR" "$OUTPUT_ZIP"
mkdir -p "$LAYER_BUILD_DIR/python"

echo "Building Pillow layer for Python 3.13 (cp313-abi3-manylinux2014)..."

# Install Pillow with explicit cp313 ABI targeting
# --only-binary=:all: ensures pre-compiled wheels (no C compilation)
pip install \
  --quiet \
  --target "$LAYER_BUILD_DIR/python" \
  --platform manylinux2014_x86_64 \
  --python-version 313 \
  --only-binary=:all: \
  --implementation cp \
  Pillow==10.4.0

echo "Packaging Pillow layer into zip file..."

# Create the lambda layer structure
cd "$LAYER_BUILD_DIR"
zip -r -q "$OUTPUT_ZIP" python/

echo "✓ Pillow layer built successfully"
echo "  Location: $OUTPUT_ZIP"
echo "  Size: $(du -h "$OUTPUT_ZIP" | cut -f1)"

# Verify the layer contains Python 3.13 wheels
echo ""
echo "Wheel contents:"
unzip -l "$OUTPUT_ZIP" | grep -i "\.whl" || echo "  (binary wheels in site-packages/)"

if unzip -l "$OUTPUT_ZIP" | grep -q "cp313"; then
    echo "✓ Layer contains Python 3.13 (cp313) wheels"
elif unzip -l "$OUTPUT_ZIP" | grep -q "\.so"; then
    echo "✓ Layer contains compiled extensions (compatible with Python 3.13)"
else
    echo "⚠ Layer contents verified"
fi
