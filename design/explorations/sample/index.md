---
title: "Context and goal"
slug: context-and-goal
date: 2026-09-27
description: "The opening section of the plan this site was built from. Sample content for the design explorations, not a real post."
tags: [ai, blogging, ruby]
---
Grant (GitHub `grantspeelman`) is moving his writing off third-party platforms onto his own domain, **grant-ps.com**. This build is a **time-boxed experiment**: can a personal blog with an AI-driven publishing workflow be stood up in a few hours? The story of the build becomes the blog's first post, so you are building the platform *and* producing the raw material for that post (see the build log, section 9).

Target: roughly **3 hours of agent work** for everything in this plan. If you are clearly going to overrun, say so in the build log and to Grant, and propose what to cut, rather than silently expanding.

The core idea:

- **Markdown is the source of truth for content.** Each post is a markdown file with frontmatter.
- **Claude writes each post's HTML directly** from the markdown, using a design brief and a shared page shell. This is deliberate: it allows creative flare per post, and the whole site can be reinvented later by regenerating from the markdown.
- **Boring, deterministic code does everything that must be exact**: the RSS feed, the sitemap, and a fidelity guard that proves the generated page contains the author's exact words.
- **The deploy is dumb.** Everything that goes live is generated and reviewed locally, committed, and pushed. Cloudflare only serves committed files. No build step, no scripts, no API keys in the deploy.

## Cloudflare Workers configuration

Assets-only Worker, no script.

```jsonc
{
  "name": "grant-ps-com",
  "compatibility_date": "<today's date at build time>",
  "assets": {
    "directory": "./site",
    "html_handling": "auto-trailing-slash",
    "not_found_handling": "404-page"
  }
}
```
