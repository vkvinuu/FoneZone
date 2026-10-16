# FoneZone demo walkthrough

1. Register the first Shop Owner with shop name **SS Mobile**. The database assigns the first shop code, normally `FZ-001`.
2. Sign into `/platform-admin` using the pre-authorized Platform Admin account and approve the pending shop application.
3. Sign in as the owner. The owner can see the shop ID and manage technician applications for that shop.
4. Register a technician using an active shop code. The technician remains pending until that shop's owner approves the request.
5. As the owner, approve the technician and test the owner-triggered password-reset email.
6. Create repair rows in Supabase Table Editor for testing public tracking. Use the tracking ID and registered mobile number on the public home page.
7. Add a certificate row linked to a repair, then open `/verify/<certificate-id>` to test the public record lookup.
8. Confirm that a public customer lookup does not reveal customer name, full phone number, issue summary, price or internal notes.

Suggested initial shop names: SS Mobile, Metro Mobile Care, QuickFix Mobiles, Prime Mobile Solutions. New shop owners register their real shop names; these are suggested demo names, not pre-created database records.

This is an onboarding and approval demo foundation. Repair workflow screens, transactional inventory management and real digital-signature verification remain future implementation tasks.
