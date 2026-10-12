#!/usr/bin/env bash
set -euo pipefail

# The isolated green branch always builds Google auth against the green API.
# Production/main keeps the existing password defaults.
if [ "${VERCEL_GIT_COMMIT_REF:-}" = "codex/wwtd-google-green" ]; then
  export API_BASE_URL="https://wwtd-api-green.onrender.com"
  export AUTH_MODE="google"
  export SUPABASE_URL="https://axffuusaaathvketrgzf.supabase.co"
  export SUPABASE_PUBLISHABLE_KEY="sb_publishable_KSoPSZcBjEfpItxR0QLHeQ_huLCfp-Q"
fi

if [ -z "${API_BASE_URL:-}" ]; then
  echo "ERROR: Set API_BASE_URL in Vercel → Project → Settings → Environment Variables"
  echo "Example: https://wwtd-api.onrender.com"
  exit 1
fi

FLUTTER_DIR="${FLUTTER_ROOT:-/tmp/flutter}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter (stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
  export PATH="$FLUTTER_DIR/bin:$PATH"
  flutter config --enable-web
  flutter precache --web
else
  export PATH="$(dirname "$(command -v flutter)"):$PATH"
fi

flutter --version
flutter pub get
flutter build web --release --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --dart-define="SUPABASE_URL=${SUPABASE_URL:-}" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY:-}" \
  --dart-define="AUTH_MODE=${AUTH_MODE:-password}" \
  --dart-define="AUTH_REDIRECT_URL=${AUTH_REDIRECT_URL:-}"
