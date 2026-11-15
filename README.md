# Altman Meter

A tiny Mac app that shows your RAM, free disk space and battery in two places:

- a **desktop widget** (small, medium or large) that sits with your other widgets, and
- a **menu bar item** with a live readout and a panel that looks like the medium widget.

Everything runs on your Mac. No network access, no accounts, no third-party code.

---

## 1. Requirements

- **macOS 14 Sonoma or newer.** Desktop widgets need it.
- **Xcode 16 or newer.** It's free in the Mac App Store. Open it once after installing so it can
  finish setting up and you can accept the license.
- **A free Apple ID.** You don't need the paid Apple Developer Program to build this for yourself.

## 2. Get the code

Either:

```sh
git clone https://github.com/<owner>/AltmanMeter.git
cd AltmanMeter
```

or, on the GitHub page, click **Code → Download ZIP**, then double-click the ZIP and open the folder.

## 3. Make it yours (signing)

macOS only runs widgets that are code-signed. Signing is free with your Apple ID, but the project
has to use *your* team and *your* bundle ID. Choose **one** of these two ways.

### Option A: edit one file (recommended)

1. **Add your Apple ID to Xcode:** Xcode → Settings… → Accounts → **+** → Apple ID → sign in.
   Then select your account, click **Manage Certificates…** → **+** → **Apple Development**.
2. **Find your Team ID** (10 characters, like `AB12CD34EF`). In Terminal, run:

   ```sh
   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
   ```

   Your Team ID is the value after `OU=`. You can also find it in Xcode → Settings → Accounts:
   select your account, and the team is listed as "Your Name (Personal Team)". Hovering or opening
   the details shows the ID.
3. Open `Config/Base.xcconfig` in any text editor and change these two lines:

   ```
   BUNDLE_ID_PREFIX = com.yourname        // anything unique to you
   DEVELOPMENT_TEAM = AB12CD34EF          // your Team ID
   ```

That's it. Both the app and the widget read their team from this one file, so they always match.

### Option B: use Xcode's signing screen

Open `AltmanMeter.xcodeproj`, click the blue project icon at the top of the sidebar, then for
**both** targets, `AltmanMeter` and `AltmanMeterWidgetExtension`, go to **Signing & Capabilities**
and pick your **Personal Team**. Use the same team for both, or the widget won't load (see
Troubleshooting). You'll still need to change `BUNDLE_ID_PREFIX` in `Config/Base.xcconfig`, because
bundle IDs must be unique per developer.

## 4. Build and install

### In Xcode

Open `AltmanMeter.xcodeproj`, choose the **AltmanMeter** scheme and "My Mac" at the top, and press
**Run** (▶). The app starts in the menu bar. For the widget, install the app to /Applications as
described below; widgets are most reliable from there.

### Or in Terminal (one command, then install)

From the project folder:

```sh
xcodebuild -project AltmanMeter.xcodeproj -scheme AltmanMeter -configuration Release \
  -derivedDataPath build -allowProvisioningUpdates build
```

Then quit any running copy, put the app in /Applications and open it:

```sh
pkill -x AltmanMeter; rm -rf /Applications/AltmanMeter.app
ditto build/Build/Products/Release/AltmanMeter.app /Applications/AltmanMeter.app
open /Applications/AltmanMeter.app
killall chronod   # makes macOS rescan widgets right away
```

**VS Code users:** the project includes tasks. Press ⇧⌘B for **Build and run**, which builds,
installs to /Applications and opens the app. **Check it compiles (no signing)** is a quick
compile check that doesn't need a team.

## 5. Add the widget to your desktop

1. Right-click an empty spot on the desktop → **Edit Widgets…**
2. Type **Altman** in the search field.
3. Choose **small**, **medium** or **large**.
4. Drag it onto the desktop next to your other widgets, then click **Done**.

## 6. Use the menu bar item

- Look near the right end of the menu bar for a small icon with a percentage, like 🔥 62%. The icon
  changes with the boss's mood: a flame when furious, a storm cloud when annoyed, a question mark
  when confused. It updates every 5 seconds.
- **Click it** to open the panel. It shows the same card as the medium widget (face, quote, RAM,
  disk, battery), refreshing every 2 seconds while it's open.
- **Menu bar shows:** pick *Icon only*, *RAM %* or *RAM GB*.
- **Open at login:** turn it on to start Altman Meter when you log in. macOS may ask you to approve
  it; if the panel says "Needs your approval", click **Open Login Items…** and switch on
  Altman Meter under "Allow in the Background" / "Open at Login".
- **Refresh desktop widget** asks macOS to redraw the widget now. **Quit** closes the app.

There's no Dock icon and no window. The menu bar item is the whole app.

## 7. How it refreshes

- **Desktop widget:** a snapshot. Each one shows **"Sampled 1:42 PM"** and macOS takes a new one
  roughly every **15 minutes**. macOS decides the exact timing to save battery, so it can be later.
  Use **Refresh desktop widget** in the panel to ask for one now.
- **Menu bar:** live, every 5 seconds, and every 2 seconds while the panel is open.
- **Boss lines** rotate about every 10 minutes.

## 8. Troubleshooting

**The widget isn't in the Edit Widgets gallery**
1. Make sure the app is in **/Applications** and you opened it from there at least once.
2. Run `killall chronod` in Terminal (it restarts the widget service), then reopen Edit Widgets.
3. Delete any other copies of AltmanMeter.app (e.g. in Downloads, or old Xcode build folders),
   because duplicate copies confuse macOS.
4. Still missing? Log out and back in, or restart.

**"Embedded binary is not signed with the same certificate as the parent app"**
The app and the widget were signed by different teams. Set the team only in
`Config/Base.xcconfig`, and if you used Xcode's Signing & Capabilities screen, make sure **both**
targets show the same team. If one target has its own team, remove it there (select the setting
and press Delete) so it falls back to the xcconfig.

**I can't see the menu bar icon**
On MacBooks with a notch, menu bar items that don't fit get hidden behind it. Quit a few other
menu bar apps, or ⌘-drag less important icons out of the menu bar to make room.

**Battery says "No battery"**
That's expected on desktop Macs (iMac, Mac mini, Mac Studio, Mac Pro).

**A value shows "—"**
That reading failed. The app keeps running and tries again on the next refresh.

## 9. What each stat means

| Stat | What it is | Where it comes from |
| --- | --- | --- |
| **RAM used / total** | Memory in use, counted like Activity Monitor's "Memory Used": app memory (internal pages minus purgeable) + wired + compressed. Total is installed RAM. | `host_statistics64(HOST_VM_INFO64)` and `ProcessInfo.physicalMemory` |
| **Free disk space** | Free space on your startup disk, including space macOS can free up from caches, which matches Finder. | `volumeAvailableCapacityForImportantUsage` on `/`, falling back to `volumeAvailableCapacity` |
| **Battery** | Charge %, plus charging / charged / plugged in, not charging / on battery. Internal battery only. | IOKit `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList` |

**Why there's no "memory pressure":** macOS has no public API that reports the *current*
memory-pressure level reliably. `DispatchSource.makeMemoryPressureSource` only fires when the
level *changes*, so a widget that starts up fresh can't ask "what is it now?". The
`kern.memorystatus_vm_pressure_level` sysctl does answer that, but it's undocumented and could
change or disappear in any macOS update. Rather than show a number that might be wrong, Altman
Meter leaves it out.

**Privacy:** all readings happen on your Mac. The app and widget are sandboxed, have no network
access, and send nothing anywhere.

## 10. Customize

- **When he's furious, and what he says:** `Shared/Mood.swift`. Change
  `furiousBelowRAMFraction` (default `0.60`, i.e. 60%) and edit the `quotes` lists. Keep each line
  under about 75 characters so it fits the widgets.
- **His face:** `Shared/BossFaceView.swift`. By default he's a drawn cartoon. To use photos
  instead, put square images named `boss-furious.jpg`, `boss-annoyed.jpg` and `boss-confused.jpg`
  (about 320×320 px; widgets reject large images) in `Shared/Photos/` and rebuild. The steam,
  brows and teeth are drawn on top; their positions are in `FaceGeometry`. `Shared/Photos/` is in
  `.gitignore`, so use only images you have the right to use, and don't commit them.
- **Refresh timings:** `Shared/Constants.swift`.

**Which folder builds into which target.** The project uses Xcode 16 "synchronized folders":
any file you drop into a folder is compiled into that folder's target automatically.

| Folder | Goes into | Contains |
| --- | --- | --- |
| `Shared/` | app **and** widget | stats model and reader, formatters, mood and quotes, face, stat rows, the widget card |
| `AltmanMeter/` | app only | app entry point, menu bar label and panel, settings, login item, assets/icon |
| `AltmanMeterWidget/` | widget only | timeline provider, small/medium/large views, widget bundle |
| `Config/` | not compiled | `Base.xcconfig`, widget `Info.plist`, entitlements |

Open any view file in Xcode and show the canvas (⌥⌘↩) to see SwiftUI previews of each widget size
and the menu bar panel.

## 11. Shipping it to other people (maintainer only)

Builds signed with a free Personal Team only work on your own Mac. **Never share them as
downloads.** To publish a version anyone can install:

1. Join the **Apple Developer Program** ($99/year) to get a **Developer ID** certificate.
2. In Xcode: **Product → Archive**, then in the Organizer **Distribute App → Direct Distribution**.
   Xcode signs it with Developer ID and gets it **notarized** by Apple.
3. Package it:
   - **ZIP:** `ditto -c -k --keepParent AltmanMeter.app AltmanMeter.zip`
   - **DMG:**
     ```sh
     hdiutil create -volname "Altman Meter" -srcfolder AltmanMeter.app -ov -format UDZO AltmanMeter.dmg
     codesign --sign "Developer ID Application: Your Name (TEAMID)" AltmanMeter.dmg
     xcrun notarytool submit AltmanMeter.dmg --keychain-profile "notary" --wait
     xcrun stapler staple AltmanMeter.dmg
     ```
     (Create the `notary` profile once with `xcrun notarytool store-credentials`.)
4. Upload the .zip or .dmg to **GitHub Releases**. Don't commit it to the repo.

# altman-meter
