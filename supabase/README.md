# Supabase setup — Blaban Sweets

This folder contains the first database schema draft. It is **not connected to the live website yet**, and applying it does not by itself create a complete shop.

## Create your own project
1. Create a Supabase account and a new project under an account you control: https://supabase.com/
2. Keep the database password and any service-role secret private.
3. Open **SQL Editor** in your project, paste the contents of `schema.sql`, and run it.
4. In Authentication settings, choose the sign-in methods you actually want to support.
5. Do not create staff accounts until the server-side role assignment and owner bootstrap process are implemented and tested.

## Security notes
- The schema deliberately seeds no products, prices, branch addresses, payment settings, or owner user.
- Public read policies expose only published products and active categories/branches.
- No browser-side insert/update/delete policies are provided for orders or administration. A trusted server/API must validate order prices and permissions before production use.
- Never place a Supabase service-role key or payment-provider secret in frontend files or commit it to GitHub.
- The owner role must be assigned through a controlled server-side process. Do not allow users to set their own role.
- Before collecting customer data, add and test the trusted order-creation API, staff authorization checks, rate limits, audit logging, privacy/retention policies, and backup/restore procedures.

## Current status
- [x] Initial relational schema for profiles, categories, products, branches, delivery zones, settings, orders, order history, and audit log.
- [ ] Connect the storefront to Supabase.
- [ ] Implement server-side order creation and price recalculation.
- [ ] Implement owner bootstrap and role-protected admin API.
- [ ] Implement admin dashboard and product/order management.
- [ ] Test authorization, order lifecycle, mobile layout, backups, and deployment.
