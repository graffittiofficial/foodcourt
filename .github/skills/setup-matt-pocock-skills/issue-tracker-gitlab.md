# Issue tracker: GitLab

Issues and specs for this repo live as GitLab issues. Use the [`glab`](https://gitlab.com/gitlab-org/cli) CLI for all operations.

## Conventions

- **Create an issue**: `glab issue create --title "..." --description "..."`. Use a heredoc for multi-line descriptions.
- **Read an issue**: `glab issue view <number> --comments`. Use `-F json` for machine-readable output.
- **List issues**: `glab issue list -O json` with appropriate `--label` filters.
- **Comment on an issue**: `glab issue note <number> --message "..."`.
- **Apply / remove labels**: `glab issue update <number> --label "..."` / `--unlabel "..."`
- **Close**: post an explanation with `glab issue note`, then run `glab issue close <number>`.
- **Merge requests**: use `glab mr` commands, equivalent to `gh pr` commands.

Infer the repo from `git remote -v`; `glab` does this automatically when run inside a clone.

## Merge requests as a triage surface

**MRs as a request surface: no.** _(Set to `yes` if this repo treats external merge requests as feature requests; `/triage` reads this flag.)_

## Skill operations

When a skill says "publish to the issue tracker", create a GitLab issue. When it says "fetch the relevant ticket", run `glab issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`.
- **Child ticket**: an issue carrying `Part of #<map>` at the top of its description and a `wayfinder:<type>` label (`research`/`prototype`/`grilling`/`task`).
- **Blocking**: prefer GitLab's native blocking link. Where unavailable, use a `Blocked by: #<n>, #<n>` line at the top of the description.
- **Claim**: assign the ticket to the driving developer.
- **Resolve**: comment with the answer, close the ticket, then append a context pointer to the map's Decisions-so-far.
