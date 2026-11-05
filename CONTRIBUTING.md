# Contributing

Create a feature branch and submit a pull request for review. Keep changes focused and explain the user-visible behavior and how you checked it.

## Preconditions

Use macOS with Xcode or Xcode Command Line Tools providing a Swift 6 compiler and a macOS SDK. Build with `/bin/sh ./build.sh`. The script produces arm64 and x86_64 slices.

## Verification

Run `/bin/sh ./check.sh` for configuration and recovery checks, then build the app. The `.github/workflows/ci.yml` workflow runs these checks and the universal build on Apple Silicon and Intel macOS runners for pushes and pull requests. Check Play, Stop, station switching while playing, volume changes, and saved preferences after relaunch. Test connection failures and any behavior affected by your change. State which macOS version and architecture you tested.

Keep your own stations in the Git-ignored `stations.json`. Pull requests may change the shared `stations.json.example` when appropriate. CI rejects a tracked personal `stations.json`. Station configuration changes should use stable, unique IDs and absolute HTTPS audio stream URLs. Keep credentials, private URLs, and broadcaster logos out of contributions. Confirm that proposed streams are appropriate to share and describe their source in the pull request.

## Licensing

Submit code, documentation, and artwork that you have the right to contribute. Unless explicitly stated otherwise, contributions submitted for inclusion are provided under the project's MIT license. Retain any required third-party notices and identify third-party material in your pull request.

## Conduct

Be respectful, focus feedback on the work, and avoid sharing anyone's private information.
