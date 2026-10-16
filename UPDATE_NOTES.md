# FoneZone update notes

This replacement follows the agreed architecture: four suggested initial shop names (SS Mobile first), centralized Platform Admin, Shop Owner and Technician roles, owner approval of shop technicians, customer tracking without a customer login, owner recovery code, password reset emails, blue-and-white UI, eight core Supabase tables, SHA-256 hash-linked inventory events, public certificate lookup, and no blockchain.

The ZIP is a source update, not a completed production deployment. Before live use, follow `docs/SUPABASE_MIGRATION.md` and `docs/DEPLOYMENT_STEPS.md`. The database reset is destructive to old application table rows, so export/backup first. Build validation could not be completed here because `npm install` timed out and the local dependency directory was incomplete; run `npm install` and `npm run build` locally before pushing to GitHub.

Not yet complete for production: certificate signing and public-key signature verification, distributed rate limiting on recovery/tracking endpoints, full transactional inventory approval workflow, and a formal automated backup schedule.
