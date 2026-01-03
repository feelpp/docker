#!/usr/bin/env bash
# Integration test for Feel++ Docker factory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Feel++ Docker Factory Integration Test ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Test 1: Validate configuration
echo "Test 1: Configuration validation"
if ./factory.sh validate >/dev/null 2>&1; then
    pass "Configuration is valid"
else
    fail "Configuration validation failed"
fi

# Test 2: Generate all Dockerfiles
echo ""
echo "Test 2: Dockerfile generation"
mkdir -p test-integration
if ./factory.sh generate --output-dir test-integration >/dev/null 2>&1; then
    pass "All Dockerfiles generated"
else
    fail "Dockerfile generation failed"
fi

# Test 3: Check ninja-build in all Dockerfiles
echo ""
echo "Test 3: Verify ninja-build presence"
missing=0
for dockerfile in test-integration/*/Dockerfile; do
    if ! grep -q "ninja-build" "$dockerfile"; then
        fail "ninja-build missing in $dockerfile"
        missing=$((missing + 1))
    fi
done
if [ $missing -eq 0 ]; then
    pass "All Dockerfiles contain ninja-build"
fi

# Test 4: Check auxiliary files
echo ""
echo "Test 4: Verify auxiliary files"
required_files="Dockerfile bashrc.feelpp feelpp.conf.sh start.sh WELCOME"
for dir in test-integration/*/; do
    for file in $required_files; do
        if [ ! -f "$dir/$file" ]; then
            fail "Missing $file in $dir"
        fi
    done
done
pass "All directories have required files"

# Test 5: Verify build matrix generation
echo ""
echo "Test 5: Build matrix generation"
source .venv/bin/activate
if python -m factory.cli matrix --format yaml >/dev/null 2>&1; then
    count=$(python -m factory.cli matrix --format json | grep -c '"service"' || echo 0)
    pass "Build matrix generated ($count distributions)"
else
    fail "Build matrix generation failed"
fi

# Test 6: Compare with expected distributions
echo ""
echo "Test 6: Verify expected distributions"
expected_dists=(
    "debian-13-clang++"
    "debian-testing-clang++"
    "debian-sid-clang++"
    "ubuntu-24.04-clang++"
    "ubuntu-26.04-clang++"
    "fedora-42-clang++"
)

for dist in "${expected_dists[@]}"; do
    if [ -d "test-integration/$dist" ]; then
        pass "$dist directory exists"
    else
        fail "$dist directory missing"
    fi
done

# Test 7: Dockerfile syntax check (basic)
echo ""
echo "Test 7: Dockerfile syntax validation"
for dockerfile in test-integration/*/Dockerfile; do
    # Check FROM statement exists
    if ! grep -q "^FROM " "$dockerfile"; then
        fail "No FROM statement in $dockerfile"
    fi
    
    # Check for LABEL maintainer
    if ! grep -q "LABEL maintainer" "$dockerfile"; then
        warn "No maintainer label in $dockerfile"
    fi
    
    # Check for ENV statements
    if ! grep -q "^ENV " "$dockerfile"; then
        warn "No ENV statements in $dockerfile"
    fi
done
pass "Dockerfile syntax checks passed"

# Test 8: Configuration file integrity
echo ""
echo "Test 8: Configuration file integrity"
for config_file in config/distributions.yaml config/packages.yaml config/variants.yaml; do
    if [ ! -f "$config_file" ]; then
        fail "Missing configuration file: $config_file"
    fi
    
    # Try to parse YAML (Python can do this)
    if python -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
        pass "$config_file is valid YAML"
    else
        fail "$config_file has invalid YAML syntax"
    fi
done

# Test 9: Template file existence
echo ""
echo "Test 9: Template files"
for template in templates/debian.dockerfile.j2 templates/ubuntu.dockerfile.j2 templates/fedora.dockerfile.j2; do
    if [ ! -f "$template" ]; then
        fail "Missing template: $template"
    else
        pass "$template exists"
    fi
done

# Test 10: Verify file sizes
echo ""
echo "Test 10: Generated file sizes (sanity check)"
for dockerfile in test-integration/*/Dockerfile; do
    size=$(wc -c < "$dockerfile")
    if [ "$size" -lt 1000 ]; then
        warn "Dockerfile $dockerfile is suspiciously small ($size bytes)"
    elif [ "$size" -gt 50000 ]; then
        warn "Dockerfile $dockerfile is suspiciously large ($size bytes)"
    fi
done
pass "File sizes look reasonable"

# Cleanup
echo ""
echo "Cleaning up test artifacts..."
rm -rf test-integration

echo ""
echo -e "${GREEN}=== All tests passed! ===${NC}"
echo ""
echo "Summary:"
echo "  ✓ Configuration valid"
echo "  ✓ Dockerfiles generated"
echo "  ✓ ninja-build present"
echo "  ✓ Auxiliary files present"
echo "  ✓ Build matrix works"
echo "  ✓ Expected distributions exist"
echo "  ✓ Dockerfile syntax valid"
echo "  ✓ Configuration files valid"
echo "  ✓ Templates exist"
echo "  ✓ File sizes reasonable"
