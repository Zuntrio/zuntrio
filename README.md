# Zuntrio

Zuntrio is a free, open-source window manager for macOS. Move and resize windows with
keyboard shortcuts: halves, thirds, corners, maximize, center, and moving windows between
displays.

It is inspired by [Spectacle](https://github.com/eczarny/spectacle), which is no longer
maintained, and uses the same default shortcuts, so former Spectacle users can keep their
muscle memory.

> **Status: beta in preparation.** No release has been published yet.

## Why Zuntrio

Spectacle made it effortless to arrange windows without reaching for the mouse: a few
memorable shortcuts, no setup, nothing in the way. Many people still use it every day. But
its repository is archived, and its last release (2017) predates Apple Silicon, so it runs
through Rosetta. Apple has announced that general Rosetta support ends after macOS 27.

Zuntrio exists so that workflow doesn't disappear. It aims to be:

- **familiar:** the same actions and default shortcuts as Spectacle;
- **native and maintained:** a modern Swift app for Apple Silicon and Intel, built for
  current versions of macOS;
- **free and open:** no subscription, account, ads or paywall, and MIT-licensed source;
- **trustworthy:** no network access or telemetry, and it tells you honestly when an app
  won't let a window move.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel (Universal app). See [Compatibility](#compatibility) for what has
  actually been tested.

## Install

1. Download `Zuntrio.zip` from the [Releases](https://github.com/Zuntrio) page *(available
   with the first beta)*.
2. Unzip it and move **Zuntrio** to your **Applications** folder.
3. Open Zuntrio. Its icon appears in the menu bar. There is no Dock icon.
4. Grant Accessibility access when asked (see below).

To build it yourself, see [Building from source](#building-from-source).

## Accessibility permission

macOS only lets one app move another app's windows with **Accessibility** access. On first
launch, Zuntrio opens a short welcome window that explains this and links to the right
place in System Settings:

**System Settings → Privacy & Security → Accessibility → turn on Zuntrio**

Zuntrio uses this access only to read and change the position and size of the window you
are working in. You can revoke it at any time. Zuntrio notices, dims its menu-bar icon,
and shows the welcome window again the next time you use a shortcut.

## Shortcuts

| Action | Default (Spectacle) | Alternative (⌃⌥) |
|---|---|---|
| Center | ⌥⌘C | ⌃⌥C |
| Maximize | ⌥⌘F | ⌃⌥↩ |
| Left / Right half | ⌥⌘← / ⌥⌘→ | ⌃⌥← / ⌃⌥→ |
| Top / Bottom half | ⌥⌘↑ / ⌥⌘↓ | ⌃⌥↑ / ⌃⌥↓ |
| Upper left / Upper right | ⌃⌘← / ⌃⌘→ | ⌃⌥U / ⌃⌥I |
| Lower left / Lower right | ⌃⇧⌘← / ⌃⇧⌘→ | ⌃⌥J / ⌃⌥K |
| Next / Previous third | ⌃⌥→ / ⌃⌥← | ⌃⌥⇧→ / ⌃⌥⇧← |
| Make larger / smaller | ⌃⌥⇧→ / ⌃⌥⇧← | ⌃⌥= / ⌃⌥- |
| Next / Previous display | ⌃⌥⌘→ / ⌃⌥⌘← | ⌃⌥⌘→ / ⌃⌥⌘← |
| Undo / Redo | ⌥⌘Z / ⌥⇧⌘Z | ⌃⌥Z / ⌃⌥⇧Z |

How the actions behave:

- **Halves and corners:** pressing the shortcut again cycles the size ½ → ⅔ → ⅓.
- **Next/Previous third:** steps through three columns, then three rows.
- **Make larger/smaller:** grows or shrinks the window by 30 pt. Edges that touch the
  screen edge stay there.
- **Next/Previous display:** keeps the window's relative position and size. Displays are
  ordered left to right, then top to bottom.
- **Undo/Redo:** separate for each window, up to 50 steps. Cleared when Zuntrio quits.

Every action is also in the menu-bar menu.

**Settings…** (in the menu) lets you:

- switch to the **Alternative (⌃⌥)** preset, which leaves ⌥⌘←/→ free for switching tabs
  in browsers;
- record your own shortcut for any action (Esc cancels, ⌫ clears);
- turn individual shortcuts off;
- restore the defaults;
- launch Zuntrio at login (off by default).

Every shortcut must include ⌘ or ⌃. Zuntrio warns you if a shortcut is already taken by
another app or is also a macOS keyboard shortcut.

## Disabling shortcuts

Sometimes an app needs those keys itself. Turn Zuntrio's shortcuts off from **Disable
Shortcuts** in the menu, or in Settings:

- **For 1 hour**, or **for several hours** (1–24). They come back on by themselves, and the
  menu shows when, with a **Turn Shortcuts Back On** option.
- **In a specific app.** Choose it while that app is in front, for example
  **In “Terminal”**. Zuntrio's shortcuts are then off whenever that app is in front, and on
  everywhere else. Manage the list in Settings.

While shortcuts are off, the key presses go to the app instead, and the menu-bar icon is
dimmed. The window actions stay available from the menu.

## When a window doesn't move

Zuntrio checks where each window actually ended up and never reports success it didn't get.
You'll hear a beep, and the menu's "Last:" line explains why:

- **The app limited the size.** Many apps have a minimum or maximum window size.
  Terminal-style apps resize in whole rows and columns.
- **Unsupported window.** Dialogs, floating panels, sheets, minimized windows and native
  full-screen windows aren't moved.
- **App isn't responding.** Zuntrio gives up after half a second and stays responsive.
- **Some apps don't support Accessibility fully** and can't be moved at all.

## Compatibility

Tested so far (beta preparation):

| | Tested |
|---|---|
| macOS | 27.2.1 on a Mac; 14.8, 15.7 and 26.6 in virtual machines |
| Mac | Apple Silicon (M1) |
| Displays | Built-in Retina + external 2560×1440, arranged above and side by side; plugging and unplugging |
| Apps | TextEdit, Safari, Google Chrome, Visual Studio Code, Terminal (TextEdit on every macOS version above) |

**Not tested yet:** Intel Macs. The app is built for them, so please report what you find.

## Privacy

- No network connections, no telemetry or analytics, no account.
- Zuntrio never reads window contents, window titles, document names or keystrokes, and
  doesn't track which apps you use.
- Settings (your shortcuts, and any apps where you've turned them off) are stored only on
  your Mac.
- Diagnostic logs stay on your Mac and contain only action names, window positions and
  sizes, and error codes.

## Uninstall

1. If you turned on **Launch at login**, turn it off first: Zuntrio menu → **Settings…**. If
   you've already removed the app, delete the entry in System Settings → General → Login Items
   instead.
2. Quit Zuntrio (menu-bar icon → **Quit Zuntrio**).
3. Delete **Zuntrio** from your Applications folder.
4. Optionally, remove everything Zuntrio left on your Mac. Run these in Terminal:

   ```sh
   # Your settings: shortcuts and disabled apps (~/Library/Preferences/app.zuntrio.Zuntrio.plist)
   defaults delete app.zuntrio.Zuntrio

   # Zuntrio's entry in System Settings → Privacy & Security → Accessibility
   tccutil reset Accessibility app.zuntrio.Zuntrio
   ```

   Instead of the second command, you can select Zuntrio in that Accessibility list and click
   **–**. Zuntrio stores nothing else. Undo history only exists while it's running.

## Building from source

You need Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Zuntrio.xcodeproj -scheme Zuntrio -configuration Debug build
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests and development notes.

## Licence

MIT, see [LICENSE](LICENSE). Zuntrio has no third-party dependencies.

Zuntrio is an independent project. It is not affiliated with or endorsed by Spectacle or its
author.
