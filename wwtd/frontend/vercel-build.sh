#!/usr/bin/env bash
set -euo pipefail

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
flutter build web --release --dart-define="API_BASE_URL=${API_BASE_URL}"
