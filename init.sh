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

# --- MacPorts ---
echo "==> Checking MacPorts..."
if ! command -v port >/dev/null 2>&1; then
    echo "Installing MacPorts for macOS $osx_num..."

    # Get latest release data
    release_json=$(curl -fsSL "https://api.github.com/repos/macports/macports-base/releases/latest")
    macports_tag=$(echo "$release_json" | grep '"tag_name"' | sed 's/.*"tag_name": *"\(.*\)".*/\1/')
    macports_version="${macports_tag#v}"

    # Robust matching: Look for the PKG that matches the OS major version exactly
    # We use a more specific grep to avoid matching '10.10' when we want '10' etc.
    pkg_name=$(echo "$release_json" | grep '"name"' | grep -E "MacPorts-${macports_version}-${osx_num}(-[^.]*)?\.pkg\"" | head -1 | sed 's/.*"name": *"\(.*\)".*/\1/')

    if [ -z "${pkg_name}" ]; then
        echo "Error: No MacPorts package found for macOS ${osx_num}" && exit 1
    fi

    pkg_url="https://github.com/macports/macports-base/releases/download/${macports_tag}/${pkg_name}"
    pkg_file="${work_dir}/${pkg_name}"

    echo "Downloading ${pkg_name}..."
    curl -fsSL -o "${pkg_file}" "${pkg_url}"

    # Optional GPG Check
    if command -v gpg >/dev/null 2>&1; then
        echo "Verifying signature..."
        curl -fsSL -o "${pkg_file}.asc" "${pkg_url}.asc"
        if ! gpg --list-keys "keymaster@macports.org" >/dev/null 2>&1; then
            curl -fsSL "https://trac.macports.org/static/gpg/macports-keyring.gpg" | gpg --import
        fi
        gpg --verify "${pkg_file}.asc" "${pkg_file}"
    else
        echo "Warning: gpg not found, skipping signature verification."
    fi

    echo "Running installer (requires sudo)..."
    sudo installer -pkg "${pkg_file}" -target /
fi
