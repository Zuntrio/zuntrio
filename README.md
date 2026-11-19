# Zuntrio

Zuntrio is a free, open-source window manager for macOS. You move and resize windows with
keyboard shortcuts. It is inspired by [Spectacle](https://github.com/eczarny/spectacle), which
is no longer maintained, and keeps the same keyboard-first workflow.

> **Status: early development.** All Spectacle window actions, including undo/redo, work with
> configurable shortcuts. Multi-display testing is still in progress. No release has been published.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon. The build is Universal (Apple Silicon and Intel), but it has not been tested
  on Intel hardware yet.

## Accessibility permission

Zuntrio needs **Accessibility** access to move and resize other apps' windows. Choose
**Grant Accessibility Access…** from the Zuntrio menu-bar item, or open
**System Settings → Privacy & Security → Accessibility** and turn on Zuntrio.

Zuntrio uses this access only to read and set the position and size of the focused window.

## Launch at login

Turn on **Launch Zuntrio at login** in Settings. It is off by default.

## Privacy

- Zuntrio makes no network connections.
- It has no telemetry, analytics or account.
- It never reads or stores window titles, document names, keystrokes or app activity.
- Settings stay on your Mac.

## Shortcuts

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

- Pressing a half or corner shortcut repeatedly cycles the size ½ → ⅔ → ⅓.
- Next/Previous Third steps through three columns, then three rows.
- Moving to another display keeps the window's relative position and size.
- Undo/Redo is kept separately for each window, up to 50 steps. It is cleared when Zuntrio quits.
- In **Settings…** (in the Zuntrio menu) you can:
  - record your own shortcut for any action (Esc cancels, ⌫ clears);
  - turn individual shortcuts on or off;
  - restore the defaults;
  - switch to the **Alternative (⌃⌥)** preset, which leaves ⌥⌘←/→ free for browsers' tab switching.
- Every shortcut must include ⌘ or ⌃.
- Zuntrio warns when a shortcut is already taken by another app or may clash with a macOS
  keyboard shortcut.

Alternative preset:

| Action | Shortcut |
|---|---|
| Center / Maximize | ⌃⌥C / ⌃⌥↩ |
| Left / Right / Top / Bottom half | ⌃⌥← / ⌃⌥→ / ⌃⌥↑ / ⌃⌥↓ |
| Upper left / Upper right / Lower left / Lower right | ⌃⌥U / ⌃⌥I / ⌃⌥J / ⌃⌥K |
| Next / Previous third | ⌃⌥⇧→ / ⌃⌥⇧← |
| Larger / Smaller | ⌃⌥= / ⌃⌥- |
| Next / Previous display | ⌃⌥⌘→ / ⌃⌥⌘← |
| Undo / Redo | ⌃⌥Z / ⌃⌥⇧Z |

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
