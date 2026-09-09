<img src="icon.svg" width="80" alt="">

# Stanza

![version](https://img.shields.io/badge/version-1.0.0-111) ![license](https://img.shields.io/badge/license-MIT-111) [![github](https://img.shields.io/badge/github-nulljosh%2Fstanza-111)](https://github.com/nulljosh/stanza)

Live at [stanza.heyitsmejosh.com](https://stanza.heyitsmejosh.com).

Every social network is loud. A poem needs silence around it. Feeds bury it under everything else. Counters turn it into a score. Comments turn it into an argument. That's the gap.

Stanza is a place to post poems and nothing else. You sign in, pick a name, and publish. Each poem gets its own page. Your name gets a page with all of them. The front page is everyone's, newest first.

> You write a poem at midnight. You post it. In the morning it's still there, on its own page, with your name on it. Nobody counted anything.

That's it. That's the whole product.

The obvious thing is a blog. A blog is a house with one voice. Stanza is a street of them, and you can walk it.

v0 is what you see: the feed, the poem page, the author page. v1 adds following and a quiet way to say "I read this". The business is a small yearly fee for a custom domain on your author page.

## Features

- Write, read, delete your own. Blank line between stanzas, single newlines kept
- Author pages by pen name, poem pages by id
- Email and password accounts, shared with the rest of the fleet
- Web, iPhone, iPad, Mac, Android, Windows, Linux

## Run it

```
# web: one static folder
env -u CLOUDFLARE_API_TOKEN npx wrangler deploy

# tests
node --test test.mjs

# apple
cd ios && xcodegen generate && open Stanza.xcodeproj
cd macos && xcodegen generate && open Stanza.xcodeproj

# android / windows / linux (CI builds these; needs JDK 17)
cd kmp && ./gradlew :composeApp:run
```

Backend is the shared Supabase project. One table, `stanza_poems`, row-level security: anyone reads, you insert and delete your own.
