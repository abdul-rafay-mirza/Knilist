#!/usr/bin/env bash
# uninstall.sh — completely removes Knilist including saved credentials

sudo pacman -R knilist-git

python -c "
import keyring
for key in ['token', 'user_id', 'username']:
    try:
        keyring.delete_password('knilist', key)
    except:
        pass
"

echo "==> Knilist and all saved credentials removed."