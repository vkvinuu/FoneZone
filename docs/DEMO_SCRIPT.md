# FoneZone demo script (one laptop)

1. Open FoneZone and select **Platform Admin** from the Demo accounts section. Open `Shop approvals`, approve the pending `Metro Phone Clinic` application, and review `All shops`.
2. Open a second browser profile/private window and sign in as **Shop Owner / Admin**. Visit `Branches` and `Inventory`; add a branch or a part and change a part price. Show the audit trail.
3. Open a third isolated browser profile as **Customer**. Create a repair ticket (or open the seeded ticket `FZ-2026-00124`). Show the estimate-pending state and approve the estimate.
4. Switch to **Shop Owner / Admin** and open the repair. Set parts/labour/tax, send a revised estimate, then approve it as the customer if the estimate changed.
5. Sign in as **Senior Technician**. Open the repair and start repair after approval. Send it to quality check, complete the checklist, and mark it ready. Staff can record a manual payment when the customer pays the shop directly.
6. As shop admin or senior tech, create a parts transfer from Borivali to Kandivali. Dispatch it, then confirm receipt. Explain that source stock is reduced at dispatch and destination stock is increased on receipt; discrepancy records require review.
7. Finish the repair, record delivery, open the QR-linked certificate page and show the public fields are limited.
8. Export the repair report CSV and show the audit trail / hash-chain link check.

Use the workspace role selector for a quick walkthrough, but separate browser profiles make the different sessions clearer. Demo Mode records are stored locally in the same browser origin. A public production deployment requires Supabase-backed operations and server-side authorization; do not present the local verifier as a production digital signature.
