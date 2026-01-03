#!/usr/bin/env bash
# Feel++ Docker Factory - Convenience wrapper
# Usage: ./factory.sh [command] [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"

# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    uv venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    echo "Installing dependencies..."
    uv pip install -q pyyaml jinja2 click rich pydantic
else
    source "$VENV_DIR/bin/activate"
fi

# Run the CLI
exec python -m factory.cli "$@"
