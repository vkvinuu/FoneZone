# Security and limitations

## Security controls in this starter

- Supabase Auth handles passwords and email recovery; public signup never accepts a Platform Admin role.
- Shop owners and technicians are separate membership roles. Memberships remain pending until the required approval.
- Row Level Security scopes shop data to approved members. Platform Admin authorization is stored in `profiles.platform_role` and must be set manually by the project owner.
- Public repair tracking requires both the tracking ID and registered mobile number and returns minimal status data only.
- Owner recovery codes are generated randomly, shown once, and stored as SHA-256 hashes. The recovery API uses the server-only Supabase service-role key.
- `audit_logs` and `inventory_events` have no UPDATE/DELETE RLS policies in the baseline schema.
- No customer personal data is put on a blockchain; this version has no blockchain integration.

## Required before production

- Configure rate limits/WAF for public tracking and recovery endpoints. The owner recovery endpoint does not implement a distributed rate limiter by itself.
- Test with separate Platform Admin, Shop Owner, Technician, and anonymous browser sessions.
- Verify that a technician from one shop cannot read or mutate another shop's data.
- Implement transactional inventory operations so quantity changes and append-only events succeed or roll back together.
- Implement and cryptographically verify digital signatures for certificates. Current public verification confirms a database record and displays its SHA-256 hash; it does not yet verify a signature against a public key.
- Set up scheduled database backups and periodically export a local encrypted copy. Local exports alone are not enough for production recovery.
- Do not put `SUPABASE_SERVICE_ROLE_KEY` in browser code, commit it, or use a `NEXT_PUBLIC_` prefix.
- Configure Supabase Auth email SMTP, site URL and redirect allowlist. Default email service can be rate-limited.

A SHA-256 field alone is not tamper-proof against a database administrator who can rewrite both data and hashes. Use controlled database access, append-only permissions, signed snapshots and independent backups for stronger evidence.
