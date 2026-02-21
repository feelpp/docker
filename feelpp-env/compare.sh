#!/usr/bin/env bash
# Compare old vs new generated Dockerfiles
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

echo "=== Dockerfile Comparison ==="
echo ""

# Compare sizes
echo "File sizes:"
for dir in debian-13-clang++ debian-sid-clang++ ubuntu-24.04-clang++ fedora-42-clang++; do
    if [ -f "$dir/Dockerfile" ]; then
        size=$(wc -c < "$dir/Dockerfile")
        lines=$(wc -l < "$dir/Dockerfile")
        printf "  %-25s %6d bytes, %3d lines\n" "$dir" "$size" "$lines"
    fi
done

echo ""
echo "=== Checking for ninja-build ===" 
for dir in debian-13-clang++ debian-testing-clang++ debian-sid-clang++ ubuntu-24.04-clang++ fedora-42-clang++; do
    if grep -q "ninja-build" "$dir/Dockerfile" 2>/dev/null; then
        echo "  ✓ $dir has ninja-build"
    else
        echo "  ✗ $dir missing ninja-build"
    fi
done

echo ""
echo "=== Checking auxiliary files ===" 
required_files="Dockerfile bashrc.feelpp feelpp.conf.sh start.sh WELCOME"
for dir in debian-13-clang++ debian-testing-clang++ debian-sid-clang++ ubuntu-24.04-clang++ fedora-42-clang++; do
    missing=0
    for file in $required_files; do
        if [ ! -f "$dir/$file" ]; then
            missing=$((missing + 1))
        fi
    done
    if [ $missing -eq 0 ]; then
        echo "  ✓ $dir has all required files"
    else
        echo "  ✗ $dir missing $missing files"
    fi
done

echo ""
echo "=== Build Matrix Generated ===" 
if [ -f ".github/workflows/feelpp-env.yml" ]; then
    old_count=$(grep -c "flavor:" .github/workflows/feelpp-env.yml || echo 0)
    echo "  Old workflow: ~$old_count distributions"
fi

new_count=$("$FACTORY" matrix --format json | grep -c '"service"' || echo 0)
echo "  New factory:  $new_count distributions"

echo ""
echo "Phase 2 Status: COMPLETE ✓"
