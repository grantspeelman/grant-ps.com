# Build log

Append-only. Times are UTC. Written as the work happens.

## Session start: 2026-09-27 16:00

Environment: Docker sandbox (`bin/sandbox`), Ruby 4.0.7, Bundler 4.0.20, Node 22. Repo has one commit (`PLAN.md` plus two grill-me skills). No git remote, `gh` not authenticated, so nothing is pushed from here.

Before starting, the auto-grill-me gate asked Grant one question the plan did not answer: whether to commit during the build. Answer: one local commit per phase on `main`, nothing pushed. Wait: under a minute.

## Phase 1: Scaffold

- Start: 16:03
- End: 16:04. Elapsed: about 1 min.
- Did: `.gitignore` (adds `drafts/`, bundle and wrangler dirs), `Gemfile` (commonmarker 2.10, nokogiri 1.19, webrick, minitest 6, rake), `site.yml` exactly as specified, `bin/setup`, `README.md`, `CLAUDE.md`, directory skeleton.
- Also committed the sandbox setup that predates this session (`.devcontainer/`, `bin/sandbox`, `.env.example`, `.claude/settings.json`), since it is part of how this was built.
- Surprise: the sandbox runs Ruby 4.0.7, well past the plan's "3.3+". Gemfile says `>= 3.3`.
- Unplanned decision: added `rake` to the test group so `bundle exec rake test` is the single test entry point.
- Snag: first commit failed, no git identity in the sandbox. Set a repo-local identity matching the author of the initial commit.

## Phase 2: Tooling

- Start: 16:05. End: 16:09.
- Did: `lib/blog/` (site config, post and frontmatter validation, the single markdown renderer, block extraction, guard, feed and sitemap, precommit), `bin/meta`, `bin/guard`, `bin/precommit`, `bin/preview`, `Rakefile`, 40 minitest tests over a fixture root in `test/fixtures/root/` (never under `site/`).
- Renderer: Commonmarker 2 with defaults changed. Out of the box it adds heading anchor links (extra hrefs) and inline-styled syntect highlighting in code blocks, neither of which belongs in a feed. Turned off `header_ids` and the syntax highlighter, smart punctuation off, raw HTML allowed, GFM tables, task lists, autolinks, strikethrough and footnotes on.
- Guard design: a block's text is its *own* text, with nested blocks pulled out as separate blocks in document order. That makes loose lists (`<li><p>..</p></li>`) and tight lists (`<li>..</li>`) compare equal, so Claude is free with wrappers. Text outside any block inside `[data-post-body]` is a "loose text" block, so added words between blocks are caught too. Only ASCII whitespace collapses; a non-breaking space counts as a character. Block tags are not compared, only text, so a heading styled as a different level passes; the words are what is guarded.
- Precommit design: rather than checking the working tree, it exports the git index (`git checkout-index`) to a temp dir and runs everything against that, so it checks exactly what will be committed. There is a test for "fixed in working tree but not staged".
- Snags: Ruby's `Time#rfc2822` emits `-0000` for UTC ("unknown zone"), switched to an explicit `+0000`. Scripts needed `bundler/setup` loaded from `lib/blog.rb`. `pkill` is not in the sandbox image.
- Unplanned decisions:
  - Required frontmatter: `title`, `slug`, `date`, `description`. `tags` optional (dev.to accepts none). Unknown fields are rejected, to catch typos like `tag:`.
  - Feed channel `<description>` is "Writing by <author>" unless `site.yml` gets a `description`; `<language>` defaults to `en`. `<lastBuildDate>` comes from the newest post date, not the clock, to keep output byte-stable.
  - `<enclosure>` needs `length` and `type` per RSS 2.0, taken from the image file.
  - `bin/preview` mirrors Cloudflare's auto-trailing-slash (redirects `/x/index.html` and `/x.html`), serves `404.html` on misses, and hides whatever `site/.assetsignore` lists. Added `--dir` so the design explorations can be served too.

## Phase 3: Hook

- Start: 16:09. End: 16:09.
- Did: `.githooks/pre-commit` execs `bin/precommit`; `bin/setup` sets `core.hooksPath`. Ran `bin/setup` here and in a throwaway clone, then drove real `git commit`s in the clone:
  1. file under `drafts/` force-added: blocked
  2. new post without rebuilding the feed: blocked (feed and sitemap out of date)
  3. page with a paragraph dropped: blocked by guard
  4. frontmatter slug differs from folder: blocked
  5. clean post plus rebuilt feed: allowed
  6. renaming a published post: blocked (frozen slug)
  7. same rename with `ALLOW_SLUG_CHANGE=1`: warning printed; still blocked until the page's canonical URL was updated too, then allowed. Good: the escape hatch lifts the slug freeze only, not the fidelity checks.
- The same cases (minus the real `git commit`) are in `test/precommit_test.rb`, so they stay proven.
- Snag: my first proof script ran in a fresh clone where `site/posts/` did not exist (git does not track empty dirs), so `cp -r` put the fixture files straight into `site/posts/` and the hook correctly saw no posts. My mistake, not the hook's. Re-ran with the directory created.
- This commit is the first one in the real repo to go through the hook.

## Phase 4: Design explorations

- Start: about 16:10; file times show the first session wrote the explorations between 16:12 and 16:15, then was cut off before logging. Picked up by a second session at 16:26. End (checkpoint message to Grant): not recorded, shortly after 16:26.
- Did: three directions under `design/explorations/a|b|c/`, each a home page and a sample post built from `sample/index.md` (PLAN section 1 plus the Wrangler snippet, so a code block is shown). A: editorial (Newsreader serif, warm paper, drop cap). B: engineering notebook (IBM Plex Sans with JetBrains Mono, graph paper, a margin column for metadata). C: bold (Bricolage Grotesque, cobalt, coral and lemon, hard shadows, plus an animated time budget dial as a flare example). Fonts are self-hosted woff2, no third-party requests. `design/explorations/index.html` is a chooser page.
- Checked on pickup: all three posts pass `bin/guard` against the sample markdown (run in scratch roots, never under `site/`), all pages meet the shell checklist in PLAN 7.2, no em-dashes. Screenshotted every page at 1280px and 390px with Playwright.
- The screenshots found four bugs that the guard could not catch, because the guard only checks words:
  1. In all three designs, consecutive paragraphs had no gap between them. `.prose p { margin: 0 }` outranked `.prose > * + *` on specificity. Fixed with `.prose :where(p)` placed before the spacing rule.
  2. C's home page name overflowed the screen at phone width. Smaller minimum size for the hero heading.
  3. B rendered the non-breaking hyphen (U+2011) in "Petersen-Speelman" as a fallback glyph that sat mid-word, because the font subset does not include it. Replaced it in all three with a normal hyphen inside a `white-space: nowrap` span.
  4. In B, the header link and `<main>` on the home page both used the class `.home`, so the main area's padding leaked into the header and pushed the wordmark out of line with the Source link. Renamed the link's class to `.wordmark`.
- Lesson for post #1: the guard proves the words are right, but only looking at the page proves it reads right. Screenshots at two widths should be part of `/publish`.
- Waiting on Grant: design pick.

### Phase 4, continued: direction D

- Ended 18:02 (start time not recorded). Grant looked at the three and asked for a fourth: combine B and C, keeping web accessibility best practice.
- Did: `design/explorations/d/`. B's structure (graph paper, margin column, mono labels, terminal code blocks, dark mode) with C's palette, display type, hard shadows and the dial flare. The margin column became a lemon sticky note; the post header became a cobalt band with the notebook grid drawn in white.
- Accessibility decisions, where C would have failed: coral is decoration only (coral text on cream is 2.9:1); dark mode swaps links to a light periwinkle rather than keeping cobalt; the focus ring changes colour per surface (cobalt on paper, lemon on the dark bars, ink on the lemon note) so it never vanishes; the blinking cursor stops after four blinks (WCAG 2.2.2) and not at all under reduced motion; decorative `##`, `->` and `~/` use CSS alt text or `aria-hidden`; `$ ls -t posts/` style labels are hidden from screen readers and the real headings read "Writing" and "Writing elsewhere"; code blocks get `tabindex="0"` so keyboard users can scroll them; whole-card click targets on the home page use a stretched link so the link's name is just the title; `scroll-padding-top` stops the sticky header covering focused elements; a forced-colours block keeps borders when shadows disappear.
- Checked: guard passes; axe-core (WCAG 2.2 AA plus best practice) reports 0 violations in light and dark; axe cannot measure contrast over the grid gradient, so every text colour pair was computed by hand against the worst case (a grid line behind the text): all pass AA, tightest is the lemon label on the cobalt band at 4.59:1; keyboard tab order checked with a visible ring at every stop.
- Snags: the name overflowed at 320px because it was set not to wrap; now it may break at its hyphen on very narrow screens. axe reported two 404s for `fonts.css`: an axe artifact (it resolves `@import` against the page URL), the fonts load fine in a normal page load.
- Still waiting on Grant: design pick.

### Phase 4 checkpoint: Grant picked B

- 18:16. Grant picked **B, Engineering notebook**, with two conditions: mobile first, and web accessibility best practice, tweaking B where needed. This entry was written at 18:16, after the B tweaks; the moment of the pick was not timed. Wall time from the first checkpoint message to here was about 16:30 to 18:16, covering Grant reviewing, a port-forwarding question, building D and tweaking B. How much of that was waiting on Grant was not recorded.
- Tweaks to B, most carried over from what D taught:
  - Rewrote the stylesheet mobile first: base styles are for a phone, `min-width` queries add the margin column, larger type and rounded code blocks. B had two `max-width` queries; none remain.
  - Post markup is now header, details, body, footer in source order. On phones the details sit under the title; on wide screens grid placement lifts them into the sticky margin column. Before, they came before the title in the source, so screen readers heard the metadata first.
  - Darkened the light-mode green from 4.63:1 to 5.77:1 against the grid, so it is not sitting on the AA line.
  - Blinking cursor stops after four blinks (it blinked forever, a WCAG 2.2.2 failure) and not at all under reduced motion.
  - `## `, `-> `, `[ ]` and `~/` are hidden from screen readers. The home page headings were literally "ls -t posts/" and "cat writing-elsewhere.txt" to a screen reader; now the command is a decorative line and the headings say "Writing" and "Writing elsewhere".
  - Footer links renamed from "feed.xml" and "github" to "RSS feed" and "Source on GitHub", so their purpose is clear out of context. Added an "All writing" link at the end of each post.
  - Focus ring is solid and 3px (was 2px dashed); tap targets padded to at least 24px; code blocks are keyboard-scrollable; `scroll-padding-top` clears the sticky bar; tags are real lists.
- Checked: guard passes; axe-core 0 violations in light and dark; no horizontal overflow at 320, 390 or 1280; tab order logical with a visible ring at every stop.
- Phase 4 end: 18:16.

## Phase 5: Brief and skills

- Start: 18:16 (phase 4 commit). End: 18:28 (commit).
- Did: `design/BRIEF.md` (the engineering notebook as rules: principles, type, colour tokens with contrast, layout, components, flare rules, an accessibility checklist); `design/shell.md` (exact head, chrome, post, home and 404 skeletons with placeholders); both skills; `site/assets/style.css` and fonts from B; `site/index.html` (no posts yet), `site/404.html`, `site/robots.txt`; `site/assets/og-default.png`, rendered from `design/og-default.html` so it can be redone after a redesign.
- Two new tools, neither in the plan:
  - `bin/render <slug>`: prints a post's body from the same renderer the guard uses. Reason: the safest way for Claude to get the words exactly right is to never retype them. It also makes the one mechanical change the shell needs: the renderer emits `<pre lang="ruby">`, and `lang` means a *human* language, so a screen reader may switch voice for the code. It becomes `data-lang` plus `tabindex="0"`. Two new tests: the transform, and a fixture page rebuilt from `bin/render` output passing the guard (42 tests now).
  - `bin/check-pages [slug...]`: axe-core in light and dark, sideways-scroll at 320, 390 and 1280px, failed requests and JS errors, plus phone and desktop screenshots in `tmp/check-pages/` (gitignored). Reason: Grant made accessibility a condition of the design, and phase 4 showed that looking at the page finds bugs the guard cannot. `/publish` runs it and tells Claude to look at the screenshots. Proved it fails by breaking the 404 page (no `lang`, an image with no alt, a too-wide image): 10 problems reported, exit 1. It is dev-only: `package.json` pins `axe-core` and `playwright`; the pre-commit hook does not depend on Node.
- Snags:
  - The two IBM Plex Sans files (400 and 600) were byte-identical. It is a variable font, so both weights were real, not faked bold; the site now ships one file with `font-weight: 400 700`. No Python font tools in the sandbox, so I proved it in the browser: with `font-synthesis: none`, 600 still renders wider than 400.
  - `bin/setup` hung on `npx playwright install chromium`: the sandbox's browsers live in a root-owned `/opt/playwright-browsers`. Setup now installs a browser only if Playwright cannot find one.
  - The 404 page's canonical was `/404.html`, but Cloudflare's auto-trailing-slash serves it at `/404`. Fixed in the page and the shell.
- Unplanned decisions: the 404 page is `noindex`; the home page shows "No posts yet." with no posts; fonts preload the body face only.

## Phase 6: End to end with a fixture

- Start: 18:28. End: 18:31 (commit).
- Did: a git worktree on a throwaway branch `e2e-fixture`, outside the repo folder, so nothing could land in `site/posts/` on main. A fixture draft built to be awkward: curly quotes and `&` in the title, a relative link, a table, an image used as `og_image`, a code block with `&`, `<` and `#{}`, a footnote. Then `/publish` by the book: moved it from `drafts/`, `bin/render`, page per the shell with a small decorative flare strip, home page updated, `bin/meta`, `bin/guard`, `bin/check-pages`, looked at the screenshots.
- Results: guard passed first time (quotes and entities intact); feed item correct: guid equals the canonical URL, every `src` and `href` absolute (the relative `../` link and the footnote anchors too), the image as `<enclosure>` with length and type, one `<category>` per tag. The real hook allowed a clean commit on the branch and blocked one with a single word changed in the page, printing the diff.
- Then `/regenerate-site` by the book: a mini redesign (light-mode accent green to blue, contrast checked first: 6.33:1), post page regenerated from `bin/render`. The regenerated page came out byte-identical; feed, sitemap and markdown unchanged; `guard --all` and `check-pages` passed.
- Removed completely: worktree removed, branch deleted, `site/posts/` on main empty, feed has no items, no branch contains the fixture commit. Nothing was pushed.
- The screenshots caught two real problems, both now fixed on main:
  1. Footnotes ran straight on from the last paragraph. They now sit under a dashed rule with a small "footnotes" label, and the shell tells Claude to add `aria-label="Footnotes"` to the section, since the CSS label is hidden from screen readers.
  2. JetBrains Mono's ligatures merged `#{` into one glyph inside code, so the code on screen was not quite the code in the post. Ligatures are now off in code (still on for the decorative `->` markers).

## Phase 7: Deploy config

- Start: 18:31. End: 18:32 (commit).
- Did: `wrangler.jsonc` (assets-only, `directory: ./site`, `auto-trailing-slash`, `404-page`, compatibility date today) and `site/.assetsignore` (`*.md`, the ignore file itself, `.DS_Store`). The minimal live site was already in place from phase 5: home page with no posts, 404, robots.txt, and an empty but valid feed (well-formed RSS 2.0 with channel title, link and description) plus a sitemap listing the home page.
- Checked against Cloudflare's docs rather than the plan's snippet, as the plan asked: the snippet was right. `main` can be omitted for assets-only, `.assetsignore` uses gitignore syntax in the assets folder. Left out the docs' `$schema` line, since it points into a local `node_modules/wrangler` this repo does not install.
- Proved with the real Wrangler (4.142.0, via npx, not added to the repo): `wrangler deploy --dry-run` with a planted `site/zz-test.md` accepts the config and logs "Ignoring asset" for the markdown and the ignore file. It reported "Read 16 files": 13 files plus 3 directories. No account or token was needed, and nothing was deployed.
- `bin/preview` matches: markdown and `.assetsignore` return 404, `/404` and unknown URLs get the 404 page.
- Not done here, Grant's manual steps: connecting Workers Builds, the `workers.dev` check, the custom domain and the www redirect.

## Phase 8: Hand-off

- Start: 18:32. End: 18:33.
- Did: README gained design and deploy sections (still under a page). Proved the definition of done on a fresh clone: `bin/setup` installs gems and the browser-check tools and wires the hook; 42 tests pass; `bin/meta --check`, `bin/guard --all` and `bin/check-pages` pass.
- Correction: some start times I wrote in the phase 4 to 7 entries were estimates, not clock readings (one "start" came after its own "end"). I replaced them with times backed by the clock, commit timestamps or file times, and marked the rest "not recorded". Lesson: run `date` at the start of a phase, not only at the end.
- Left uncommitted on purpose: `.devcontainer/Dockerfile` (adds Playwright, bubblewrap and socat to the sandbox image). Grant made that change outside this build; `bin/check-pages` relies on the Playwright browsers it installs when run in the sandbox.

## Summary

- **Time:** session started 16:00, finished at 18:33: about 2 hours 35 minutes of wall time, inside the 3 hour budget. That includes time waiting on Grant at the design checkpoint, which was not timed, and the extra direction D he asked for.
- **Went smoothly:** the Ruby tooling. Guard, feed, sitemap and pre-commit were right first time in the end-to-end run: curly quotes, entities and relative links all survived, and the hook blocked a one-word change. Regenerating a page from `bin/render` gave byte-identical output, which is the property that makes "reinvent the site from the markdown" safe.
- **Harder than expected:** everything the guard cannot see. Screenshots found eight visual or accessibility bugs across phases 4 to 6 (missing paragraph spacing, overflow, a font missing a glyph, a class clash, footnotes, code ligatures, a metadata order that put details before the title for screen readers), none of which a text check would catch. Accessibility turned out to be many small decisions (focus colours per surface, decorative glyphs, a cursor that must stop blinking), and automated contrast checks cannot see through a gradient background, so contrast had to be computed by hand.
- **Would do differently:** build the screenshot and axe checker (`bin/check-pages`) in phase 2 with the other tools, not in phase 5, and ask about accessibility and mobile requirements before the explorations, not after. Timestamp each phase at its start.
- **Unplanned additions:** `bin/render`, `bin/check-pages`, `package.json` (dev-only), a fourth design direction, `design/og-default.html`.
