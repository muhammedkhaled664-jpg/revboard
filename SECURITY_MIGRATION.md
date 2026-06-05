# Security Migration — Supabase Auth + Row Level Security

This upgrades RevBoard / SYNC from plaintext passwords stored in a table to
**real authentication** (hashed passwords) with **Row Level Security (RLS)** so
your data can no longer be read by anyone who opens the page source.

> ⚠️ **Why this matters:** Today the public key in `index.html` lets *anyone*
> read the entire `floor_users` table — including every password — straight from
> the browser. RLS closes that hole. Do the steps in order.

---

## What changes for your team
- People log in with **email + password** instead of their name.
- Passwords are now hashed and managed by Supabase Auth (never stored in plain text).
- Managers add members the same way as before, but now also enter an **email**.

---

## Step-by-step

### 1. Disable email confirmation (so new accounts work immediately)
Supabase Dashboard → **Authentication → Sign In / Providers → Email** →
turn **OFF** "Confirm email" → Save.
(Internal tool, accounts are created by managers, so confirmation isn't needed.)

### 2. Run the database migration
Supabase Dashboard → **SQL Editor → New query** → paste the entire contents of
`supabase/migrations/0001_auth_and_rls.sql` → **Run**.
This adds the auth link, the helper functions, and turns on RLS with policies.

### 3. Create auth accounts for your existing people
For **each** current user in `floor_users`:

a. Dashboard → **Authentication → Users → Add user** → enter their email +
   a temporary password → create. Copy the new user's **UID**.

b. Dashboard → **SQL Editor**, link the account to their existing profile:
```sql
update public.floor_users
set user_id = 'PASTE-THE-UID-HERE',
    email   = 'their@email.com'
where name = 'Their Exact Name';
```
Repeat for everyone. (New members added later through the app do this automatically.)

> 💡 Make sure at least one person has a manager role
> (`role` contains "Manager" or equals "Admin"), or no one will be able to add
> members or delete tasks.

### 4. Deploy the updated app
Upload the new `index.html` to GitHub (or let Claude push it once the GitHub App
has write access). Vercel will redeploy automatically.

### 5. Test before locking the old door
- Log in as a manager with the new email + password. Confirm you see your tasks.
- Add a test member through the app — confirm they can log in.
- Log in as a normal team leader — confirm they only see their department.

### 6. Remove the old plaintext passwords (only after step 5 passes)
Dashboard → **SQL Editor**, run just this line:
```sql
alter table public.floor_users drop column password;
```

Done — passwords are now hashed, and the database is locked down by RLS. ✅

---

## Notes / future hardening
- **Revoking access:** removing a member in the app deletes their profile, which
  blocks their access. To also delete the underlying login, remove them from
  **Authentication → Users** in the dashboard.
- **Password resets / invites:** for a more polished flow later, switch member
  creation to a Supabase **Edge Function** using the service-role key and the
  `inviteUserByEmail` API. The current client-side flow is fine for an internal
  tool but the edge-function approach is the long-term best practice.
