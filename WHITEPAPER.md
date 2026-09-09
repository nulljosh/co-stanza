# Stanza Technical Whitepaper

**v1.0** | September 2026

Stanza is a poetry network with one table and no ranking. Poems are rows. Pages are queries over those rows. Every client, web or native, talks straight to the database through row-level security. There is no application server.

## The core mechanic

A poem is a title, a pen name, a body and a timestamp, owned by an account. The body is plain text. Blank lines separate stanzas; single newlines are kept as line breaks. That rule is the only formatting Stanza has, and it lives in one function shared by the web app and its test.

Three pages fall out of one table:

- The front page: newest fifty poems.
- An author page: poems where the pen name matches.
- A poem page: one row by id.

There is no like, follow, comment or count. The order is time. That is deliberate and it is most of the design.

## Storage

One Postgres table, `stanza_poems`, on the shared Supabase project the rest of the fleet uses. Row-level security does the authorization: any request may read, an authenticated user may insert rows carrying their own id, and may delete only those. Length checks on title, name and body are database constraints, not client code, so every platform gets them for free.

## Clients

The web app is a single static HTML file plus a small module of pure functions. It loads the Supabase JS client from a CDN and routes on the URL hash. Accounts are email and password; confirmation mail is branded by the fleet's authmail Worker.

The iOS and macOS apps share one SwiftUI file. They use URLSession against the PostgREST and GoTrue endpoints directly, with the same anon key that ships in the web bundle. The session token is kept in UserDefaults.

Android, Windows and Linux come from one Kotlin Multiplatform module. A Ktor client in `shared` mirrors the Swift store; a Compose screen in `composeApp` mirrors the web layout. GitHub Actions builds the msi, deb and apk.

## Hosting

Cloudflare Workers serves the `web/` folder as static assets on `stanza.heyitsmejosh.com`. Deploys are one wrangler command. There is nothing to run.

## What is left out, and why

No server means no moderation queue, no rate limit beyond Supabase's, no search. Those come when there are enough poems to need them. Kudos, in the Svbtle sense, is the first feature on the list; it is one more table and a unique constraint.

MIT 2026 Joshua Trommel
