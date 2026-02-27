#!/usr/bin/env bash
set -euo pipefail

# Persisted credential file (first run prompts once)
CONFIG_DIR="${HOME}/.config/bits-keepalive"
CREDENTIALS_FILE="${CONFIG_DIR}/credentials.env"

# BITS login endpoint (used to refresh session when needed)
LOGIN_URL="https://fw.bits-pilani.ac.in:8090/login.xml"
USERNAME_FIELD="username"
PASSWORD_FIELD="password"
EXTRA_LOGIN_FIELDS=("mode=191")

# BITS Wi-Fi keepalive URL
KEEPALIVE_URL="https://fw.bits-pilani.ac.in:8090/keepalive?0d05070d0d020f02"

# Hit every 5 seconds (very low CPU; process sleeps between requests)
INTERVAL_SECONDS=5

# Optional: if cert validation fails on campus firewall cert, set to true
INSECURE_TLS=false
PRINT_RESPONSE_BODY=true

RUN_ONCE=false
SETUP_ONLY=false
RESET_CREDENTIALS=false

usage() {
  cat <<'EOF'
Usage: ./bits_keepalive.sh [--once] [--setup] [--reset]

Options:
  --once    Run a single keepalive cycle and exit
  --setup   Prompt for username/password, save, and exit
  --reset   Delete saved credentials and prompt again
  -h,--help Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --once)
      RUN_ONCE=true
      ;;
    --setup)
      SETUP_ONLY=true
      ;;
    --reset)
      RESET_CREDENTIALS=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

load_or_create_credentials() {
  mkdir -p "$CONFIG_DIR"

  if [[ "$RESET_CREDENTIALS" == true ]]; then
    rm -f "$CREDENTIALS_FILE"
  fi

  if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    local username password
    echo "First-time setup: enter BITS credentials (saved locally for reuse)."
    read -r -p "BITS username: " username
    read -r -s -p "BITS password: " password
    echo

    if [[ -z "$username" || -z "$password" ]]; then
      echo "Username/password cannot be empty." >&2
      exit 2
    fi

    umask 077
    {
      printf 'BITS_USERNAME=%q\n' "$username"
      printf 'BITS_PASSWORD=%q\n' "$password"
    } > "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    echo "Saved credentials at: $CREDENTIALS_FILE"
  fi

  # shellcheck source=/dev/null
  source "$CREDENTIALS_FILE"

  if [[ -z "${BITS_USERNAME:-}" || -z "${BITS_PASSWORD:-}" ]]; then
    echo "Saved credentials are invalid. Run with --reset." >&2
    exit 2
  fi
}

curl_keepalive() {
  local rc=0
  local body=""
  local countdown_raw=""
  local countdown_seconds=0
  if [[ "$INSECURE_TLS" == true ]]; then
    if body="$(curl -ksS --max-time 10 "$KEEPALIVE_URL")"; then
      if [[ "$PRINT_RESPONSE_BODY" == true ]]; then
        echo "----- keepalive response begin -----"
        printf '%s\n' "$body"
        echo "----- keepalive response end -------"
      fi
      if [[ "$body" =~ countDownTime[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
        countdown_raw="${BASH_REMATCH[1]}"
        countdown_seconds="$countdown_raw"
        if [[ "$countdown_seconds" -eq 14401 ]]; then
          countdown_seconds=14400
        fi
        if [[ "$countdown_seconds" -ge 14400 ]]; then
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] Timer refresh confirmed at ${countdown_seconds}s."
        else
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] Timer present but below 14400s (${countdown_seconds}s)."
        fi
      fi
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Keepalive refresh request succeeded."
      return 0
    else
      rc=$?
    fi
  else
    if body="$(curl -sS --max-time 10 "$KEEPALIVE_URL")"; then
      if [[ "$PRINT_RESPONSE_BODY" == true ]]; then
        echo "----- keepalive response begin -----"
        printf '%s\n' "$body"
        echo "----- keepalive response end -------"
      fi
      if [[ "$body" =~ countDownTime[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
        countdown_raw="${BASH_REMATCH[1]}"
        countdown_seconds="$countdown_raw"
        if [[ "$countdown_seconds" -eq 14401 ]]; then
          countdown_seconds=14400
        fi
        if [[ "$countdown_seconds" -ge 14400 ]]; then
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] Timer refresh confirmed at ${countdown_seconds}s."
        else
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] Timer present but below 14400s (${countdown_seconds}s)."
        fi
      fi
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Keepalive refresh request succeeded."
      return 0
    else
      rc=$?
    fi
  fi

  # Some captive portal endpoints may close without body (curl 52).
  [[ "$rc" -eq 52 ]]
}

submit_login() {
  local curl_args=(
    -s
    --max-time 12
    --data-urlencode "${USERNAME_FIELD}=${BITS_USERNAME}"
    --data-urlencode "${PASSWORD_FIELD}=${BITS_PASSWORD}"
  )

  local field
  for field in "${EXTRA_LOGIN_FIELDS[@]}"; do
    curl_args+=(--data-urlencode "$field")
  done

  local rc=0
  if [[ "$INSECURE_TLS" == true ]]; then
    if curl -k "${curl_args[@]}" "$LOGIN_URL" >/dev/null; then
      return 0
    else
      rc=$?
    fi
  else
    if curl "${curl_args[@]}" "$LOGIN_URL" >/dev/null; then
      return 0
    else
      rc=$?
    fi
  fi

  # Accept empty reply as non-fatal for this gateway style endpoint.
  [[ "$rc" -eq 52 ]]
}

load_or_create_credentials

if [[ "$SETUP_ONLY" == true ]]; then
  echo "Credentials are configured."
  exit 0
fi

echo "Starting keepalive loop (interval: ${INTERVAL_SECONDS}s)..."

# Best-effort login once at startup (ignored if already logged in)
submit_login || true

while true; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sending keepalive refresh request..."
  if ! curl_keepalive; then
    # If keepalive fails, try refreshing login once and continue.
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Keepalive failed. Refreshing portal login..."
    submit_login || true
    curl_keepalive || true
  fi

  if [[ "$RUN_ONCE" == true ]]; then
    echo "Run-once complete."
    exit 0
  fi

  sleep "$INTERVAL_SECONDS"
done
