#!/usr/bin/env bash
# Ad-hoc signs the app and widget with their entitlements (so the sideloading
# tool knows they share an App Group), then zips them into an .ipa.
set -euo pipefail

APP="$1"
OUT="$2"
GROUP_ID=$(/usr/libexec/PlistBuddy -c "Print :AppGroupID" "$APP/Info.plist")

ents() {
  cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>application-identifier</key><string>$1</string>
  <key>com.apple.security.application-groups</key><array><string>$GROUP_ID</string></array>
</dict></plist>
PLIST
}

TMP=$(mktemp -d)
for APPEX in "$APP"/PlugIns/*.appex; do
  ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APPEX/Info.plist")
  ents "$ID" > "$TMP/widget.plist"
  codesign --force --sign - --entitlements "$TMP/widget.plist" "$APPEX"
done
ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
ents "$ID" > "$TMP/app.plist"
codesign --force --sign - --entitlements "$TMP/app.plist" "$APP"

mkdir -p "$TMP/Payload"
cp -R "$APP" "$TMP/Payload/"
(cd "$TMP" && zip -qry "ipa.zip" Payload)
mv "$TMP/ipa.zip" "$OUT"
echo "Wrote $OUT (App Group: $GROUP_ID)"
