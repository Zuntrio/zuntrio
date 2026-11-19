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
- **No false success:** read the window frame back after setting it, and report any mismatch
  or error.
- **Privacy:** no network access, telemetry or analytics. Never log window titles, document
  names, app names or keystrokes.
- **Code safety:** no force unwraps, `try!` or empty `catch` blocks in app code.
- **Dependencies:** keep them to a minimum. Discuss any new one in an issue first.
- **Assets:** don't copy code or assets from other projects without a licence check. Spectacle's
  artwork must not be used.

## Pull requests

- Keep each pull request small and focused.
- Describe what changed, why, and how you tested it.
- Make sure `swift test --package-path ZuntrioCore` and the Debug build pass.
