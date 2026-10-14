# Jack's Day Counter

A sleek iOS countdown app with accounts, cloud sync, Outlook calendar export,
and Home Screen + Lock Screen widgets. Built to be sideloaded (no App Store)
at zero cost.

| | |
|---|---|
| App | SwiftUI, iOS 17+ |
| Widgets | WidgetKit: Home Screen small/medium/large, Lock Screen circular/rectangular/inline |
| Accounts + sync | [Supabase](https://supabase.com) free tier: email/password auth, Postgres with row-level security, private photo storage |
| Calendar | System "New Event" sheet (pick your Outlook calendar) and `.ics` export |
| Build | GitHub Actions macOS runner produces an unsigned `.ipa` (free on this public repo) |
| Install | Sideloadly or AltStore signs it with your free Apple ID |

## Docs

- [docs/PLAN.md](docs/PLAN.md): what's built, how it works, limitations, and ideas
- [docs/SETUP.md](docs/SETUP.md): one-time setup (Supabase, GitHub secrets)
- [docs/SIDELOADING.md](docs/SIDELOADING.md): installing on your iPhone, step by step

## Layout

```
App/            iPhone app (views, auth, sync, calendar)
Widgets/        Widget extension
Shared/         Model + storage shared by app and widgets (via App Group)
Config/         Build settings; put Supabase keys in Config/Secrets.xcconfig
supabase/       Database schema and security policies (run once in Supabase)
scripts/        IPA packaging used by CI
project.yml     XcodeGen project definition (run `xcodegen generate`)
```
