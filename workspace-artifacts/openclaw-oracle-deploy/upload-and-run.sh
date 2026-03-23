#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash upload-and-run.sh /path/to/deploy.env" >&2
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

required_vars=(
  ORACLE_HOST
  ORACLE_USER
  SSH_PRIVATE_KEY
  TAILSCALE_AUTHKEY
  OPENROUTER_API_KEY
  OPENROUTER_MODEL
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required variable in env file: $var_name" >&2
    exit 1
  fi
done

if [[ "$OPENROUTER_MODEL" == "openrouter/REPLACE_WITH_EXACT_OPENROUTER_MODEL_SLUG" ]]; then
  echo "OPENROUTER_MODEL still has the placeholder value. Replace it with the exact OpenRouter model ref." >&2
  exit 1
fi

if [[ ! -f "$SSH_PRIVATE_KEY" ]]; then
  echo "SSH private key not found: $SSH_PRIVATE_KEY" >&2
  exit 1
fi

REMOTE_DIR="~/openclaw-oracle-deploy"

echo "Uploading deployment bundle to ${ORACLE_USER}@${ORACLE_HOST}..."
ssh -i "$SSH_PRIVATE_KEY" -o StrictHostKeyChecking=accept-new "$ORACLE_USER@$ORACLE_HOST" "mkdir -p $REMOTE_DIR"

scp -i "$SSH_PRIVATE_KEY" \
  -o StrictHostKeyChecking=accept-new \
  "$SCRIPT_DIR/remote-bootstrap.sh" \
  "$SCRIPT_DIR/render-config.mjs" \
  "$ENV_FILE" \
  "$ORACLE_USER@$ORACLE_HOST:$REMOTE_DIR/"

echo "Running remote bootstrap..."
ssh -i "$SSH_PRIVATE_KEY" \
  -o StrictHostKeyChecking=accept-new \
  "$ORACLE_USER@$ORACLE_HOST" \
  "cd $REMOTE_DIR && chmod +x remote-bootstrap.sh && bash ./remote-bootstrap.sh ./$(basename "$ENV_FILE")"

echo "Deployment finished. Reconnect using Tailscale after VCN lock-down."
