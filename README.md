# FoneZone — multi-shop repair management

FoneZone is a Next.js repair-management project designed for multiple repair businesses and multiple branches per business. The included **Demo Mode** runs immediately without API credentials and is suitable for demonstrating the user roles and core workflows on one laptop.

> **Important scope note:** Demo Mode persists sample records in this browser's `localStorage`. It is not production authentication, not a shared cloud database, and not secure tenant isolation. The included Supabase SQL is the production data-model/RLS foundation; do not deploy real customer data until the Supabase-backed auth/data operations are connected and security-tested. Public certificate verification in Demo Mode is a record lookup, not a cryptographic signature verification.

## Features in the demo

- Separate portal entry points for customer, shop staff and platform admin; role-specific workspace navigation.
- Demo accounts for Platform Super Admin, Shop Admin, Senior Technician, Technician and Customer.
- Shop applications and approval, multiple branches, shop-specific inventory and pricing.
- Online/walk-in repair creation, hierarchical brand → series → model selection, optional IMEI Luhn validation and intake consent.
- Estimate versions and customer approval before repair begins; changing an estimate resets approval.
- Configurable labour/parts warranty, GST-rate calculation example, partial manual payment recording and balance due.
- Parts catalogue, supplier/authenticity notes, price-change audit events, branch transfers with request/dispatch/receive/discrepancy workflow.
- Quality check, delivery, QR-linked certificate page, verified completed-repair ratings.
- CSV report export, audit event hash chaining using Web Crypto SHA-256, demo data reset by clearing browser site data.
- Responsive professional UI and a role switcher to make a single-laptop demonstration easier.

## Start locally

Requirements: Node.js 20.9+ (Node 22 recommended) and npm.

```bash
npm install
cp .env.example .env.local
npm run dev
```

Open `http://localhost:3000`. You can use the demo account buttons without passwords or API keys. To demonstrate different roles in parallel, open several tabs in the same browser profile and sign into a different demo role in each tab. Tabs on the same browser profile share Demo Mode's local data while each tab has its own session storage. Separate browser profiles/private windows do not share local storage by default.

### Demo accounts

| Role | Email |
|---|---|
| Platform Super Admin | `platform@fonezone.demo` |
| Shop Owner/Admin | `owner@fonezone.demo` |
| Senior Technician | `senior@fonezone.demo` |
| Technician | `tech@fonezone.demo` |
| Customer | `customer@fonezone.demo` |

These are role shortcuts for local Demo Mode only, not real credentials. Never use them for a public deployment.

## Supabase setup foundation

1. Create a Supabase project.
2. Open SQL Editor and run `supabase/schema.sql`.
3. Copy `.env.example` to `.env.local` and fill `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
4. Configure Supabase Auth email verification, password reset and Google OAuth only if desired. Facebook login is intentionally omitted.
5. Configure a production email provider/SMTP for reliable public email delivery.
6. Before switching real users onto the system, connect every operation to Supabase and verify RLS with cross-shop/branch tests. Demo Mode is intentionally not an automatic production fallback.

The Supabase schema contains tenant-scoped tables and RLS foundations. Review `docs/SECURITY_AND_LIMITS.md` before deployment. Do not put service-role keys or signing private keys in frontend code or Git.

## Useful commands

```bash
npm run dev
npm run lint
npm run build
npm start
```

## Tax and payment notes

- Payment recording is manual. Staff confirm cash/UPI/card was received; FoneZone does not transfer money.
- GST is a configurable estimate calculation, not tax advice. The applicable rate, classification, inclusive/exclusive price treatment, GSTIN and place-of-supply treatment must be confirmed for each shop by a qualified professional.
- Sample inventory prices and repair records are illustrative demo data, not current supplier quotes.

## Deployment

Vercel + Supabase free tiers are intended for initial testing. Free allowances and features can change. Do not promise a concurrency number without load testing. Review free-tier limits, backups, email delivery, storage and database capacity before production use.
