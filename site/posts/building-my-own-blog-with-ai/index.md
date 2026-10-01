---
title: "I built my own blog with an AI agent"
slug: building-my-own-blog-with-ai
date: 2026-10-01
description: "A plan, a three hour time box and Claude Code: every step it took to get grant-ps.com live, and why I think more of us will start building our own software."
tags: [ai, blogging, cloudflare, ruby]
---

A plan, a three hour time box, and an AI agent doing the typing. Everything it took to get this site live.

My writing has lived on other people's platforms: Medium, under NEXL Engineering, and dev.to. They work fine. They are also not mine. The URL, the design, the way a post gets from my head to the page, all of it belongs to somebody else.

So I moved it to my own domain. But rather than pick a platform, I made it an experiment. Can an AI agent stand up a personal blog, with a publishing workflow I actually trust, in an afternoon?

This post is the answer. It is also the first post on the blog it describes.

## Plan first, then hand over the keys

Before the agent wrote a line of code, I wrote `PLAN.md`. Seventeen settled decisions, each with what it was chosen over. A three hour budget. Eight phases, one checkpoint where the agent had to stop and wait for me, and a list of things it was not allowed to do.

The core idea fits in four lines:

- Markdown is the source of truth for every post.
- The agent writes each page's HTML by hand from that markdown, following a design brief. No static site generator, no templates.
- Boring, deterministic Ruby does everything that must be exact: the RSS feed, the sitemap, and a fidelity guard.
- The deploy is dumb. Cloudflare serves the committed files. No build step, no API keys.

The second point is the unusual one. Letting an agent hand write every page means each post can get its own touch, and the whole site can be redesigned later by regenerating every page from the markdown. Nothing is locked into a theme.

It also means trusting an agent with my words. That is where the third point comes in.

## Instructions are advisory. A guard is not.

The plan tells the agent never to alter, add to, reorder or omit my prose. That is an instruction, and I have written before about how far instructions get you.

So there is a fidelity guard. It renders the markdown, pulls the post body out of the agent's HTML, and compares the two block by block: headings, paragraphs, list items, code lines. Whitespace may change. Nothing else may. A curly quote turned straight fails. A dropped code line fails. A reworded sentence fails, with a diff that tells the agent exactly what to fix.

It runs as a pre-commit hook, so a bad page cannot be committed, by me or by the agent. In the end to end test it blocked a commit where a single word had changed on the page.

The same idea later spread to the home page intro. A redesign rewrites the home page, so the intro got its own markdown file and the guard checks that too.

## Three designs, then a fourth

The checkpoint was the design. The agent built three directions, each as a home page and a sample post: an editorial serif, an engineering notebook, and something loud in cobalt, coral and lemon.

I asked for a fourth that combined the notebook with the loud one. Then I picked the notebook anyway, on two conditions: mobile first, and proper web accessibility. The agent rewrote the stylesheet mobile first and worked through the accessibility details one by one. A blinking cursor that stops after four blinks. Decorative shell prompts hidden from screen readers. A focus ring you can see on every surface.

## What the guard could not see

This was the most useful lesson of the build.

The guard proves the words are right. It says nothing about whether the page reads right. Screenshots at phone and desktop width found eight bugs that no text check would ever catch. A few of them:

- Paragraphs with no gap between them, because one CSS rule outranked another on specificity.
- My name overflowing the screen on a phone.
- A font missing the glyph for a non-breaking hyphen.
- Code ligatures merging `#{` into a single glyph, so the code on screen was not quite the code in the post.

So the agent built itself a second checker, `bin/check-pages`: accessibility checks with axe-core in light and dark mode, sideways scroll checks at three widths, and screenshots it has to look at before handing a page over. It was not in the plan. It is now the step I would least want to lose.

The agent's own note at the end of its build log: build the screenshot checker in phase 2, not phase 5. I agree. It is the same lesson as [my tooling post](https://dev.to/grantps/tooling-every-ai-software-harness-should-have-4512). A tool only counts if the agent sees the output.

## The numbers

The build took 2 hours 35 minutes of wall time, inside the three hour budget, including the time spent waiting for me to pick a design. It ended with 42 passing tests, a pre-commit hook proven against every failure case in the plan, two Claude Code skills, `/publish` and `/regenerate-site`, and a site ready to deploy that nobody could see yet.

## Getting it live

Then came the part the agent could not do alone. Clicking through dashboards is still my job. So I did it one step at a time, with the agent telling me what to do next and checking each step from its side before moving on.

1. Bought grant-ps.com through Cloudflare Registrar.
2. Created the Worker with Workers Builds, pointed at the GitHub repo. No build command, deploy command `npx wrangler deploy`. The first deploy to `workers.dev` went green in under a minute.
3. The build log showed Cloudflare installing my Ruby gems and npm packages before every deploy. The deploy needs neither, so we turned that off with a `SKIP_DEPENDENCY_INSTALL` build variable. I put it in the runtime variables first. The agent spotted the wrong section from my screenshot.
4. Attached the custom domain and a www to apex redirect. The agent tested every combination of http, https and www, and found `http://www.grant-ps.com` returning a 522, because the redirect rule only matched https. One switch, Always Use HTTPS, fixed it.
5. Turned on Cloudflare Web Analytics. The agent recommended a manual token. I asked to try automatic injection first, because it was easier. It worked within a minute, with no change to the repo.
6. Added links to my writing elsewhere, and wrote the intro.

From the first deploy to the intro being live took a little over an hour.

## Off the shelf is losing its edge

Here is the thought that kept coming back while I did this.

I could have used Medium, Ghost, WordPress, or a static site generator with a theme. Any of them would have worked. Every one of them would have meant accepting someone else's idea of what a blog is.

What I got instead fits exactly how I want to work. My words in markdown, checked by a guard I can read. Pages that can be redesigned without touching a single post. A deploy with no moving parts. None of that is on a product roadmap anywhere, because nobody else needs exactly this combination. I did.

Building it used to be the expensive part. You weighed weeks of evenings against a monthly subscription, and the subscription won. That trade has changed. The cost of something bespoke is now an afternoon of agent time and a plan worth following.

I think more and more people are going to make that trade. Not for everything. Off the shelf will still win where the problem is genuinely shared and getting it wrong is expensive. But for the tools that sit closest to how you work, building your own is starting to beat adapting to someone else's. The default is going to flip.

## What this costs

Worth being straight about the trade offs.

You own all of it. There is no vendor to fix a bug, patch a security hole or keep the lights on. Here that is small on purpose: static files, no server code, no database. A bigger system carries a bigger bill.

The plan did a lot of the work. The agent was fast because the decisions were already made. Skipping that step would not have saved time. It would have moved the thinking into the middle of the build, where it costs far more.

And somebody still has to look. The agent caught most of its own mistakes, but only because it was told to screenshot and read its own pages. The checks are the reason this is trustworthy, not the agent.

## Where this leaves things

The site is live at grant-ps.com, the source is public at [github.com/grantspeelman/grant-ps.com](https://github.com/grantspeelman/grant-ps.com), and every post links to the markdown it was generated from. Next is syndication: dev.to will import posts from the RSS feed, with this site as the canonical home. After that, an editor app, which will be post number two.

If you have been putting off building your own version of something because the off the shelf one was close enough, it might be worth another look. Happy coding.
