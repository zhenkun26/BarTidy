#!/usr/bin/env bash
# Build the actual app/test bundle and run only the non-destructive regression
# suites. TestAction selects a host without AppState and retains scratch defaults.
# Permission/cursor/capture checks use injected behavior, not desktop automation.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="${1:?Usage: bash scripts/test-bartidy.sh /absolute/path/to/derived-data}"
if [[ "$derived_data" != /* ]]; then
  echo 'Derived data must use an absolute path.' >&2
  exit 2
fi
packages="${BARTIDY_PACKAGE_CACHE:-$derived_data/SourcePackages}"
result_bundle="$derived_data/Results-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
cd "$root"

# Refuse to launch a host that would inherit ordinary app settings or clean up
# scratch domains. Checking after execution is too late to prevent side effects.
python3 - <<'PY'
import xml.etree.ElementTree as ET
scheme = ET.parse('Thaw.xcodeproj/xcshareddata/xcschemes/Thaw.xcscheme')
action = scheme.find('TestAction')
assert action is not None and action.get('shouldUseLaunchSchemeArgsEnv') == 'NO', 'TestAction must use its own environment'
environment = {
    item.get('key'): item.get('value')
    for item in action.findall('./EnvironmentVariables/EnvironmentVariable')
    if item.get('isEnabled') == 'YES'
}
assert environment.get('BARTIDY_UNIT_TEST_HOST') == '1', 'Isolated test host is required'
assert environment.get('BARTIDY_RETAIN_TEST_ARTIFACTS') == '1', 'Scratch-data retention is required'
PY

xcodebuild test \
  -project Thaw.xcodeproj -scheme Thaw -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$packages" \
  -onlyUsePackageVersionsFromResolvedFile \
  -resultBundlePath "$result_bundle" \
  -parallel-testing-enabled NO -enableCodeCoverage NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 60 -maximum-test-execution-time-allowance 120 \
  -only-testing:ThawTests/CursorRestorationSessionTests \
  -only-testing:ThawTests/MouseHelpersCursorPointTests \
  -only-testing:ThawTests/PermissionTests \
  -only-testing:ThawTests/MenuBarCaptureServiceTests \
  -only-testing:ThawTests/UpdatesManagerTests \
  -only-testing:ThawTests/MacOSCompatibilityWarningTests \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES

# An empty selection can make xcodebuild succeed without testing anything.
# Check the result bundle instead of treating exit status alone as acceptance.
xcrun xcresulttool get test-results summary --path "$result_bundle" > "$result_bundle.summary.json"
python3 - "$result_bundle.summary.json" <<'PY'
import json, sys
with open(sys.argv[1]) as source:
    result = json.load(source)
total = result['totalTestCount']
passed = result['passedTests']
assert total > 0, 'No regression tests ran'
assert passed == total, f'Only {passed}/{total} regression tests passed'
assert result['failedTests'] == 0 and result['skippedTests'] == 0, result
print(f'BarTidy regression tests: {passed}/{total} passed, none skipped')
PY
