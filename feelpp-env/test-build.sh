#!/usr/bin/env bash
# Test build a Dockerfile locally
# Usage: ./test-build.sh <distribution>
# Example: ./test-build.sh ubuntu:24.04

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ ! -x ".venv/bin/feelpp-factory" ]; then
    uv venv .venv
    source .venv/bin/activate
    uv pip install -q -e "${PROJECT_ROOT}"
fi
FACTORY=".venv/bin/feelpp-factory"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <distribution>"
    echo ""
    echo "Available distributions:"
    "$FACTORY" show --variant feelpp-env | grep -E "debian:|ubuntu:|fedora:" || true
    exit 1
fi

DIST="$1"
DIST_NAME="${DIST%%:*}"
DIST_VERSION="${DIST#*:}"

# Map to directory name
if [ "$DIST_NAME" = "debian" ]; then
    if [ "$DIST_VERSION" = "13" ]; then
        DIR="debian-13-clang++"
    elif [ "$DIST_VERSION" = "testing" ]; then
        DIR="debian-testing-clang++"
    elif [ "$DIST_VERSION" = "sid" ]; then
        DIR="debian-sid-clang++"
    fi
elif [ "$DIST_NAME" = "ubuntu" ]; then
    DIR="ubuntu-${DIST_VERSION}-clang++"
elif [ "$DIST_NAME" = "fedora" ]; then
    DIR="fedora-${DIST_VERSION}-clang++"
fi

if [ -z "${DIR:-}" ] || [ ! -d "$DIR" ]; then
    echo "Error: Directory for $DIST not found"
    echo "Expected: $DIR"
    exit 1
fi

echo "=== Testing Docker build for $DIST ==="
echo "Directory: $DIR"
echo ""

# Build the image
TAG="feelpp-env-test:${DIST_NAME}-${DIST_VERSION}"
echo "Building: $TAG"
echo ""

cd "$DIR"
docker build --progress=plain -t "$TAG" . 2>&1 | tee build.log

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Build succeeded!"
    echo "Image: $TAG"
    echo "Size: $(docker images $TAG --format '{{.Size}}')"
    echo ""
    echo "Test the image:"
    echo "  docker run --rm -it $TAG bash"
    echo ""
    echo "Verify ninja:"
    echo "  docker run --rm $TAG which ninja"
else
    echo ""
    echo "✗ Build failed. Check build.log for details."
    exit 1
fi
