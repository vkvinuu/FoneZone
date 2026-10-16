# Real Supabase Auth setup

1. Create/open the Supabase project.
2. Back up the current application tables before applying the reset script. See `docs/SUPABASE_MIGRATION.md`.
3. Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and server-only `SUPABASE_SERVICE_ROLE_KEY` in `.env.local`.
4. Run `supabase/reset_and_install.sql` only after exporting old application data and confirming you accept the clean reset.
5. Register the Platform Admin account through Supabase Auth, then set its UUID to `PLATFORM_ADMIN` in `public.profiles` using SQL Editor.
6. Set the Supabase Auth Site URL to your stable Vercel URL and add its `/auth/callback` redirect path to the allowlist.
7. Test owner signup, admin approval, technician signup, owner approval, owner recovery code, email reset and customer tracking.

Never commit `.env.local`. The service-role key must be server-only and must never be sent to a browser.
