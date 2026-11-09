#!/bin/zsh
# Runs every check for a phase report:
#   ./scripts/test.sh           format lint + RunKit tests + app build and app tests
#   ./scripts/test.sh --fast    format lint + RunKit tests only (seconds)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ Lint (swift format)"
swift format lint --strict --recursive RunKit/Sources RunKit/Tests RunWalk RunWalkTests

echo "▸ RunKit tests"
(cd RunKit && swift test 2>&1 | grep -E "✘|error:|Test run with")

[[ "${1:-}" == "--fast" ]] && exit 0

DEVICE_NAME="${RUNWALK_TEST_DEVICE:-iPhone 17 Pro}"
DEVICE_ID=$(xcrun simctl list devices available | grep -m1 "$DEVICE_NAME (" | grep -oE '[0-9A-F-]{36}')
[[ -n "$DEVICE_ID" ]] || { echo "No simulator named $DEVICE_NAME"; exit 1; }

echo "▸ App build + tests on $DEVICE_NAME"
xcodegen generate -q
xcodebuild -project RunWalk.xcodeproj -scheme RunWalk \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath build-test \
  -only-testing:RunWalkTests test 2>&1 \
  | grep -E "error:|warning: .*(Sendable|concurrency)|recorded an issue|Test Case.*failed|Test run with|TEST SUCCEEDED|TEST FAILED"
