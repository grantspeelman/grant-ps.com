# CLAUDE.md

Personal blog for grant-ps.com. Read `README.md` for the workflow.

- Publishing: use the `/publish <slug>` skill. Redesigns: `/regenerate-site`. Follow them exactly.
- Never alter, add to, reorder or omit the author's prose. The markdown is the text; fix the HTML, never the markdown.
- Never change a published slug. Every page uses `design/shell.md`.
- No em-dashes in any copy you write. Do not invent facts about Grant; use `TODO(grant)` placeholders.
- Never commit `drafts/`, fixture or test posts under `site/posts/`, or secrets.
- `bin/guard` and `bin/meta --check` must pass before a commit (the pre-commit hook enforces this). `bin/check-pages` must pass before you hand a page to Grant.
- Design: mobile first and WCAG 2.2 AA, per `design/BRIEF.md`.
- The original build brief is `PLAN.md`; the build story is in `BUILD_LOG.md`.
