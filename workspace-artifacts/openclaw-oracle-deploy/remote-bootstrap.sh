#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash remote-bootstrap.sh ./deploy.env" >&2
  exit 1
fi

ENV_FILE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

export DEBIAN_FRONTEND=noninteractive

required_vars=(
  TAILSCALE_AUTHKEY
  OPENROUTER_API_KEY
  OPENROUTER_MODEL
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required variable: $var_name" >&2
    exit 1
  fi
done

if [[ "$OPENROUTER_MODEL" == "openrouter/REPLACE_WITH_EXACT_OPENROUTER_MODEL_SLUG" ]]; then
  echo "OPENROUTER_MODEL still has the placeholder value." >&2
  exit 1
fi

if [[ "${ENABLE_MEMORY_LANCEDB:-0}" == "1" && -z "${MEMORY_EMBEDDINGS_API_KEY:-}" ]]; then
  echo "ENABLE_MEMORY_LANCEDB=1 requires MEMORY_EMBEDDINGS_API_KEY." >&2
  exit 1
fi

sudo apt update
sudo apt upgrade -y
sudo apt install -y build-essential curl ca-certificates git jq

sudo hostnamectl set-hostname "${OPENCLAW_HOSTNAME:-openclaw}"
sudo loginctl enable-linger "$USER"

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

sudo tailscale up \
  --authkey "$TAILSCALE_AUTHKEY" \
  --ssh \
  --hostname "${TAILSCALE_HOSTNAME:-openclaw}"

if ! command -v openclaw >/dev/null 2>&1; then
  curl -fsSL https://openclaw.ai/install.sh | bash
fi

if [[ -f "$HOME/.bashrc" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.bashrc"
fi

mkdir -p "$HOME/.openclaw"

if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.bak.$(date +%Y%m%d%H%M%S)"
fi

if [[ "${ENABLE_WHATSAPP:-0}" == "1" ]]; then
  echo ""
  echo "Installing WhatsApp plugin..."
  openclaw plugins install @openclaw/whatsapp
  openclaw plugins enable whatsapp
fi

if [[ "${ENABLE_MEMORY_LANCEDB:-0}" == "1" ]]; then
  echo ""
  echo "Installing memory-lancedb plugin..."
  openclaw plugins install @openclaw/memory-lancedb
  openclaw plugins enable memory-lancedb
fi

node "$SCRIPT_DIR/render-config.mjs"

chmod 600 "$HOME/.openclaw/openclaw.json"

systemctl --user daemon-reload || true
systemctl --user restart openclaw-gateway

echo
echo "Verification"
echo "============"
openclaw --version
openclaw plugins list || true
systemctl --user --no-pager --full status openclaw-gateway || true
tailscale serve status || true
curl -fsS http://127.0.0.1:18789 | head -c 200 || true
echo

if [[ "${ENABLE_WHATSAPP:-0}" == "1" ]]; then
  echo ""
  echo "WhatsApp is installed but not yet linked."
  echo "To link WhatsApp, SSH back in and run:"
  echo ""
  echo "  openclaw channels login --channel whatsapp"
  echo ""
  echo "Then scan the QR code from your phone."
  echo ""
fi

echo "Next manual step: lock down Oracle VCN ingress to Tailscale only."
