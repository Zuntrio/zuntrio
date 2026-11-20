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
its repository is archived, and its last release (2017) predates Apple Silicon, so on today's
Macs it only runs through Rosetta, which Apple is winding down (see
[Requirements and support](#requirements-and-support)).

Zuntrio exists so that workflow doesn't disappear. It aims to be:

- **familiar:** the same actions and default shortcuts as Spectacle;
- **native and maintained:** a modern Swift app for Apple Silicon and Intel, built for
  current versions of macOS;
- **free and open:** no subscription, account, ads or paywall, and MIT-licensed source;
- **trustworthy:** no network connections unless you check for updates, no telemetry, and it
  tells you honestly when an app won't let a window move.

## Requirements and support

- **macOS 14 Sonoma or later.**
- **Apple Silicon and Intel Macs.** Zuntrio is a Universal app: it contains native code for
  both, so it never needs Rosetta.

See [Compatibility](#compatibility) for what has been tested.

### Why native support matters: Rosetta is ending

Rosetta is the translation layer that lets apps built only for Intel run on Apple Silicon
Macs. Apple has announced that Rosetta stays fully available through macOS 27. From macOS 28
it will be available only for certain older, unmaintained games:

- Apple Support: [Using Intel-based apps on a Mac with Apple silicon](https://support.apple.com/en-us/102527)
- Apple Developer News: [Upcoming changes to Rosetta support for Intel-based macOS apps](https://developer.apple.com/news/?id=w5ngl9k2)

Spectacle's last release is Intel-only, so on an Apple Silicon Mac it depends on Rosetta.
Zuntrio gives Spectacle users a native, maintained replacement with the same shortcuts, one
that keeps working after that change.

## Install

1. Download `Zuntrio.zip` from the [Releases](https://github.com/Zuntrio/zuntrio/releases) page.
   The current version is 0.1.0 beta 1. It's a Universal app, signed and notarized by Apple.
2. Unzip it and move **Zuntrio** to your **Applications** folder.
3. Open Zuntrio. Its icon appears in the menu bar. There is no Dock icon.
4. Grant Accessibility access when asked (see below).

Or install it with [Homebrew](https://brew.sh):

```sh
brew install --cask zuntrio/tap/zuntrio
```

Or with curl (or `wget -qO-` in place of `curl -fsSL`):

```sh
curl -fsSL https://zuntrio.app/install.sh | bash
```

The [script](https://zuntrio.app/install.sh) downloads the release from GitHub, checks its SHA-256
checksum, checks that the app is signed by Zuntrio's Developer ID and notarized by Apple, and moves it
to Applications. Run it again to update.

Then open Zuntrio and grant Accessibility access, as in steps 3 and 4.

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

## Troubleshooting

### A shortcut does nothing

- **Is the menu-bar icon dimmed?** Open the Zuntrio menu. It says either **Accessibility access
  needed** (choose **Grant Accessibility Access…**) or that shortcuts are off. If they're off for a
  while, choose **Turn Shortcuts Back On**. If they're off in the app in front, uncheck that app
  under **Disable Shortcuts** (see [Disabling shortcuts](#disabling-shortcuts)).
- **Does the menu say "… shortcuts unavailable — see Settings"?** Another app registered the
  same keys first, or they're also a macOS keyboard shortcut. Settings shows which ones; record
  a different shortcut or switch to the **Alternative** preset.
- **Want ⌥⌘← / ⌥⌘→ to switch browser tabs again?** They're Spectacle's defaults for left and
  right half, so Zuntrio takes them. The **Alternative** preset (⌃⌥) leaves them to the browser.
- **Can't see the menu-bar icon?** On Macs with a notch, icons can be hidden behind it when
  the menu bar is full. Quit a few other menu-bar apps to make room.

### A window doesn't move

Zuntrio checks where each window actually ended up and never reports success it didn't get.
You'll hear a beep, and a line near the bottom of the Zuntrio menu explains why:

- **The app limited the size.** Many apps have a minimum or maximum window size.
  Terminal-style apps resize in whole rows and columns.
- **Unsupported window.** Dialogs, floating panels, sheets, minimized windows and native
  full-screen windows aren't moved.
- **App isn't responding.** Zuntrio gives up after half a second and stays responsive.
- **Some apps don't support Accessibility fully** and can't be moved at all.

### Accessibility is on, but Zuntrio says it needs access

macOS ties the permission to the exact copy of the app. After replacing Zuntrio with a copy
signed differently (for example a build of your own), the switch can stay on for the old copy.
Select **Zuntrio** in System Settings → Privacy & Security → Accessibility, click **–**, then
open Zuntrio again and grant access. Or run `tccutil reset Accessibility app.zuntrio.Zuntrio`
in Terminal first.

### Reporting a problem

Choose **Copy Diagnostics…** in the Zuntrio menu (0.1.0 beta 2 or later). It shows exactly
what will be copied: versions, Mac model, display layout and the last result, with no window
titles, app names or personal data. Then [open an issue](https://github.com/Zuntrio/zuntrio/issues/new/choose)
and paste it in.

## Compatibility

Tested so far (beta preparation):

| | Tested |
|---|---|
| macOS | 27.2.1 on a Mac; 14.8, 15.7 and 26.6 in virtual machines |
| Mac | Apple Silicon (M1) |
| Displays | Built-in Retina + external 2560×1440, arranged above and side by side; plugging and unplugging |
| Apps | TextEdit, Safari, Google Chrome, Visual Studio Code, Terminal (TextEdit on every macOS version above) |

**Using an Intel Mac?** Zuntrio runs natively on both Apple Silicon and Intel. If something doesn't
work on your Intel Mac, please [let us know](https://github.com/Zuntrio/zuntrio/issues/new/choose).

## Privacy

- No network connections unless you check for updates: a single request to GitHub, made only
  when you choose **Check for Updates…** or turn on automatic checks in Settings (off by default).
  Nothing about you or your Mac is sent, and Zuntrio never downloads or installs updates itself.
- No telemetry or analytics, no account.
- Zuntrio never reads window contents, window titles, document names or keystrokes, and
  doesn't track which apps you use.
- Settings (your shortcuts, and any apps where you've turned them off) are stored only on
  your Mac.
- Diagnostic logs stay on your Mac and contain only action names, window positions and
  sizes, and error codes.

## Uninstall

Installed with Homebrew? Turn off **Launch at login** if you turned it on, then run
`brew uninstall --cask zuntrio`. Add `--zap` to also delete your settings. Otherwise:

1. If you turned on **Launch at login**, turn it off first: Zuntrio menu → **Settings…**. If
   you've already removed the app, delete the entry in System Settings → General → Login Items
   instead.
2. Quit Zuntrio (menu-bar icon → **Quit Zuntrio**).
3. Delete **Zuntrio** from your Applications folder.
4. Optionally, remove everything Zuntrio left on your Mac. Run these in Terminal:

   ```sh
   # Your settings: shortcuts, disabled apps, update checks (~/Library/Preferences/app.zuntrio.Zuntrio.plist)
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
