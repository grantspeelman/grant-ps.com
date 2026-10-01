# Page shell

Every page on grant-ps.com uses this shell. Copy it exactly and fill the `{{placeholders}}`; everything else (the post body, flare) goes where marked. Values come from `site.yml` and the post's frontmatter. The look is defined in `design/BRIEF.md` and `site/assets/style.css`.

Rules that apply to every page:

- All site-internal URLs are root-relative (`/assets/style.css`, `/posts/<slug>/`). Absolute URLs (`https://grant-ps.com/...`) are required in `canonical`, `og:url`, `og:image` and `twitter:image`.
- HTML-escape every placeholder value (`&`, `<`, `>`, and `"` inside attributes).
- `{{site_title}}` is `site.yml` `title`. `{{base_url}}` is `site.yml` `base_url` with no trailing slash.
- `{{og_image}}` is the absolute URL of the frontmatter `og_image` (`{{base_url}}/posts/{{slug}}/{{og_image}}`) or, if it is not set, `{{base_url}}` + `site.yml` `default_og_image`.
- The analytics line appears only if `site.yml` `analytics_token` is non-empty. Otherwise leave it out entirely.
- No em-dashes in any copy you write (chrome, alt text you add, captions). Use commas, colons or full stops.

## `<head>` (all pages)

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{page_title}}</title>
<meta name="description" content="{{description}}">
<link rel="canonical" href="{{canonical_url}}">
<link rel="alternate" type="application/rss+xml" title="{{site_title}}" href="/feed.xml">
<meta property="og:type" content="{{og_type}}">
<meta property="og:site_name" content="{{site_title}}">
<meta property="og:title" content="{{og_title}}">
<meta property="og:description" content="{{description}}">
<meta property="og:url" content="{{canonical_url}}">
<meta property="og:image" content="{{og_image}}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{{og_title}}">
<meta name="twitter:description" content="{{description}}">
<meta name="twitter:image" content="{{og_image}}">
<link rel="preload" href="/assets/fonts/ibm-plex-sans-normal.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/assets/style.css">
<script defer src="https://static.cloudflareinsights.com/beacon.min.js" data-cf-beacon='{"token": "{{analytics_token}}"}'></script>
</head>
```

| Placeholder | Post | Home | 404 |
|---|---|---|---|
| `{{page_title}}` | `{{title}} · {{site_title}}` | `{{site_title}}` | `Not found · {{site_title}}` |
| `{{description}}` | frontmatter `description` | `Writing by {{site_title}}.` | `This page does not exist.` |
| `{{canonical_url}}` | `{{base_url}}/posts/{{slug}}/` | `{{base_url}}/` | `{{base_url}}/404` (Cloudflare strips `.html`), and add `<meta name="robots" content="noindex">` |
| `{{og_type}}` | `article` | `website` | `website` |
| `{{og_title}}` | frontmatter `title` | `{{site_title}}` | `Not found` |

Posts also add, after `og:image`:

```html
<meta property="article:published_time" content="{{date}}">
<meta property="article:modified_time" content="{{updated}}">   <!-- only if updated is set -->
```

Posts with flare add their own files after the shared stylesheet: `<link rel="stylesheet" href="flare.css">` and `<script src="flare.js" defer></script>`.

## Body chrome (all pages)

```html
<body>
<a class="skip" href="#content">Skip to content</a>
<header class="topbar">
  <div class="page">
    <a class="wordmark" href="/"{{aria_current}}><span class="prompt" aria-hidden="true">~/</span>grant-ps.com<span class="cursor" aria-hidden="true"></span></a>
    <nav aria-label="Site"><a href="{{repo_url}}">source</a></nav>
  </div>
</header>

<!-- page main goes here -->

<footer class="site-foot">
  <div class="page"><a href="/feed.xml">RSS feed</a><a href="{{repo_url}}">Source on GitHub</a></div>
</footer>
</body>
</html>
```

`{{aria_current}}` is ` aria-current="page"` on the home page and empty elsewhere. `{{repo_url}}` is `site.yml` `repo_url`.

## Post main

```html
<main id="content" class="page">
  <article class="entry">
    <header class="entry-head">
      <p class="label">posts/{{slug}}</p>
      <h1>{{title}}</h1>
      <p class="abstract">{{description}}</p>
    </header>
    <aside class="margin" aria-label="Post details">
      <dl>
        <dt>Logged</dt><dd><time datetime="{{date}}">{{date}}</time></dd>
        <dt>Updated</dt><dd><time datetime="{{updated}}">{{updated}}</time></dd>   <!-- only if updated is set -->
        <dt>Tags</dt><dd><ul class="tags"><li>#{{tag}}</li>...</ul></dd>           <!-- only if there are tags -->
        <dt>Source</dt><dd><a href="{{source_url}}">Read the markdown source</a></dd>
      </dl>
    </aside>
    <div class="prose" data-post-body>
{{post body}}
    </div>
    <footer class="entry-foot"><span aria-hidden="true">EOF</span><a href="/">All writing</a></footer>
  </article>
</main>
```

- `{{source_url}}` is `site.yml` `source_url_template` with `%{slug}` replaced.
- `<h1>` text must equal the frontmatter `title` exactly (the guard checks it). It is the only `<h1>` on the page.
- **The post body** is the markdown rendered to HTML, every block in order, with the author's words untouched. Start from `bin/render <slug>`: it is the same renderer the guard and feed use, and it already turns `<pre lang="x">` into `<pre data-lang="x" tabindex="0">` (never keep `lang` on code: it names a human language). Then apply only these changes:
  - Footnotes: add `aria-label="Footnotes"` to `<section class="footnotes" data-footnotes>` so screen readers can name it (the visible "footnotes" label is CSS).
  - Each `<table>` is wrapped: `<div class="table" role="region" aria-label="Table: {{what it shows}}" tabindex="0">...</div>`.
  - Headings in the markdown start at `##`. If the author used `#`, render it as `<h2>` so there is still only one `<h1>`.
  - Images keep the author's alt text. If the alt text is empty and the image carries meaning, flag it to Grant; do not invent one.
  - Classes, wrappers and `data-*` attributes are fine. Words, their order, link targets and image sources are not yours to change.
- Flare goes inside the body only as elements marked `data-flare` (the guard skips them), or in `flare.*` files.

## Home main

```html
<main id="content" class="page home">
  <h1>{{site_title}}</h1>
  <p class="todo">TODO(grant): a line or two about who you are and what you write about.</p>

  <section aria-labelledby="writing">
    <p class="cmd" aria-hidden="true"><span class="dollar">$</span> ls -t posts/</p>
    <h2 id="writing">Writing</h2>
    <ol class="ls" reversed>
      <li>
        <time datetime="{{date}}">{{date}}</time>
        <div>
          <h3><a href="/posts/{{slug}}/">{{title}}</a></h3>
          <p>{{description}}</p>
          <ul class="tags" aria-label="Tags"><li>#{{tag}}</li>...</ul>   <!-- only if there are tags -->
        </div>
      </li>
      ...one <li> per post, newest first (same order as bin/meta: date descending, then slug)
    </ol>
  </section>

  <section aria-labelledby="elsewhere">
    <p class="cmd" aria-hidden="true"><span class="dollar">$</span> cat writing-elsewhere.txt</p>
    <h2 id="elsewhere">Writing elsewhere</h2>
    <ul class="ls">
      <li><span class="venue">{{venue}}</span><a href="{{url}}">{{title}}</a></li>
      ...one per site.yml writing_elsewhere entry, in file order
    </ul>
  </section>
</main>
```

- In `{{site_title}}` inside the `<h1>`, wrap the hyphenated surname in `<span class="nowrap">` so it does not break at the hyphen.
- With no posts, the list is replaced by `<p class="ls-empty">No posts yet.</p>`.
- The `TODO(grant)` intro stays until Grant writes one; then his words replace it verbatim.

## 404 main

```html
<main id="content" class="page lost">
  <p class="cmd" aria-hidden="true">cat: no such file or directory</p>
  <h1>Not found</h1>
  <p>There is nothing at this address. It may have moved, or the link may be wrong.</p>
  <p><a href="/">Go to the home page</a> or <a href="/feed.xml">follow the RSS feed</a>.</p>
</main>
```

The page is static and served for every missing URL, so it cannot name the requested path.
