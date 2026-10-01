---
name: publish
description: "Publish one blog post on grant-ps.com: turn site/posts/<slug>/index.md into its hand-written HTML page, update the home page, rebuild the feed and sitemap, and prove the page is faithful and accessible. Use when Grant says '/publish <slug>', 'publish <slug>', 'generate the page for <slug>', or has just moved a draft into site/posts/. Not for redesigns of the whole site (use regenerate-site)."
---

# /publish &lt;slug&gt;

You are turning Grant's markdown into a page. The markdown is the text; the page is your design work around it. Do the steps in order and do not skip the checks.

## Rules (read these every time)

- **Never alter, add to, reorder or omit the author's prose.** Not a typo, not a quote mark, not a heading. The markdown is the text; if the page and the markdown disagree, the page is wrong. Never edit `index.md` to make a check pass. If you believe the markdown has a mistake, tell Grant and leave it.
- **Never change a published slug or its URL.** The folder name, frontmatter `slug` and URL `/posts/<slug>/` are frozen once the post has been committed.
- **Every page uses the shell in `design/shell.md`**, and follows `design/BRIEF.md` (engineering notebook, mobile first, WCAG 2.2 AA).
- **No em-dashes** in any copy you write: page chrome, alt text you add, captions, labels. Use commas, colons or full stops. (The author's own words are theirs; leave them.)
- **Flare degrades gracefully**: the post reads correctly with flare JS disabled and with `prefers-reduced-motion`. Flare lives in `[data-flare]` elements or `flare.*` files in the post folder.
- **Do not invent facts about Grant.** Anything you would need to make up becomes a `TODO(grant)` placeholder.
- **Do not commit.** Grant reviews, then commits and pushes.

## Steps

### 1. Find and validate the post

- The post must be at `site/posts/<slug>/index.md`. If it is still in `drafts/<slug>/`, move the whole folder to `site/posts/<slug>/` (ask Grant first if there is any doubt about which draft or slug he means).
- Frontmatter must validate. Run `bin/meta`; it refuses to build and names the problem if any post's frontmatter is invalid (missing field, slug not matching the folder, bad tags, missing `og_image` file). Fix frontmatter problems with Grant, not on your own, unless it is purely mechanical and he agrees.
- Note whether this post is already published: `git ls-files site/posts/<slug>/index.md` prints the path if it has been committed. If so, the slug is frozen, and this run is a re-render.

### 2. Read the design

Read `design/BRIEF.md` and `design/shell.md` in full, and `site/assets/style.css` for the class names. Read the whole of `index.md` before designing anything: decide what, if anything, deserves flare.

### 3. Write `site/posts/<slug>/index.html`

- Follow the shell exactly: head, chrome, the post main. Fill placeholders from `site.yml` and the frontmatter.
- Get the body from `bin/render <slug>`. Paste it into `[data-post-body]`. Then only the changes `design/shell.md` lists (table wrappers, a leading `#` heading demoted to `h2`). Add classes and wrapper elements freely; never touch the words, their order, link `href`s or image `src`s.
- Images: keep the author's alt text. If an image has empty alt text but clearly carries meaning, tell Grant in your summary; do not write one.
- Flare (optional): only if it helps this post's point, within the brief's "Flare" rules. Mark injected elements `data-flare`; decorative flare gets `aria-hidden="true"`; put CSS and JS in `site/posts/<slug>/flare.css` and `flare.js`, linked from the head as the shell describes. No external requests.

### 4. Regenerate `site/index.html`

Follow the "Home main" section of `design/shell.md`: every post in `site/posts/`, newest first (date descending, then slug, the same order as the feed), then "Writing elsewhere" from `site.yml`. The intro comes from `site/intro.md`: paste the output of `bin/render --intro` into the `data-intro` div, unchanged. If there is no `site/intro.md`, keep the `TODO(grant)` placeholder. Never write or edit `site/intro.md`; it is Grant's text, like a post.

### 5. Build the feed and sitemap

Run `bin/meta`. Never edit `site/feed.xml` or `site/sitemap.xml` by hand.

### 6. Prove the words

Run `bin/guard <slug> --intro` (the post, and the home page intro against `site/intro.md`). If it fails, it prints the first mismatched block from each side and a diff: fix the HTML and run it again, until it passes. Never "fix" the markdown to match the HTML.

### 7. Prove the page works

Run `bin/check-pages <slug>`. It audits the new post, the home page and the 404 page with axe-core in light and dark mode, checks for sideways scrolling at 320, 390 and 1280px, and fails on missing files or JS errors. Fix every failure in the HTML or CSS and re-run.

Then **look** at the screenshots it saves in `tmp/check-pages/` (`<slug>-light-390.png`, `<slug>-dark-1280.png` and the rest, using the Read tool). Automated checks cannot see a heading that wraps badly, a code block that looks broken, or flare that crowds the text. Fix what looks wrong.

Finally, check the few things no tool checks:
- Tab through the page mentally from the skip link: every interactive element is reachable and in reading order, and interactive flare works from the keyboard.
- Flare: the post reads the same with `flare.js` removed.
- No em-dashes in anything you wrote: `grep -n "—" site/posts/<slug>/index.html site/index.html` should only find the author's own words.

### 8. Preview and hand over

Start `bin/preview <slug>` in the background and give Grant the URL it prints (`http://localhost:4000/posts/<slug>/`). Summarise in a few lines: what flare you added (if any) and why, anything you flagged for him (missing alt text, a suspected typo you did not touch), and that nothing is committed. He reviews, then commits and pushes; the pre-commit hook re-runs the guard and the feed check.

## If something will not pass

- Guard keeps failing on text you did not change: compare `bin/render <slug>` output with your body; you may have lost an entity (`&amp;`, `&lt;`) or a non-breaking space.
- A check contradicts a rule in this skill: the rule wins. Stop and tell Grant rather than working around it.
