#!/usr/bin/env bash
# uninstall.sh — removes Knilist
# Saved credentials are cleaned up automatically by the package's
# post_remove hook (see knilist.install), so no extra keyring logic
# is needed here.

set -e

sudo pacman -R knilist-git

echo "==> Knilist removed."
