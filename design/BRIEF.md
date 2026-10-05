# Design brief: engineering notebook

Grant picked direction B from the phase 4 explorations (`design/explorations/b/`), on two conditions: **mobile first**, and **web accessibility best practice**. In October 2026 the design was polished (bigger type scale, numbered entries, a prompt that shows the path, a margin ruler, sidenotes, copy buttons) without changing the identity. This brief is what every generated page follows. The page skeleton itself is in `design/shell.md`; the shared CSS is `site/assets/style.css`; the shared enhancement script is `site/assets/notebook.js`.

## Principles

1. **Reading first.** The post is the product. Chrome is quiet, small and monospaced; the words get the space.
2. **A lab notebook, not a costume.** Graph paper, a margin column, mono labels, numbered entries and terminal code blocks set the tone. Keep the metaphor light: one or two notebook touches per component, never jokes that get in the way of reading.
3. **The site describes itself.** The shell prompt in the top bar shows where you are; the home page lists posts the way `ls` would; the hero card says how the site is made. Every one of these is true, never decorative fiction.
4. **Mobile first.** Design and write CSS for a 360px phone, then add room with `min-width` queries. Never use `max-width` queries. Nothing may scroll sideways at 320px except a code block or table, inside its own scroll box.
5. **Accessible by default.** WCAG 2.2 AA is the floor, not a stretch goal (checklist below).
6. **Exact words.** Styling can wrap, highlight and rearrange visually; it never changes the author's text (the guard enforces this).
7. **Works without JavaScript.** `notebook.js` only adds conveniences (copy buttons, the ruler's reading position, sidenotes). Every page reads the same with it removed.

## Type

| Role | Face | Notes |
|---|---|---|
| Body, headings on home | IBM Plex Sans, variable 400 to 700 | 1.0625rem on phones, 1.125rem from 40rem; line-height 1.65 |
| Chrome, labels, metadata, post h2/h3, code | JetBrains Mono, variable 400 to 700 | Post h2 is mono bold with a decorative `## ` |
| Post title (h1) | Plex Sans 600 | 2.1rem phone, 2.8rem from 40rem, 3.2rem from 64rem, `text-wrap: balance` |
| Home name (h1) | Plex Sans 600 | 2.4rem phone, 3.8rem from 40rem |

Fonts are self-hosted in `site/assets/fonts/` (latin subset). No third-party font or script requests, other than the analytics beacon.

## Colour

Tokens live at the top of `site/assets/style.css`; use them, do not add raw colours to pages.

| Token | Light | Dark | Use |
|---|---|---|---|
| `--paper` | `#fbfbf7` | `#0f1412` | page ground, under a 24px grid |
| `--ink` | `#1d2320` | `#e1e8e3` | text |
| `--muted` | `#56605a` | `#9aa8a0` | secondary text, labels |
| `--accent` | `#056b4a` | `#52d6a3` | links, markers, focus ring, entry numbers |
| `--mark` | `#fff0a0` | `#3b3a16` | highlighter behind `<strong>` |
| `--rule` | `#d5dbd6` | `#2c3833` | dividers (decorative only) |
| `--card` | 2.5% ink | 3% white | fill of the hero card |
| `--term-bg` / `--term-ink` | `#121815` / `#d8e4dc` | `#070a09` / same | code blocks |

Dark mode follows the system setting (`prefers-color-scheme`); there is no toggle. Every text pair above passes AA against its worst-case ground (a grid line behind the text); the tightest is accent on the highlighter at 5.68:1. Tag pills use accent text with a 40% accent border: the border is decorative, the text is what must pass. If you add a colour, compute its contrast in both modes first.

## Layout

- One centred column, `max-width: 58rem`, 1rem side padding on phones, 1.5rem from 40rem.
- **Post:** source order is header (path label with entry number, h1, description), details (date, length, tags, source link, ruler), body, footer. On phones they stack in that order. From 52rem the details become a sticky right-aligned margin column beside the post, and the body is capped at 38rem. From 86rem sidenotes hang to the right of the body, outside the column.
- **Home:** a hero (`$ whoami`, name as h1, `$ cat intro.md`, intro line) with the `site.yml` card beside it from 52rem; then "Writing" (the ledger, newest first: entry number, date, title link, description, tags), then "Writing elsewhere" (venue, link). Each section has a decorative shell command above its heading (`$ ls -t posts/`), hidden from screen readers.
- Sticky top bar: the prompt wordmark on the left (links home; on a post it continues with the path), `[rss]` and `[source]` on the right. Footer: "RSS feed", "Source on GitHub", and the colophon "Markdown in, hand-written HTML out. No build step."

## Components

- **Prompt wordmark:** `~/grant-ps.com` with a blinking cursor (four blinks, then still). On a post page it continues with `/posts/<slug>` in muted mono, from 40rem; on phones it shows `/posts/…`. The path is `aria-hidden`: the link text stays "grant-ps.com".
- **Entry numbers:** posts are numbered in date order, oldest first, three digits (`#001`). The number appears in the ledger and in the post's label. Numbers are derived at generation time and shift only if an older post is added, which is fine: they are not identifiers, the slug is.
- **Hero card:** a `<pre class="spec">` styled as a `site.yml` file stating how the site is made (source, html, build, host, theme). Decorative (`aria-hidden`), facts only, five lines at most.
- **Ledger:** the post list. Hover on a wide screen reveals a `->` to the left of the row (decorative). The "Writing" heading carries the entry count in mono.
- **Links:** always underlined in body text. Accent colour. Thicker underline on hover.
- **Strong:** a highlighter stripe (`--mark`) behind the bottom of the text.
- **Lists:** unordered lists use a decorative `->` marker; ordered lists keep numbers with a mono accent marker.
- **Headings in a post:** every h2 and h3 gets an `id` (lower-case words joined by hyphens, unique within the page) and a trailing `<a class="anchor" href="#id" aria-label="Link to this section">` whose `#` glyph is CSS; it appears on hover and focus. The id is derived from the heading text, never added to it.
- **Code blocks:** dark terminal panel with the language label top-left and three dots top-right (both decorative); `notebook.js` adds a Copy button between them. Full-bleed on phones, rounded from 40rem. Every `<pre>` gets `tabindex="0"` so keyboard users can scroll it, and `data-lang="<language>"` for the label (never `lang`, which means a human language).
- **Inline code:** mono, thin border.
- **Blockquote:** muted text, rule on the left.
- **Images:** full column width at most, thin border, always with the author's alt text from the markdown.
- **Tables:** wrapped in `<div class="table" role="region" aria-label="Table: <short description>" tabindex="0">` so they scroll inside themselves.
- **Metadata:** a `<dl>` with mono uppercase labels: Logged (the date), Updated (if set), Length (`N words, M min`: words in the markdown body, minutes at 200 words a minute rounded up, never under 1), Tags (a `<ul class="tags">`), Source ("Read the markdown source").
- **Ruler:** under the metadata, `<nav class="ruler" aria-label="On this page">`: the post title, every h2 in order, then `EOF`. Each item is a tick mark; `notebook.js` fills the ticks already read and marks the current one (`aria-current="location"`). Omit the ruler when the post has no h2.
- **Footnotes:** rendered at the end as the markdown has them. From 86rem `notebook.js` copies each note beside its paragraph as an `aria-hidden` sidenote and visually hides the footnotes section; screen readers still get the original section, and the `1` links still work.

## Flare

Flare is optional, per post, and lives in `[data-flare]` elements and `flare.css` / `flare.js` in the post folder.

Flare **may**: add a diagram, figure, small interactive or animated illustration that helps the post's point; restyle one section of the post in a way that suits its content; use accent colours already in the palette.

Flare **may not**: change, add or hide the author's words (flare is excluded from the guard, so this is on trust); carry information that the text does not also give; replace the shell (header, footer, metadata, fonts); load anything from another domain; autoplay sound; animate for more than 5 seconds or ignore `prefers-reduced-motion`; break the page with JS disabled. Decorative flare gets `aria-hidden="true"`; meaningful flare gets a text alternative. Interactive flare must work with a keyboard and show focus.

## Accessibility checklist (every page)

- `lang="en"` on `<html>`; one `<h1>`; headings in order with no skipped levels.
- Landmarks: skip link to `#content`, `<header>`, `<nav aria-label="Site">`, `<main id="content">`, `<footer>` with `<nav aria-label="Footer">`; the post details are an `<aside aria-label="Post details">` containing `<nav aria-label="On this page">`.
- Text contrast AA (4.5:1, or 3:1 for large text) in light **and** dark; focus ring 3px solid accent, visible on every interactive element, including the Copy button on a dark panel.
- Links say where they go out of context ("Read the markdown source", not "here"). Icon-only or glyph-only controls carry an `aria-label`.
- Decorative glyphs hidden from assistive tech: CSS `content: "## " / ""` or `aria-hidden="true"`.
- Motion: none longer than 5 seconds; nothing under `prefers-reduced-motion`.
- Tap targets at least 24 by 24px. Text sized in rem; zoom to 200% without loss.
- Reflows at 320px with no page-level sideways scroll.
- Check each new page with axe-core in light and dark mode, and tab through it once (the `/publish` skill says how).
