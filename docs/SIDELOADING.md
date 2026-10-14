# Installing on your iPhone

You need: your iPhone, a USB cable, a Windows PC or Mac, and a free Apple ID.
Use a secondary Apple ID if you'd rather not type your main one into a
third-party tool.

## Step 1. Turn on Developer Mode (one time)

Developer Mode only appears after a sideloaded app has been installed once,
so you'll come back to this after Step 4 if the toggle isn't there yet.

iPhone: **Settings > Privacy & Security > Developer Mode > On**, then restart
and confirm.

## Step 2. Get the app file

1. Open the repository on GitHub > **Actions** > **Build unsigned IPA**.
2. Click the latest green run (or **Run workflow** to make a fresh one).
3. Under **Artifacts**, download **JacksDayCounter-ipa** and unzip it. You
   now have `JacksDayCounter.ipa`.

## Step 3. Install Sideloadly on your computer

1. Download from <https://sideloadly.io> and install.
2. **Windows only:** install iTunes and iCloud from apple.com (the
   non-Microsoft-Store versions), which Sideloadly needs for its USB drivers.

## Step 4. Install the app

1. Plug in the iPhone, unlock it, and tap **Trust** if asked.
2. Open Sideloadly. Your iPhone appears in the device list.
3. Drag `JacksDayCounter.ipa` onto Sideloadly.
4. Enter your Apple ID and click **Start**. Enter the password (and 2FA
   code) when prompted.
5. Wait for "Done".

## Step 5. Trust the app on your iPhone

**Settings > General > VPN & Device Management** > tap your Apple ID under
Developer App > **Trust**. Now open Day Counter from the Home Screen.

## Step 6. Add widgets

- **Home Screen:** long-press an empty spot > **Edit** > **Add Widget** >
  search "Day Counter" > choose a size > **Add Widget**.
- **Lock Screen:** long-press the Lock Screen > **Customize** > Lock Screen >
  tap the widget area > pick Day Counter.
- Long-press any Day Counter widget > **Edit Widget** to choose which
  countdown it shows.

## Every 7 days: refresh

A free Apple ID signature lasts 7 days. Before it runs out, plug in and
repeat Step 4 with the same IPA. Your countdowns are kept.

**Make it automatic with AltStore instead (optional):** install AltServer on
your PC from <https://altstore.io>, install AltStore onto the phone through
it, then open `JacksDayCounter.ipa` in AltStore (My Apps > +). With
AltServer running on the same Wi-Fi, AltStore refreshes the app in the
background. AltStore also adjusts the App Group automatically, which the
widgets rely on.

## If something goes wrong

| Problem | Fix |
|---|---|
| "Untrusted Developer" | Step 5. |
| App won't open after a week | The 7-day signature expired. Repeat Step 4. |
| Widgets say "Add a countdown in the app" but you have some | Open the app once, then Settings in the app > Refresh widgets. If Settings warns the App Group isn't active, reinstall with AltStore, or with Sideloadly enable its App Group/"signing mode" option in Advanced. |
| "Maximum number of apps" | Free Apple IDs allow 3 sideloaded apps. Remove one. |
| Can't sign in | Check SETUP.md step 3 about email confirmation. |

## Building on a Mac instead

1. Install Xcode from the Mac App Store, then `brew install xcodegen`.
2. Clone this repo, create `Config/Secrets.xcconfig` (SETUP.md step 5), run
   `xcodegen generate`, open `JacksDayCounter.xcodeproj`.
3. Xcode > Settings > Accounts > add your Apple ID.
4. Select the **JacksDayCounter** target > Signing & Capabilities > Team =
   your Personal Team. Do the same for **JacksDayCounterWidgets**. If Xcode
   says the bundle ID is unavailable, change `BUNDLE_ID_PREFIX` in
   `Config/App.xcconfig` to something unique and regenerate.
5. Plug in your iPhone, select it as the run destination, press Run.
