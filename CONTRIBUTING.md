# Contributing to Zuntrio

Thanks for your interest!

Zuntrio is in early development. Please open an issue to discuss a change before starting
large work.

## Setup

- Xcode 27 or later, on macOS 26.6 or later
- XcodeGen: `brew install xcodegen`

```sh
xcodegen generate   # creates Zuntrio.xcodeproj from project.yml (not committed)
```

## Build and test

```sh
# Pure logic tests: no display or permissions needed
swift test --package-path ZuntrioCore

# App build (Debug)
xcodebuild -project Zuntrio.xcodeproj -scheme Zuntrio -configuration Debug build

# Universal Release build
xcodebuild -project Zuntrio.xcodeproj -scheme Zuntrio -configuration Release \
  -destination 'generic/platform=macOS' build

# All tests through the Xcode scheme
xcodebuild -project Zuntrio.xcodeproj -scheme Zuntrio -destination 'platform=macOS' test
```

Local builds are ad-hoc signed by default. macOS ties the Accessibility grant to the code
signature, so after an ad-hoc rebuild you may have to turn Zuntrio off and on again in
System Settings → Privacy & Security → Accessibility.

To keep the grant across rebuilds, sign with a stable identity from your keychain. A
self-signed code-signing certificate works for local development:

```sh
xcodebuild -project Zuntrio.xcodeproj -scheme Zuntrio -configuration Debug \
  CODE_SIGN_IDENTITY="<your identity name>" build
```

## Debug test harness

Debug builds accept a few launch arguments for repeatable checks without touching your own
windows. Launch them with `open` so macOS applies Zuntrio's Accessibility permission (not
your terminal's):

```sh
APP=build/DerivedData/Build/Products/Debug/Zuntrio.app   # with -derivedDataPath build/DerivedData
open -n -g "$APP" --args --poc-fixture-host                # a test window with min/max size, in its own process
open -n -g "$APP" --args --poc-run leftHalf,maximize,undo \
  --poc-target-pid <test window pid> --poc-output /tmp/result.json --poc-restore
```

- `--poc-fixture-kind panel|dialog|minimized|sheet|ignore|ignore-later|delayed` shows window
  types that Zuntrio should refuse or handle specially. `delayed` reports its old frame for
  40 ms after a change; add `--poc-no-settle` to compare results without the second read.
- `--poc-fixture-hang <delay>,<seconds>` simulates an app that stops responding.
- Results are JSON with geometry only.
- Never point the harness at a window you are working in.

## Project layout

- `ZuntrioCore/` is a Swift package with no AppKit or Accessibility API use. It holds layout
  geometry, coordinate conversion and display selection.
- `App/Sources/` is the macOS app:
  - menu-bar UI
  - permission handling
  - Accessibility window access
  - display enumeration
  - global shortcuts
- `project.yml` is the XcodeGen project definition.

## Guidelines

- **Tests:** every change to `ZuntrioCore` needs unit tests. For behaviour that depends on
  macOS (window moves, permissions, displays), describe how you tested it: app, macOS version,
  Mac model and display setup.
- **Compatibility reports are especially welcome:** macOS 14, 15 and 26, Intel Macs, and apps
  that don't move as expected.
- **No false success:** read the window frame back after setting it, and report any mismatch
  or error.
- **Privacy:** no telemetry or analytics, and no network access apart from the opt-in update
  check (`App/Sources/Updates/`), which sends nothing about the user or the Mac. Never log window titles, document
  names, app names or keystrokes.
- **Code safety:** no force unwraps, `try!` or empty `catch` blocks in app code.
- **Dependencies:** keep them to a minimum. Discuss any new one in an issue first.
- **Assets:** don't copy code or assets from other projects without a licence check. Spectacle's
  artwork must not be used.

## Pull requests

Every pull request runs the **CI** checks (GitHub Actions): unit tests, the Xcode scheme's tests and a
Universal Release build, plus checks that the Release app is Universal and contains no debug code.
The check must pass before a pull request can be merged.

- Keep each pull request small and focused.
- Describe what changed, why, and how you tested it.
- Make sure `swift test --package-path ZuntrioCore` and the Debug build pass.

## Releases (maintainers)

Releases are built locally with Xcode 27 by `scripts/release.sh`, which needs a Developer ID identity
and a notarytool keychain profile. Run `scripts/release.sh` without arguments for details.

```sh
scripts/release.sh prepare 0.1.0-beta.2   # bump project.yml on a branch, open a pull request
scripts/release.sh check 0.1.0-beta.2     # optional dry run on main: tests, signed build, checks
scripts/release.sh build 0.1.0-beta.2     # after the pull request is merged: notarize, draft release
```

The GitHub release stays a draft until a maintainer publishes it.
