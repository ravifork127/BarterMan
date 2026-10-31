# BarterMan

A mobile-first campus marketplace built with React, TypeScript, Vite, Tailwind CSS, React Router, Lucide, and Supabase. The visual direction follows the attached mobile references, with a responsive desktop layout.

## Run locally

1. Install Node.js 20 or newer.
2. Run `npm install`.
3. Copy `.env.example` to `.env` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` from your Supabase project.
4. Apply `supabase/migrations/001_marketplace.sql` in the Supabase SQL editor, or use the Supabase CLI linked to your project and run `supabase db push`.
5. The migration creates a public `listing-images` bucket with image type, size, and owner-folder policies.
6. Run `npm run dev`; `npm run build` runs TypeScript checks and generates `dist/`.

With no credentials, the app builds and runs in preview mode. Marketplace queries, auth, uploads, and transaction features require valid credentials and the migration to be applied. The app never inserts demo listings. No backend setup is claimed until you apply the migration in your own project.

## Features

- Live marketplace browse, search, and category filtering
- Sign up, sign in, sign out, and password recovery
- Create listings with up to five validated camera/device photos
- Offer submission and owner decisions
- Trade and rental request schema with owner decision RPCs
- Private conversation and message schema with participant-based RLS
- Activity, offer, trade, rental, profile, and listing screens

The client currently exposes the main marketplace, listing, auth, profile, my listings, activity, and messages routes. Use the database schema and RLS as the authorization boundary; never add a service-role key to a `VITE_` variable. Production deployments also need the site's origin configured in Supabase Auth redirect URLs.

## Supabase notes

The publishable/anon key is intended for browser use with RLS enabled. Profiles are provisioned by an auth trigger. The decision RPCs lock the listing while accepting offers/trades so only one competing request can reserve it; rental acceptance checks accepted date ranges while holding a listing lock. Create user accounts through the app, then apply migrations. For local Supabase CLI use, install the CLI, run `supabase init` if needed, link the project, and run `supabase db push`.

## Deploy

Set the two public `VITE_` environment variables in your host, run `npm run build`, publish `dist`, and configure Supabase Auth site and redirect URLs for the deployed origin.
## Required signup profile fields

New account creation requires full name, current semester, and phone number. The auth trigger stores the name and semester on the profile and copies the phone into `private_profile_details`, which is readable only by that account. Existing users can add/update these fields from Profile.

After applying migrations `001_marketplace.sql` and `002_private_profile_history.sql`, also run `003_required_signup_profile.sql` in Supabase SQL Editor to add semester storage and update the auth profile trigger. Supabase email confirmation settings determine whether signups must click an inbox link. The app accepts any syntactically valid email; it does not require a campus email domain.

## Buyer actions and conversations

Fixed-price sale listings use a purchase request at the listed price; the seller confirms the handoff. BarterMan does not process payment. Auctions alone accept bids, and rental listings take date-range rental requests. Buyers and sellers can continue privately in the in-app Messages screen. Run `supabase/migrations/004_buy_messaging_whatsapp.sql` after migrations 001 and 002 to install the purchase RPC and non-recursive conversation membership RLS helper.

Phone numbers are stored privately and are not currently OTP-verified or shared with sellers. Real SMS or WhatsApp OTP delivery needs an authentication provider and server-side credentials configured in Supabase; the app must not pretend verification succeeded without that provider.


### Realtime listing, request, and message updates

Apply `supabase/migrations/011_realtime_publication.sql` in the Supabase SQL Editor after the schema migrations. It safely adds the marketplace, request, and messaging tables to the `supabase_realtime` publication when they are not already included. The app subscribes to those database changes; Row Level Security still controls which rows each signed-in user can read.
