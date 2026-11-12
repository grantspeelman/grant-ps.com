# grant-ps.com

Grant Petersen-Speelman's personal blog. Markdown is the source of truth; Claude writes each post's HTML by hand from it; small Ruby scripts do everything that must be exact.

## How it works

- **Posts** live in `site/posts/<slug>/index.md` (frontmatter plus markdown). The folder name is the slug and the URL: `https://grant-ps.com/posts/<slug>/`. Once published, a slug never changes.
- **Drafts** live in `drafts/<slug>/`, which is gitignored.
- **Pages** (`site/posts/<slug>/index.html`, `site/index.html`, `site/404.html`) are written by Claude following `design/BRIEF.md` (engineering notebook, mobile first, WCAG 2.2 AA) and the mandatory shell in `design/shell.md`.
- **Feed and sitemap** (`site/feed.xml`, `site/sitemap.xml`) are built by `bin/meta` straight from the markdown. Never edit them by hand.
- **Home page intro** lives in `site/intro.md` (plain markdown, no frontmatter) and is guarded like a post.
- **Fidelity guard** (`bin/guard`) proves each page contains the author's words exactly, in order. It runs in the pre-commit hook.
- **Deploy** is dumb: Cloudflare serves the committed `site/` folder as static assets. No build step.

## Publishing a post

1. Write it in `drafts/<slug>/index.md`.
2. Move the folder to `site/posts/<slug>/`.
3. In Claude Code: `/publish <slug>`. Claude writes the page, updates the home page, runs `bin/meta` and `bin/guard`, and starts a preview.
4. Review at `http://localhost:4000/posts/<slug>/`, then commit and push. Cloudflare deploys.

For a redesign, use `/regenerate-site`. The design rules are in `design/BRIEF.md` (engineering notebook, mobile first, WCAG 2.2 AA); the rejected directions are kept in `design/explorations/` (`bin/preview --dir design/explorations`).

## Deploy

Cloudflare Workers Builds deploys on every push to `main`: no build command, deploy command `npx wrangler deploy`. Other branches get a preview deployment from `npx wrangler preview`, which needs the `previews` block in `wrangler.jsonc`. `wrangler.jsonc` is an assets-only Worker serving `site/`; `site/.assetsignore` keeps the markdown off the site (it stays public on GitHub). Test posts never go in `site/posts/` on `main`: they would reach the feed and dev.to.

## Commands

| Command | What it does |
|---|---|
| `bin/setup` | Install gems and the browser-check tools, wire the git hooks |
| `bin/meta` | Rebuild `feed.xml` and `sitemap.xml` (`--check` to verify only) |
| `bin/render <slug>` | Print a post's body HTML from the markdown, the starting point for its page (`--intro` for the home page intro) |
| `bin/guard [slug\|--intro\|--all]` | Fidelity check (default: staged posts, plus the intro if the home page or `site/intro.md` is staged) |
| `bin/check-pages [slug...]` | Accessibility (axe-core, light and dark), sideways-scroll and broken-asset checks, plus screenshots in `tmp/check-pages/` |
| `bin/em-dashes [file...]` | Fail on an em-dash in any page copy outside the author's text (`[data-post-body]`, `[data-intro]`); default: every `site/**/*.html` |
| `bin/precommit` | What the hook runs: slug checks, guard, meta check, em-dashes in staged pages, no drafts |
| `bin/preview [slug]` | Serve `site/` on http://localhost:4000 |
| `bundle exec rake test` | Run the tests (including a check that `site.yml` and `wrangler.jsonc` parse) |
| `bundle exec standardrb` | Ruby style check with [Standard](https://github.com/standardrb/standard) (`--fix` to correct); config in `.standard.yml` |

CI (`.github/workflows/checks.yml`) runs the tests, `standardrb`, `bin/guard --all`, `bin/meta --check` and `bin/em-dashes`, plus [actionlint](https://github.com/rhysd/actionlint) on the workflows and a gitleaks scan of the full history.

Frontmatter fields and rules are in `PLAN.md` section 5. The build story is in `BUILD_LOG.md`.

## Where things live

A map for agents (and Grant): which file owns each concern, which test covers it, and which commands prove a change. To run one test file: `bundle exec ruby -Ilib -Itest test/meta_test.rb` (add `-n test_sitemap` for one test). Use `bundle exec` here; plain `ruby` can fail on gem versions. The `bin/` scripts don't need it, because `lib/blog.rb` sets `BUNDLE_GEMFILE`.

| Concern | Owned by | Covered by | Proves a change |
|---|---|---|---|
| Frontmatter validation | `lib/blog/post.rb` (fields: `PLAN.md` section 5) | `test/post_test.rb` | `bundle exec rake test`, `bin/meta --check` |
| Markdown rendering | `lib/blog/markdown.rb`, `bin/render` | `test/guard_test.rb`, `test/meta_test.rb` | `bundle exec rake test`, `bin/guard --all`, `bin/meta --check` |
| Block extraction, fidelity guard | `lib/blog/blocks.rb`, `lib/blog/guard.rb`, `bin/guard` | `test/guard_test.rb`, `test/commands_test.rb` | `bundle exec rake test`, `bin/guard --all` |
| Feed and sitemap | `lib/blog/meta.rb`, `bin/meta` | `test/meta_test.rb`, `test/commands_test.rb` | `bundle exec rake test`, `bin/meta --check` |
| Pre-commit checks, slug freeze | `lib/blog/precommit.rb`, `bin/precommit`, `.githooks/pre-commit` | `test/precommit_test.rb` | `bundle exec rake test`, then `bin/precommit` with the change staged |
| Site config | `lib/blog/site.rb`, `site.yml` | `test/config_test.rb` (the real `site.yml`), every other test through `test/fixtures/root/site.yml` | `bundle exec rake test`, `bin/guard --all`, `bin/meta --check` |
| Em-dashes in page copy | `lib/blog/em_dash_check.rb`, `bin/em-dashes` | `test/em_dash_check_test.rb`, `test/precommit_test.rb` | `bundle exec rake test`, `bin/em-dashes` |
| Ruby style | `.standard.yml`, `Gemfile` | none; it is the check | `bundle exec standardrb` |
| Browser checks | `bin/check-pages`, `package.json` | none; it is the check | `bin/check-pages` |
| Preview | `bin/preview` (mirrors Cloudflare's trailing slashes, 404 page and `.assetsignore`) | `bin/check-pages` runs on it | `bin/preview`, then http://localhost:4000/ |
| Deploy config | `wrangler.jsonc`, `site/.assetsignore` | `test/config_test.rb` (`wrangler.jsonc` settings) | `bin/preview` for `.assetsignore`; the rest only on a Cloudflare preview deployment of a pushed branch |
| Page shell and design | `design/shell.md`, `design/BRIEF.md`, `site/assets/` | `bin/guard` (words), `bin/check-pages` (accessibility, layout) | `bin/guard --all`, `bin/check-pages` |
| Skills | `.claude/skills/publish/SKILL.md`, `.claude/skills/regenerate-site/SKILL.md` | none | run the skill, which ends with its own checks |
| CI | `.github/workflows/checks.yml`, `.github/workflows/devcontainer-ci.yml` | actionlint, in CI only | push a branch and open a pull request |
| Dev container | `.devcontainer/` (start at `.devcontainer/README.md`) | `.devcontainer/container-structure-test.yaml`, `.devcontainer/smoke-test.sh` | `.github/workflows/devcontainer-ci.yml`, which runs when `.devcontainer/` changes |

### Environment and services

- **Ruby and Bundler** (`Gemfile`: Ruby 3.3 or later; CI and the dev container use 4.0.7), plus **git**, which `bin/precommit` and `test/precommit_test.rb` call. That is all the tests, `bin/guard`, `bin/meta`, `bin/render` and `bin/preview` need.
- **Node and npm** only for `bin/check-pages` (Playwright's Chromium and axe-core from `package.json`). It starts `bin/preview` itself.
- **No services**: no database, no server to start, no API keys. Tests work on temp copies of `test/fixtures/root/`.
- **Environment variables**: `ALLOW_SLUG_CHANGE=1` is the only override the code reads; it lets `bin/precommit` pass a deleted or renamed published post, with a warning. `BUNDLE_GEMFILE` is set by `lib/blog.rb` when unset.
- **Network** only for `bin/setup` (gems, npm packages, Chromium).
- **gitleaks** ships in the dev container; elsewhere the hook skips the staged scan with a warning.
- **Cloudflare** only at deploy, through Workers Builds on push. Nothing local needs a Cloudflare account or token.

### What CI runs and what only the hook runs

| Check | Pre-commit hook (`.githooks/pre-commit`, then `bin/precommit`) | CI (`.github/workflows/checks.yml`) |
|---|---|---|
| Tests | no | `bundle exec rake test` |
| Ruby style | no | `bundle exec standardrb` |
| Em-dashes in page copy | staged pages | `bin/em-dashes` |
| Workflow files | no | actionlint |
| Fidelity guard | staged posts, and the intro if `site/index.html` or `site/intro.md` is staged | `bin/guard --all` |
| Frontmatter | staged posts | through `bin/guard --all` and `bin/meta --check` |
| Feed and sitemap up to date | yes | `bin/meta --check` |
| Slug freeze (published post deleted or renamed) | yes | no |
| Nothing staged under `drafts/` | yes | no |
| Secret scan (gitleaks) | staged changes, if gitleaks is installed | full history |

The hook checks the staged snapshot, not the working tree. The dev container image is built and tested by `.github/workflows/devcontainer-ci.yml`, only when `.devcontainer/` or that workflow changes.

### Never do, or ask Grant first

- Change the author's words in any `index.md` or `site/intro.md`: `CLAUDE.md`, both skills.
- Change a published slug or URL: `CLAUDE.md`, `.claude/skills/regenerate-site/SKILL.md`, and the hook (`ALLOW_SLUG_CHANGE=1`).
- Write post content, or invent facts about Grant (use `TODO(grant)`): `CLAUDE.md`, `PLAN.md` section 13.
- Pick a design direction: `.claude/skills/regenerate-site/SKILL.md` step 1, `PLAN.md` section 13.
- Commit after `/publish` or `/regenerate-site`; Grant reviews, commits and pushes: both skills.
- Guess which draft or slug Grant means: `.claude/skills/publish/SKILL.md`.
- Commit `drafts/`, fixture or test posts under `site/posts/`, or secrets: `CLAUDE.md`, `PLAN.md` section 13.
- Add features `PLAN.md` section 3 rules out: `PLAN.md` section 13.
