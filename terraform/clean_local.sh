#!/usr/bin/env bash
set -euo pipefail

# clean_local.sh
# Supprime les fichiers locaux générés par Terraform et la clé SSH
     # chmod +x clean_local.sh
     # ./clean_local.sh






TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$TF_DIR"

FILES=(
  hadoop_ssh_key.pem
  hadoop_ssh_key.pub
  terraform.tfstate
  terraform.tfstate.backup
  .terraform
  .terraform.lock.hcl
  tfplan
  terraform.tfstate.backup
)

echo "This will remove the following files from: $TF_DIR"
for f in "${FILES[@]}"; do
  echo " - $f"
done

read -r -p "Continue and delete these files? (y/N): " answer
if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
  echo "Aborted. No files removed."
  exit 0
fi

for f in "${FILES[@]}"; do
  if [ -e "$f" ] || [ -L "$f" ]; then
    rm -rf "$f" && echo "Removed: $f"
  else
    echo "Not found: $f"
  fi
done

echo "Cleanup complete."
