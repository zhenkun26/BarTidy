# Roadmap

## BarTidy maintenance — 2026-11-15

Scope: finish the existing local fixes, make fork CI executable, and align the
application with manual updates. No upstream merge, dependency upgrade, app
installation, notarization, or release is included.

- Preserve the six local commits after `c3b5e10e` without rewriting them.
  Permission recovery is `2e870ac2`, non-prompting hover capture is `d49da114`,
  and cursor restoration is `401a32f9`; the preceding commits adapt docs and tests.
- Continue on `codex/bartidy-maintenance`, based on the complete repair branch.
  Integration remains `development`; publication and integration are separate steps.
- Add **BarTidy CI** with strict SwiftLint, resource checks, a Debug test build,
  six isolated regression suites, and an ad-hoc-signed Release build.
  Keep inherited upstream automation gated to Thaw.
- Disable update startup, consent, preferences, and menu actions when the bundled
  update configuration is unavailable. Show manual-update instructions instead.
- Isolate the Debug test host from the menu bar application and preserve scratch
  preferences. Keep the full filesystem-mutating test suite outside the scoped run.

Verification: SwiftLint 0.63.3 passed for all 246 production Swift files. Resource
JSON/plist, scheme XML, workflow YAML, shell syntax, the tracked SwiftLint input
list, and diff whitespace checks passed. Debug app/test compilation and universal
Release compilation passed with Xcode 26.6. Both products have the BarTidy bundle
identity and disabled update configuration.

After user-granted Documents-folder access, final focused validation passed:
**62 tests in six suites, zero failures and zero skips**. The script's result-bundle
check also passed. A launch-environment inheritance issue found during validation
was corrected: TestAction now explicitly uses its own environment, the script
checks it before launch, and a regression test verifies the isolated host and
scratch-data retention. The final Release build passed for arm64 and x86_64.
Hosted CI has not run for this branch.

Delivery: completed as a local maintenance increment on
`codex/bartidy-maintenance`; not pushed. Publishing the branch requires separate
authorization, and merging into `development` requires review. No installation,
upstream merge, or release has occurred.

Remaining acceptance: interactive permission recovery/revocation, real cursor
interruption, multiple displays, sleep/wake, and sustained memory/CPU measurements
for the teamless capture path. Stable signing and distribution remain separate work.

## Upstream Thaw roadmap (reference)

Near-term direction (roughly the next year): keep Thaw compatible with current
macOS releases, and harden release and contribution practices. Items may slip;
the list is intent, not a contract.

## Menu bar item management

- Temporarily show individual menu bar items

## Menu bar appearance

- Rounded screen corners

## Integrations

- Official Alfred workflow. The `thaw://` scheme already works with Alfred today
  (see [URI schemes](URI_SCHEMES.md)); this covers a packaged, installable workflow

## Other

- Menu bar widgets

## Shipped in 2.1.0

These were on the list above until 2.1.0 took them off it:

- Individual spacer items
- Menu bar item groups
- Show menu bar items when trigger conditions are met
- A hotkey to enable and disable auto-rehide

## Suggesting changes

Roadmap items are tracked as issues. To propose something, open a
[feature request](https://github.com/thaw-app/Thaw/issues/new/choose) or start with
[Ways to contribute](https://github.com/thaw-app/Thaw/issues/316).
