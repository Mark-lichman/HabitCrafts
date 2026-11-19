#!/usr/bin/env bash
# Build the side-by-side "HabitCraft QR" APK (com.reddevinc.habitcrafts.quietroom).
#
# The install on Mark's phone uses this app id and is signed with this machine's
# debug key, so an update must match both. Three files are edited for the build and
# ALWAYS restored afterwards, even on failure: never commit them.
#   android/app/build.gradle             applicationId -> .quietroom
#   android/app/src/main/AndroidManifest label -> HabitCraft QR
#   android/app/google-services.json     + a client for the .quietroom package
# Run from the repo root: bash pipeline/jp/build_qr_apk.sh
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
FILES=(android/app/build.gradle android/app/src/main/AndroidManifest.xml android/app/google-services.json)
BAK="$(mktemp -d)"
for f in "${FILES[@]}"; do cp "$f" "$BAK/$(basename "$f")"; done
restore() { for f in "${FILES[@]}"; do cp "$BAK/$(basename "$f")" "$f"; done; echo "restored build files"; }
trap restore EXIT

python - <<'PY'
import copy, json
p = 'android/app/build.gradle'; s = open(p, encoding='utf-8').read()
s = s.replace('applicationId "com.reddevinc.habitcrafts"', 'applicationId "com.reddevinc.habitcrafts.quietroom"', 1)
open(p, 'w', encoding='utf-8').write(s)
p = 'android/app/src/main/AndroidManifest.xml'; s = open(p, encoding='utf-8').read()
s = s.replace('android:label="HabitCraft"', 'android:label="HabitCraft QR"', 1)
open(p, 'w', encoding='utf-8').write(s)
p = 'android/app/google-services.json'; d = json.load(open(p))
c = copy.deepcopy(d['client'][0])
c['client_info']['android_client_info']['package_name'] = 'com.reddevinc.habitcrafts.quietroom'
# Web OAuth client only: the Android OAuth entries are tied to the original package's SHA-1.
c['oauth_client'] = [o for o in c.get('oauth_client', []) if o.get('client_type') == 3]
d['client'].append(c); json.dump(d, open(p, 'w'), indent=2)
PY

FLUTTER="${FLUTTER:-/c/src/flutter/bin/flutter}"
"$FLUTTER" build apk --release
echo "APK: $ROOT/build/app/outputs/flutter-apk/app-release.apk"
