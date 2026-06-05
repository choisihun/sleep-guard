#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 user@host [remote_dir]" >&2
  exit 2
fi

host="$1"
remote_dir="${2:-/opt/sleepguard-webhook}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"

rsync -az --delete --exclude ".env" "$project_dir/" "$host:$remote_dir/"
ssh "$host" "sudo systemctl restart sleepguard-webhook.service && systemctl is-active sleepguard-webhook.service"
