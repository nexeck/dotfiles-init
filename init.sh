#!/usr/bin/env bash

set -euo pipefail

# --- Configuration & Environment ---
work_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

# Ensure newly installed tools are available immediately
export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:/opt/local/sbin:$PATH"

# --- Discovery ---
unameOut="$(uname -s)"
case "${unameOut}" in
    Darwin*)    machine=darwin ;;
    *)          echo "Error: This script only supports macOS." && exit 1 ;;
esac

osx_num=$(sw_vers -productVersion | awk -F '.' '{print $1}')
# Handle legacy macOS 10.x
if [ "$osx_num" -eq 10 ]; then
    osx_num=$(sw_vers -productVersion | awk -F '.' '{print $1"."$2}')
fi

echo "Detected macOS version: $osx_num"

# --- Homebrew ---
echo "==> Checking Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Ensure brew is active in the current session
if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
