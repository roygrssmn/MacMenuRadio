#!/bin/sh
set -eu
cd -P -- "$(dirname -- "$0")"
mkdir -p build/module-cache
xcrun swiftc -swift-version 6 -parse-as-library \
    -module-cache-path "$PWD/build/module-cache" \
    Stations.swift Tests/StationsCheck.swift -o build/stations-check
set -- "$PWD/stations.json.example"
if [ -f stations.json ]; then
    set -- "$@" "$PWD/stations.json"
fi
./build/stations-check "$@"
xcrun swiftc -swift-version 6 -parse-as-library -D RADIO_DIAGNOSTICS \
    -module-cache-path "$PWD/build/module-cache" \
    MacMenuRadio.swift Stations.swift Tests/PlayerRecoveryCheck.swift -o build/player-recovery-check
./build/player-recovery-check
