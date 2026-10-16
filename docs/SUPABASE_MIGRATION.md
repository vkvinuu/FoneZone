# Supabase update — read before running SQL

The simplified schema has **8 core application tables**: `profiles`, `shops`, `shop_members`, `repairs`, `inventory`, `inventory_events`, `certificates`, and `audit_logs`. It removes the old branch, transfer, senior-technician, customer-login, and blockchain structures.

## Important: the reset script deletes old application data

`supabase/reset_and_install.sql` drops the existing FoneZone application tables and their rows, then creates the simplified schema. Supabase Auth identities in `auth.users` are retained and basic profiles are recreated, but old repair tickets, stock records, certificates, and shop membership rows are not retained in the new tables.

Before running it:

1. In Supabase Dashboard, create/download a database backup if available for your plan.
2. Open **Table Editor** and export important tables to CSV/JSON locally. At minimum export shops, profiles, repair tickets, inventory items, stock movements, certificates and audit events.
3. Keep those exports outside the Git repository. Never export or commit service-role keys.
4. Only then open **SQL Editor**, paste/run `supabase/reset_and_install.sql`, and check the results.

Do not run the reset script if you need the old repair/stock data preserved in the live schema. This first replacement is a clean schema reset, not an automatic data migration.

## Set the initial Platform Admin

1. Register your own account using the private `/platform-admin` route only after you have an Auth user account. Do not create an admin through public signup.
2. In **Authentication → Users**, copy your user's UUID.
3. In SQL Editor run, replacing the placeholder with your UUID:

```sql
update public.profiles
set platform_role = 'PLATFORM_ADMIN'
where id = '<YOUR_AUTH_USER_UUID>';
```

4. Sign in at `/platform-admin`. The admin can approve pending shop applications and review pending technician requests.

## Shop IDs and approvals

- The first shop owner signup receives `FZ-001`, the next receives `FZ-002`, and so on.
- Initial demo names: SS Mobile, Metro Mobile Care, QuickFix Mobiles, and Prime Mobile Solutions. Shop owners submit the actual applications; the IDs are assigned by the database.
- A shop is not usable until the Platform Admin approves it. Once active, technicians can request to join using that shop ID; the owner approves only their own shop's technicians.

## Environment variables

Set these in local `.env.local` and Vercel Project Settings → Environment Variables:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (server-only; required for owner recovery-code verification)

Never prefix the service-role key with `NEXT_PUBLIC_`, commit it, or expose it to browser code. Configure Supabase Auth Site URL and redirect URLs for the stable production Vercel domain and `/auth/callback`.

## Recovery and tracking notes

- Owner recovery code: a random 12-character code is shown once at owner signup; the database stores only its SHA-256 hash. The recovery endpoint uses the server-only service key and should be protected with rate limiting before public production use.
- Password recovery email delivery is controlled by Supabase Auth SMTP/rate limits. Owner can request a reset email for an approved technician.
- Customer tracking requires both the tracking ID and registered phone number and returns only minimal progress details.
- Local CSV exports are useful extra copies, but should not be the only backup for a live service.
