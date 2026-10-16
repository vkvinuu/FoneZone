# FoneZone: Supabase authentication setup

## Environment
Create `.env.local` in the project root (next to `package.json`):

```dotenv
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
NEXT_PUBLIC_FONEZONE_DEMO_MODE=false
```

Do not put a service-role/secret key in browser environment variables.

## Apply database schema
1. Open Supabase Dashboard → SQL Editor.
2. Open `supabase/schema.sql` in this project, copy the complete SQL, and run it in the new project.
3. Check the SQL Editor for errors. Do not use real customer data until RLS policies have been reviewed and tested.

The `auth.users` trigger creates a `profiles` row. If metadata `account_type=shop` and `shop_name` are provided at signup, it also creates a pending `shop_applications` row.

## Auth settings
In Supabase Authentication → URL Configuration, set the Site URL to your local development URL while testing (`http://localhost:3000`) and add the callback URL to allowed redirect URLs. Configure production URLs before deployment. Configure email delivery/SMTP before relying on email confirmation and password-reset delivery.

## Run
```bash
npm install
npm run dev
```

## Scope status — read before deployment
This update connects signup, password login, password-reset request, reset-password form, and an account overview to Supabase Auth/profile/application reads. It does **not** finish the multi-tenant repair operations backend. The legacy workspace still contains browser-local sample workflows and is intentionally blocked from the live authenticated route rather than presented as production functionality. Shop approval must still create the actual `shops` and `shop_memberships` records through a protected server-side/RPC workflow. Repair, estimate, inventory, branch-transfer, payment/refund, audit-signing, certificate and reporting screens need database-backed transactional operations and authorization tests before this is production-ready. Never expose a service-role key to the browser.
