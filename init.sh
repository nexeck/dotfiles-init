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

# --- Base Tools ---
echo "==> Installing Base Tools (chezmoi, pass-cli)..."
for tool in chezmoi pass-cli; do
    if ! brew list "$tool" >/dev/null 2>&1; then
        # Handle pass-cli tap if needed (keeping original tap logic)
        if [ "$tool" == "pass-cli" ]; then
            brew install protonpass/tap/pass-cli
        else
            brew install "$tool"
        fi
    fi
done

# --- Proton Pass & SSH Agent ---
echo "==> Configuring Proton Pass SSH Agent..."
if ! pass-cli vault list >/dev/null 2>&1; then
    pass-cli login
else
    echo "Already logged in to Proton Pass."
fi
pass-cli ssh-agent daemon start

export SSH_AUTH_SOCK="$HOME/.ssh/proton-pass-agent.sock"

# Wait for socket to be ready
echo "Waiting for SSH agent socket..."
for i in {1..10}; do
    if [ -S "$SSH_AUTH_SOCK" ]; then
        echo "SSH agent is ready."
        break
    fi
    sleep 0.5
done

if [ ! -S "$SSH_AUTH_SOCK" ]; then
    echo "Warning: SSH agent socket not found at $SSH_AUTH_SOCK"
fi

# --- Chezmoi ---
echo "==> Initializing Dotfiles with chezmoi..."
if [ -d "$HOME/.local/share/chezmoi" ]; then
    echo "Existing chezmoi directory found. Updating..."
    chezmoi update --apply
else
    echo "Initializing new chezmoi repository..."
    chezmoi init --apply --ssh nexeck
fi

echo "Done! System initialized."
