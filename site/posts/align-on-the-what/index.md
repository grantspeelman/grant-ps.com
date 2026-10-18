---
title: "Align on the what. Let the tooling handle the how."
slug: align-on-the-what
date: 2026-10-18
description: "Why my agent interviews me about the outcome before it changes anything, and leaves the implementation to linters and injected conventions."
tags: [ai, agents, skills, claudecode]
---

I asked Codex to add a rule to a project's AGENTS.md, and to get aligned with me before touching the file. The rule: any development is done by sub-agents, and another sub-agent reviews the changes.

It read AGENTS.md and the docs, wrote a short ledger, and came back with one question:

```
The goal is to make delegation and independent review mandatory in AGENTS.md. I propose:

  • All repository changes, including docs and configuration, are implemented by sub-agents.
  • The primary agent coordinates the work.
  • A separate sub-agent reviews the changes, and findings are addressed before completion.
  • This update follows that process too. Only AGENTS.md changes; no commit or push.

I'll choose the wording and placement.

Q1: Does that match your intent?

  1. Yes, apply to all repository changes.
  2. Apply only to application code.
```

I had typed "any development". I hadn't thought about whether a one-line README fix counts as development. That question made me stop and work out what I actually meant.

I went with all repository changes, because I was curious how well that would work. Either way, the question got me thinking properly about the outcome I wanted.

That question is the whole idea behind two skills I've been using. `get-aligned` interviews me about the goal and outcome. `auto-alignment-before-action` checks for gaps before the agent changes anything.

## Agree on the what, leave the how

When I work with an agent, I want us to agree on the outcome: the goal, what will be different when it's done, what's in and out of scope, and how I'll know it worked. How it gets built is the agent's call.

That only works because I'm not relying on the agent's taste for the how. Linters catch style. A mutation gate catches tests that don't really test anything. [agent-apropos](https://github.com/NEXL-LTS/agent-apropos) injects the project's conventions at the moment the agent touches a file they apply to. If the implementation comes out wrong in a way none of those catch, that's a gap in the harness, and I fix the harness.

Without that layer I'd have to review the how myself, and then I'd want to agree on it up front too. With it, my attention goes where tooling can't help: what I actually mean.

## Only ask what changes the outcome

`get-aligned` interviews me one multiple-choice question at a time, with its recommendation first so I can accept in a click. Before it asks anything, it checks two things. Could it find the answer itself? Would a different answer change what I end up with? If either fails, it decides on its own.

Look at the Codex exchange again. It read the files before asking. It said "I'll choose the wording and placement" instead of asking me where the rule should go. One question survived, and it was about scope.

When an implementation question does matter, it asks about the consequence, not the mechanism: "should a reviewer see every retry?" rather than "should retries get their own table?"

## A gate before anything changes

`auto-alignment-before-action` runs before the agent changes state: editing files, running commands with side effects, committing, publishing. It silently checks the goal, outcome, scope, constraints and what "done" means. Every answer has to trace back to something I said or a settled source like AGENTS.md. An answer it inferred doesn't count.

If there's a gap, it asks one question, or runs a full `get-aligned` session for anything bigger or hard to undo. If there's no gap, it opens with one line naming what it's about to produce. That line is my last cheap chance to stop it.

It also lists its out clauses up front, so we agree which problems it hands back and which it solves. This is a made-up example:

```
Out clauses:
- npm registry unreachable → stop and tell you
- lint fails on files I didn't touch → leave them, mention at the end
- feed validator rejects the dates → I'll fix the formatting myself
```

After that it keeps going. It only stops mid-task for a blocker an out clause says to hand back, or before changing the outcome we agreed.

## Try them

I've been tuning these in my personal repo [grantspeelman/skills](https://github.com/grantspeelman/skills), alongside a dev container skill and `unslop`. If the idea fits how you want to work, install mine to try it, or build your own tweaked version.

If you catch yourself reviewing implementation details your linters could have caught, that's a harness problem. If you catch yourself reviewing a correct implementation of the wrong thing, that's an alignment problem. These two skills are my fix for the second one.
