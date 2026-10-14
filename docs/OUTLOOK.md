# Connect Outlook: Entra app registration

The in-app **Connect Outlook** button signs users in with Microsoft and
writes events through Microsoft Graph. It needs one free app registration.
About 5 minutes in the Entra admin center.

## 1. Register the app

1. Go to <https://entra.microsoft.com> > **Identity** > **Applications** >
   **App registrations** > **New registration**.
2. **Name:** `Jack's Day Counter`.
3. **Supported account types**, pick one:
   - **Accounts in this organizational directory only**: only people in
     your tenant can connect. Most locked-down option.
   - **Accounts in any organizational directory and personal Microsoft
     accounts**: work/school accounts from any tenant *and* Outlook.com /
     Hotmail accounts. Pick this if anyone will connect a personal Outlook.
4. **Redirect URI:** platform **Public client/native (mobile & desktop)**,
   value exactly:
   ```
   jacksdaycounter://auth
   ```
5. **Register**.

From the Overview page copy:
- **Application (client) ID**
- **Directory (tenant) ID** (only needed for the single-tenant option)

No client secret or certificate: this is a public client app using PKCE,
so there is nothing secret to store in the app.

## 2. API permissions

**API permissions** > **Add a permission** > **Microsoft Graph** >
**Delegated permissions**, and add:

| Permission | Why |
|---|---|
| `Calendars.ReadWrite` | Create, update, and delete the countdown events |
| `User.Read` | Show which account is connected (already there by default) |
| `offline_access` | Stay connected without signing in again every hour |
| `openid`, `profile` | Standard sign-in |

Then **Grant admin consent for <your tenant>**. This is required if your
tenant blocks user consent, and it saves your users a consent prompt.

## 3. Give the build the IDs

GitHub repository > **Settings > Secrets and variables > Actions**:

| Secret | Value |
|---|---|
| `MS_CLIENT_ID` | the Application (client) ID |
| `MS_TENANT` | your Directory (tenant) ID for single-tenant, or `common` for "any org + personal" (or `organizations` for any org, no personal) |

Re-run **Actions > Build unsigned IPA**. Without `MS_CLIENT_ID` the Outlook
buttons stay hidden and the iPhone Calendar / .ics options still work.

## Admin options worth knowing

- **Limit who can connect:** Enterprise applications > Jack's Day Counter >
  Properties > **Assignment required = Yes**, then Users and groups > add a
  security group. Only members of that group can sign in.
- **Conditional Access:** sign-in happens on Microsoft's own page, so MFA
  policies apply normally. Policies that require a *compliant device* or an
  *approved client app / app protection policy* will block it, because a
  sideloaded app isn't Intune-managed. If you hit that, exclude this app
  from the policy (scoped to your group), or use the iPhone Calendar
  fallback.
- **Revoke access:** Entra > Users > the user > **Revoke sessions**, or the
  user taps Disconnect Outlook in the app. Deleting the app registration
  disconnects everyone.
- **Audit:** Entra sign-in logs show each connection under the app name.

## Troubleshooting

| Message in the app | Fix |
|---|---|
| "Need admin approval" on the Microsoft page | Grant admin consent (step 2). |
| AADSTS50011 redirect URI mismatch | The redirect URI must be exactly `jacksdaycounter://auth` under the mobile & desktop platform. |
| AADSTS50020 / 50194 account not in tenant | Your account type choice (step 1.3) doesn't allow that account; switch to the multi-tenant option and set `MS_TENANT` to `common`. |
| "Outlook refused access (403)" | Calendars.ReadWrite missing or not consented. |
