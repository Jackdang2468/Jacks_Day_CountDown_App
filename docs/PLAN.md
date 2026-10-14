# Plan

## What's in this first version

**Accounts.** Create an account or sign in with email and password. Supabase
Auth issues short-lived access tokens plus a refresh token; the SDK stores
them in the iOS Keychain. Passwords never touch this repository or the phone's
files.

**Your data stays private.** Countdowns live in a Supabase Postgres table
with row-level security, so each account can only read or change its own
rows, and a not-signed-in request gets nothing. Photos go to a private
storage bucket under a folder named after your user ID, with the same rule.
The GitHub repository only holds code; no personal data is stored in it.

**Sync.** Local-first: every change saves on the phone immediately (widgets
update instantly), then syncs to your account. Edits made offline are queued
and pushed when you're back online. Pull to refresh on the list to sync on
demand; the app also syncs every time it comes to the foreground.

**Countdowns.** Title, date (all-day or a specific time), notes, an optional
emoji, and either a photo of your choice or one of seven gradient themes.
Past events move to a collapsible "Past events" section and count up.
The detail screen shows a live days/hours/minutes/seconds countdown.

**Outlook calendar.** Two ways, no Microsoft setup needed:
1. **Add to Calendar** opens Apple's New Event sheet pre-filled with the
   event and a reminder one day before. Pick your Outlook/Exchange calendar
   in the Calendar field and it syncs to Outlook. This needs your work or
   personal Outlook account added under Settings > Calendar > Accounts (or
   the Outlook app with calendar sync turned on).
2. **Share .ics** creates a standard calendar file you can send to Outlook
   by Mail, AirDrop to your PC, or open in the Outlook app.

There's also a toggle in the New Countdown screen to jump straight into
the calendar sheet after saving.

**Widgets.** One "Countdown" widget in six sizes:
- Home Screen: small, medium, large, showing your photo or theme behind
  the day count.
- Lock Screen: circular (just the number), rectangular (photo thumbnail,
  title, days), and inline (one line above the clock).
Long-press a widget and choose Edit Widget to pick which countdown it shows;
by default it shows the next upcoming one. Widgets tick over at midnight on
their own without opening the app.

**Design.** Rounded type, large numbers, gradient cards from the logo's
cyan/blue/violet palette, smooth number transitions, Dark Mode support.

## Limitations to know about

- **7-day expiry with a free Apple ID.** Apps signed with a free Apple ID
  stop launching after 7 days. Re-sign before then: AltStore can do it
  automatically over Wi-Fi; Sideloadly needs you to re-install from the
  computer. Your data is safe either way since it's in your account. A paid
  Apple Developer account ($99/year) makes it one year.
- **Free Apple ID caps.** Up to 3 sideloaded apps at once and 10 app IDs
  per 7 days. This app uses 2 (app + widget).
- **Lock Screen widgets are monochrome.** iOS renders Lock Screen widgets
  tinted, so your photo shows as a small tinted thumbnail there. Full-color
  photos appear on Home Screen widgets.
- **Supabase free tier pauses** a project after about a week with no
  activity. Opening the app regularly keeps it awake; if it does pause, one
  click in the Supabase dashboard resumes it with no data lost. Limits are
  500 MB database and 1 GB of photo storage, far more than this app needs.
- **Confirmation emails.** Supabase's built-in email sender is rate limited
  and only meant for testing. See SETUP.md for the options (turn off email
  confirmation for this personal app, or send through your own SMTP such as
  Microsoft 365).
- **Password reset** isn't in this first version, because the reset link
  needs a web page to land on. You can reset a password from the Supabase
  dashboard (Authentication > Users).
- **Sign out clears the phone copy.** Changes made offline that haven't
  synced yet are lost on sign-out.
- **The cloud-built IPA is public.** This repository is public, so anyone
  signed in to GitHub can download the built app file. It contains only the
  Supabase *anon* key, which is designed to be public and can't read data
  without signing in. After you create your account you can turn off new
  sign-ups in Supabase so nobody else can register (SETUP.md step 4).

## Alternatives you could choose instead

| Area | Default | Alternatives |
|---|---|---|
| Sign-in | Email + password in Supabase | Sign in with your Microsoft (Entra ID) account using Supabase's Azure provider, so your M365 credentials and MFA/Conditional Access apply. Needs an Entra app registration. |
| Outlook | iPhone calendar sheet + .ics | Microsoft Graph: the app writes straight to your Outlook calendar via the API. Needs an Entra app registration with `Calendars.ReadWrite` delegated permission; works even without Outlook on the phone. |
| Backend | Supabase | Firebase (Auth + Firestore), also free. Or no backend at all with iCloud, but iCloud needs a paid developer account. |
| Install | Sideloadly / AltStore | Xcode on a Mac (most reliable), or a paid developer account for 1-year installs. |

## Ideas for later (your call)

These aren't built. Say which you'd like and I'll add them.

1. **Reminders**: local notifications at milestones (1 week, 1 day, day-of).
   Free, no server needed.
2. **Repeating events**: birthdays and anniversaries that roll over to next
   year automatically.
3. **Face ID lock**: require Face ID to open the app.
4. **Share card**: export a pretty image of a countdown to send to friends.
5. **Siri and Shortcuts**: "Hey Siri, how many days until vacation?"
6. **Count-up mode**: "days since" trackers (quit a habit, relationship, etc.).
7. **Sort and pin**: pin a favorite to the top, sort by date or name.
8. **Live Activity**: a live timer on the Lock Screen and Dynamic Island in
   the final hours before an event.
