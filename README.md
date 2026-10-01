# grant-ps.com

Grant Petersen-Speelman's personal blog. Markdown is the source of truth; Claude writes each post's HTML by hand from it; small Ruby scripts do everything that must be exact.

## How it works

- **Posts** live in `site/posts/<slug>/index.md` (frontmatter plus markdown). The folder name is the slug and the URL: `https://grant-ps.com/posts/<slug>/`. Once published, a slug never changes.
- **Drafts** live in `drafts/<slug>/`, which is gitignored.
- **Pages** (`site/posts/<slug>/index.html`, `site/index.html`, `site/404.html`) are written by Claude following `design/BRIEF.md` (engineering notebook, mobile first, WCAG 2.2 AA) and the mandatory shell in `design/shell.md`.
- **Feed and sitemap** (`site/feed.xml`, `site/sitemap.xml`) are built by `bin/meta` straight from the markdown. Never edit them by hand.
- **Fidelity guard** (`bin/guard`) proves each page contains the author's words exactly, in order. It runs in the pre-commit hook.
- **Deploy** is dumb: Cloudflare serves the committed `site/` folder as static assets. No build step.

## Publishing a post

1. Write it in `drafts/<slug>/index.md`.
2. Move the folder to `site/posts/<slug>/`.
3. In Claude Code: `/publish <slug>`. Claude writes the page, updates the home page, runs `bin/meta` and `bin/guard`, and starts a preview.
4. Review at `http://localhost:4000/posts/<slug>/`, then commit and push. Cloudflare deploys.

For a redesign, use `/regenerate-site`. The design rules are in `design/BRIEF.md` (engineering notebook, mobile first, WCAG 2.2 AA); the rejected directions are kept in `design/explorations/` (`bin/preview --dir design/explorations`).

## Deploy

Cloudflare Workers Builds deploys on every push to `main`: no build command, deploy command `npx wrangler deploy`. `wrangler.jsonc` is an assets-only Worker serving `site/`; `site/.assetsignore` keeps the markdown off the site (it stays public on GitHub). Test posts never go in `site/posts/` on `main`: they would reach the feed and dev.to.

## Commands

| Command | What it does |
|---|---|
| `bin/setup` | Install gems and the browser-check tools, wire the git hooks |
| `bin/meta` | Rebuild `feed.xml` and `sitemap.xml` (`--check` to verify only) |
| `bin/render <slug>` | Print a post's body HTML from the markdown, the starting point for its page |
| `bin/guard [slug\|--all]` | Fidelity check (default: staged posts) |
| `bin/check-pages [slug...]` | Accessibility (axe-core, light and dark), sideways-scroll and broken-asset checks, plus screenshots in `tmp/check-pages/` |
| `bin/precommit` | What the hook runs: slug checks, guard, meta check, no drafts |
| `bin/preview [slug]` | Serve `site/` on http://localhost:4000 |
| `bundle exec rake test` | Run the tests |

Frontmatter fields and rules are in `PLAN.md` section 5. The build story is in `BUILD_LOG.md`.
