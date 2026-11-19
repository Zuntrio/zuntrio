# Zuntrio

Zuntrio is a free, open-source window manager for macOS. You move and resize windows with
keyboard shortcuts. It is inspired by [Spectacle](https://github.com/eczarny/spectacle), which
is no longer maintained, and keeps the same keyboard-first workflow.

> **Status: early development.** The current build is a technical proof of concept with three
> actions (Left Half, Maximize, Center). It is not ready for everyday use yet, and no release
> has been published.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon. The build is Universal (Apple Silicon and Intel), but it has not been tested
  on Intel hardware yet.

## Accessibility permission

Zuntrio needs **Accessibility** access to move and resize other apps' windows. Choose
**Grant Accessibility Access…** from the Zuntrio menu-bar item, or open
**System Settings → Privacy & Security → Accessibility** and turn on Zuntrio.

Zuntrio uses this access only to read and set the position and size of the focused window.

## Privacy

- Zuntrio makes no network connections.
- It has no telemetry, analytics or account.
- It never reads or stores window titles, document names, keystrokes or app activity.
- Settings stay on your Mac.

## Planned shortcuts

The defaults match Spectacle's, so former Spectacle users can keep their muscle memory.

| Action | Shortcut |
|---|---|
| Center | ⌥⌘C |
| Maximize | ⌥⌘F |
| Left / Right half | ⌥⌘← / ⌥⌘→ |
| Top / Bottom half | ⌥⌘↑ / ⌥⌘↓ |
| Upper left / Upper right | ⌃⌘← / ⌃⌘→ |
| Lower left / Lower right | ⌃⇧⌘← / ⌃⇧⌘→ |
| Next / Previous third | ⌃⌥→ / ⌃⌥← |
| Larger / Smaller | ⌃⌥⇧→ / ⌃⌥⇧← |
| Next / Previous display | ⌃⌥⌘→ / ⌃⌥⌘← |
| Undo / Redo | ⌥⌘Z / ⌥⇧⌘Z |

- Pressing a half shortcut repeatedly cycles the width ½ → ⅔ → ⅓.
- Only **⌥⌘← Left Half** works in the current proof of concept.
- An alternative ⌃⌥-based preset is planned, because ⌥⌘←/→ also switch tabs in most browsers.

## Building from source

You need Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Zuntrio.xcodeproj -scheme Zuntrio -configuration Debug build
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests and development notes.

## Licence

MIT. See [LICENSE](LICENSE).

Zuntrio is an independent project. It is not affiliated with or endorsed by Spectacle or its author.
