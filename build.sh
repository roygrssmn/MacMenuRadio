#!/bin/sh
set -eu
cd -P -- "$(dirname -- "$0")"

if ! command -v xcrun >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
    echo 'Install Xcode or the Xcode Command Line Tools with a Swift 6 compiler first.' >&2
    exit 1
fi

stations=stations.json.example
if [ -f stations.json ]; then
    stations=stations.json
fi

app="$PWD/build/MacMenuRadio.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$PWD/build/module-cache"
for arch in arm64 x86_64; do
    xcrun swiftc -swift-version 6 -O -parse-as-library \
        -target "$arch-apple-macosx13.0" \
        -module-cache-path "$PWD/build/module-cache" \
        MacMenuRadio.swift Stations.swift -o "$PWD/build/MacMenuRadio-$arch"
done
xcrun lipo -create build/MacMenuRadio-arm64 build/MacMenuRadio-x86_64 \
    -output "$app/Contents/MacOS/MacMenuRadio"
cp Info.plist "$app/Contents/Info.plist"
cp "$stations" "$app/Contents/Resources/stations.json"
cp LICENSE PRIVACY.md NOTICE.md "$app/Contents/Resources/"
codesign --force --sign - "$app"
echo "Built $app"
