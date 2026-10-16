# FoneZone

Blue-and-white multi-shop mobile repair management starter built with Next.js, TypeScript, Tailwind CSS and Supabase.

## Included in this update

- Public sign-in options: **Shop Owner** and **Technician** only.
- Customer repair lookup without customer accounts (tracking ID + registered mobile number).
- Separate `/platform-admin` route; public signup cannot grant Platform Admin privileges.
- Shop applications and owner approval flow, technician requests and owner approval for their own shop.
- 12-character owner recovery code (only its SHA-256 hash is stored), email-based password recovery, and owner-triggered technician reset emails.
- Simplified eight-table Supabase schema, RLS policies, minimal public tracking RPC and public certificate lookup RPC.
- SHA-256 hash fields for audit and inventory events. No blockchain or Sepolia integration.
- Public certificate verifier at `/verify/<certificate-id-or-hash>`.

## Local setup

```bash
npm install
cp .env.example .env.local
# Fill in NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY and server-only SUPABASE_SERVICE_ROLE_KEY
npm run dev
```

Install the schema using the instructions in [`docs/SUPABASE_MIGRATION.md`](docs/SUPABASE_MIGRATION.md). The reset script is destructive: back up/export existing data first.

## Deploy

Push the project to GitHub and import/update that repository in Vercel. Set the same environment variables in Vercel. Configure Supabase Auth Site URL and redirect allowlist for the production Vercel domain.

## Important limits

This update establishes the account/onboarding, approval, public tracking and verification foundation. It is **not yet a complete production repair/inventory system**: repair creation/status transitions, inventory adjustment approval transactions, and certificate signing/verification keys need to be completed and security-tested before handling real customer data. SHA-256 hash fields alone do not make records tamper-proof if a database administrator can rewrite the rows. Add rate limiting to public RPC/API endpoints and verify RLS with separate owner/technician test accounts before launch.
