---
name: regenerate-site
description: "Redesign or rebuild the whole grant-ps.com site: agree a new or revised design brief with Grant, then regenerate every post page, the home page and the 404 page from the markdown. Use when Grant says '/regenerate-site', 'redesign the site', 'rebuild all the pages', 'change the look of the blog', or asks for a change to the shell or shared CSS that affects every page. For a single post, use publish."
---

# /regenerate-site

A redesign changes how the site looks. It never changes what the site says or where things live.

## Never changes in a redesign

- **URLs and slugs.** Every post stays at `/posts/<slug>/`; folder names and frontmatter slugs are frozen.
- **Feed guids.** `bin/meta` derives them from the URL, so they stay the same as long as the URLs do. Changing one makes dev.to import the post again as a duplicate.
- **The markdown.** Do not touch any `index.md`, including "harmless" fixes.
- **The rules in `/publish`**: exact words, the shell, no em-dashes in copy you write, flare degrades gracefully, WCAG 2.2 AA, mobile first, no invented facts about Grant.

## Steps

### 1. Agree the design with Grant

- Read `design/BRIEF.md`, `design/shell.md` and `site/assets/style.css`.
- Work out with Grant what is changing and why. If the change is large, offer to produce explorations first (as in the original build: static pages under `design/explorations/<letter>/`, each with a home page and a sample post, viewable with `bin/preview --dir design/explorations`) and let him pick. Do not pick for him.
- Update `design/BRIEF.md` to describe the new design (principles, type, colour with contrast checked in light and dark, layout, components, flare rules, accessibility checklist). Update `design/shell.md` only if the page skeleton itself changes; the shell requirements in it (canonical, social tags, feed link, analytics, header, footer, post metadata, source link) remain mandatory.
- Update `site/assets/style.css` and fonts in `site/assets/fonts/`. If the default social card should change, edit `design/og-default.html` and run `bin/check-pages --og`.

### 2. Regenerate every page

For each post in `site/posts/` (list them with `ls site/posts`), rewrite `index.html` following steps 3 and 6 of the `/publish` skill: body from `bin/render <slug>`, shell from `design/shell.md`, and `bin/guard <slug>` until it passes. Existing flare: keep it if it still fits the new design, restyle it if needed; it is part of that post, so do not drop it silently. Tell Grant if you think a post's flare no longer works.

Then regenerate `site/index.html` (step 4 of `/publish`, with the intro from `bin/render --intro`) and `site/404.html` (the "404 main" in `design/shell.md`).

### 3. Check everything

- `bin/meta`, then `git diff --stat site/feed.xml site/sitemap.xml`: a redesign should leave both unchanged. If they changed, something other than the look changed; find out what before going on.
- `bin/guard --all`: every post and the home page intro must pass.
- `bin/check-pages`: all pages, both colour schemes, three widths. Then look at the screenshots in `tmp/check-pages/`.
- `git diff --stat -- 'site/posts/*/index.md'` must be empty.

### 4. Preview and hand over

Start `bin/preview` in the background and give Grant `http://localhost:4000/`. Summarise what changed, anything flagged, and that nothing is committed. He reviews, commits and pushes.
