# Security, deployment and limits

## Demo mode vs production

The supplied UI's Demo Mode uses `localStorage` for records and `sessionStorage` for the current role. It is intentionally easy to demonstrate on one laptop. It is not an authentication boundary: users can alter browser storage, and local data is not shared with other devices. Never deploy this mode with real customer information.

The SQL in `supabase/schema.sql` establishes a tenant-oriented relational model and initial row-level security policies. It does **not** mean every UI action is already wired to Supabase. Before a real deployment, implement and test the production data adapter and server-side RPCs for all mutations, then disable Demo Mode for production builds.

## Non-negotiable production controls

- Supabase Auth for real accounts; no public platform-admin signup. Assign platform admin only through a controlled one-time bootstrap/migration and enforce MFA.
- Use a server-side authorization layer and PostgreSQL RLS together. Test horizontal access: Shop A cannot read or mutate Shop B's customers, jobs, invoices, stock, events or certificates.
- Scope branch operations to authorized branch membership. Cross-branch transfers are allowed only within the same shop unless an explicit inter-shop transfer workflow is approved.
- Put all multi-row financial/inventory operations in database transactions/RPCs with row locks. Never let the browser update quantity balances directly.
- Do not expose `SUPABASE_SERVICE_ROLE_KEY` or signing private keys to browser code. Never commit `.env.local`.
- Hash-chain events need canonical serialization and protected checkpoints. An attacker who can rewrite all local events can recompute the chain; hash chaining alone is not proof of truth.
- Ed25519 signing must occur server-side with a managed private key. Store public keys, fingerprints, validity and revocation state. The demo verifier is not a signature verifier.
- Public certificate endpoints should return a minimal allowlisted payload, never the raw repair/customer row. Never put names, contact details, full IMEI, passwords or notes on-chain.
- Don't store device passcodes. Record consent for inspection/photos, restrict image storage and define retention/deletion policies.
- Add rate limiting at API/provider level, secure cookies, CSRF protections where applicable, upload validation, dependency scanning, monitoring and backup restore tests.

## Rate limiting starting points

Treat these as initial application policies to load-test, not provider guarantees:

- Login/OTP/reset: use Supabase Auth limits, progressive delays, generic reset responses and resend cooldowns.
- Repair creation: 10 per authenticated user per minute initially.
- Public certificate verification: 60 per IP per minute initially.
- Inventory/transfer mutations: 30 per user per minute initially; enforce role and branch scope on every request.
- Uploads: strict content type, file-size and per-user/shop quotas.

On serverless hosting, don't rely on in-memory counters across instances. Use a shared rate-limit service or platform-supported controls.

## Capacity and free tiers

No single concurrent-user number can be guaranteed from a plan name. Capacity depends on query patterns, connection pooling, serverless execution limits, realtime usage, uploads and egress. Use indexes, pagination, bounded list endpoints and load tests. The intended initial test target is 50–100 simultaneous active sessions, not a production guarantee.

Vercel and Supabase free allowances can change and may include pausing, storage, egress, build and usage limits. Verify current plan terms before deployment. Email providers may throttle or charge for public volume. Sepolia is optional and testnet availability/faucet funding is not guaranteed.

## GST and payment

Manual payment recording documents that a staff member says funds were received; it does not transfer money or independently verify a UPI transaction. Record actor, timestamp, method, amount and optional reference. Refund/void actions need authorization and immutable audit events. Tax rates are configurable examples only; validate GST classification, inclusive/exclusive pricing, place of supply, GSTIN and invoice rules with a qualified professional.
