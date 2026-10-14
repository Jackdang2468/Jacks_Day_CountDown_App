# One-time setup

About 10 minutes, all free. You only do this once.

## 1. Create a Supabase project

1. Go to <https://supabase.com> and sign up (GitHub sign-in works).
2. **New project**. Name it `jacks-day-counter`, set a strong database
   password (save it in your password manager; the app never uses it), and
   pick the region closest to you. Free plan.
3. Wait for it to finish provisioning (a minute or two).

## 2. Create the database table and security rules

1. In the project, open **SQL Editor** > **New query**.
2. Paste the whole contents of
   [`supabase/migrations/0001_countdowns.sql`](../supabase/migrations/0001_countdowns.sql)
   and click **Run**. You should see "Success. No rows returned".
3. Run [`supabase/migrations/0002_features.sql`](../supabase/migrations/0002_features.sql)
   the same way. It adds the columns for yearly repeats, pinning, and
   reminders. (If you set up Supabase before this file existed, run just
   this one now; until you do, syncing shows "Couldn't sync".)
4. Check **Table Editor**: a `countdowns` table with a "RLS enabled" badge.
   Check **Storage**: a private `countdown-images` bucket.

## 3. Email confirmation (pick one)

Supabase's built-in email sender is for testing only: it is heavily rate
limited and may only deliver to your Supabase team's own addresses.

- **Simplest (recommended for a personal app):** Authentication >
  Sign In / Providers > Email > turn **off** "Confirm email". Accounts work
  immediately after sign-up.
- **Keep confirmation, use Microsoft 365 to send:** Authentication > Emails >
  SMTP Settings > enable custom SMTP with `smtp.office365.com`, port 587,
  and a licensed or shared mailbox that has SMTP AUTH enabled (Exchange
  admin center > mailbox > Manage email apps > Authenticated SMTP). If SMTP
  AUTH is disabled tenant-wide by policy, a free sender like Resend or
  Brevo works too.

## 4. Lock it down after you sign up (optional, recommended)

Once you've created your own account in the app:
Authentication > Sign In / Providers > turn **off** "Allow new users to sign
up". Your account keeps working; nobody else can register against your
project. You can add other people later from Authentication > Users > Invite.

## 5. Give the build your Supabase keys

In Supabase: **Project Settings > API** (or **Data API**). You need:
- **Project URL**, e.g. `https://abcdefghijkl.supabase.co`. Use only the
  host part: `abcdefghijkl.supabase.co`.
- **anon / publishable key**. This key is safe to put in an app; it can't
  read anything without a signed-in user, thanks to the rules from step 2.
  Never use the `service_role` / secret key.

Then in GitHub: repository **Settings > Secrets and variables > Actions >
New repository secret**, add two secrets:

| Name | Value |
|---|---|
| `SUPABASE_HOST` | `abcdefghijkl.supabase.co` |
| `SUPABASE_ANON_KEY` | the anon / publishable key |

Only if you choose Microsoft sign-in for Outlook (OUTLOOK.md Option B),
also add `MS_CLIENT_ID` and `MS_TENANT`. Skip them to use the Outlook
account on your iPhone instead.

Then **Actions > Build unsigned IPA > Run workflow** to build an app with
sync turned on. (Without the secrets the app still builds, but runs in
on-device-only mode.)

**Building on a Mac with Xcode instead?** Copy
`Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` and fill in the
same two values. That file is git-ignored.

## 6. (Optional) Add your Outlook account to the iPhone

This is what **Connect Outlook** uses by default (see
[OUTLOOK.md](OUTLOOK.md) Option A). For events to land in Outlook, your Outlook calendar must be on
the phone: Settings > Calendar > Accounts > Add Account > Microsoft Exchange
or Outlook.com. Or install the Outlook app and, in its settings, turn on
calendar sync to iOS. If your tenant restricts native-mail access via
Intune/Conditional Access, use the **Share .ics** button instead and open
the file in the Outlook app.
