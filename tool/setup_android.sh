#!/usr/bin/env bash
# Generates the android/ folder (not committed in this zip) and adds the
# INTERNET permission, which Flutter only adds for debug builds by default.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d android ]; then
  flutter create --platforms=android --org com.friday --project-name friday .
fi
M=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$M"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$M"
fi
# flutter_secure_storage needs minSdk 23+
for G in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$G" ] && sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 26/; s/minSdkVersion flutter.minSdkVersion/minSdkVersion 26/' "$G"
done
echo "android/ ready"
