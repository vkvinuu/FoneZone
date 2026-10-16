# Replace GitHub project and deploy to Vercel

This ZIP is source code only; it does not contain `.env.local`, `node_modules`, or your private keys.

## 1. Make a backup first

- Keep a copy of the current project folder and export existing Supabase table data locally.
- Do not delete your existing `.env.local`; keep it outside the ZIP/extracted folder.
- Read `docs/SUPABASE_MIGRATION.md`. The SQL reset is destructive to old application table data.

## 2. Replace source in the existing GitHub repository

On your computer:

1. Clone or open `https://github.com/vkvinuu/FoneZone`.
2. Extract this ZIP into a separate temporary folder first and inspect it.
3. Copy the ZIP's project files into the repository root, replacing the old source files. Do not copy `node_modules` or `.env.local`.
4. From the repository root run:

```bash
npm install
npm run build
```

5. Only if the build succeeds, review the changes and commit/push:

```bash
git status
git add -A
git commit -m "Update FoneZone roles, onboarding and simplified schema"
git push
```

Do not use `git push --force` for this update.

## 3. Update Supabase

1. Export/backup the existing app tables first.
2. In Supabase SQL Editor, run `supabase/reset_and_install.sql` only if you accept losing old application table rows. It retains Auth user identities, then recreates basic profile rows.
3. Set your own Auth user's `profiles.platform_role` to `PLATFORM_ADMIN` using the UUID command in `SUPABASE_MIGRATION.md`.
4. Check Auth URL configuration and test a shop owner signup before inviting real users.

## 4. Deploy on Vercel

1. Open the existing FoneZone project in Vercel. A push to its connected GitHub branch should trigger a deployment.
2. In **Settings → Environment Variables**, set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` for the required environments.
3. Redeploy after changing environment variables.
4. In Supabase **Authentication → URL Configuration**, set the stable production Vercel URL as Site URL and allow the production URL plus `/auth/callback` redirect.
5. Test: owner signup → admin approval → technician signup → owner approval → repair create → customer lookup → password recovery.

## Status note

I could not verify a production build in this environment because dependency installation timed out and the local `node_modules` directory was incomplete. Run `npm install` and `npm run build` locally before pushing. Do not deploy if the build fails.
