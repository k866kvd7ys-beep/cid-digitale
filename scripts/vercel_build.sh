#!/usr/bin/env bash
set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"

flutter config --enable-web
flutter pub get
flutter build web --release --dart-define=GOOGLE_PLACES_API_KEY=$GOOGLE_PLACES_API_KEY
