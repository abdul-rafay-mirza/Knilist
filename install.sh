#!/usr/bin/env bash
# install.sh — installs Knilist using makepkg (no AUR helper required)
# Usage: bash install.sh

set -e

echo "==> Installing Knilist..."

# Check for required tools
if ! command -v git &>/dev/null; then
    echo "Error: git is not installed. Run: sudo pacman -S git"
    exit 1
fi

if ! command -v makepkg &>/dev/null; then
    echo "Error: makepkg is not available. Are you on Arch Linux?"
    exit 1
fi

# Create a temporary build directory
BUILDDIR="$(mktemp -d)"
trap 'rm -rf "$BUILDDIR"' EXIT

echo "==> Copying PKGBUILD to build directory..."
cp "$(dirname "$0")/PKGBUILD" "$BUILDDIR/"
cp "$(dirname "$0")/knilist.install" "$BUILDDIR/"

echo "==> Installing dependencies via pacman..."
cd "$BUILDDIR"
makepkg --syncdeps --noconfirm --noprogressbar 2>&1 | grep -v "^$"

echo "==> Installing package..."
sudo pacman -U --noconfirm knilist-git-*.pkg.tar.*

echo ""
echo "==> Knilist installed successfully!"
echo "    It should now appear in your application launcher."
