# Issue tracker: Local Markdown

Issues and specs for this repo live as markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`.
- Triage state is recorded as a `Status:` line near the top of each issue file.
- Comments and conversation history append to the bottom of the file under a `## Comments` heading.

When a skill says "publish to the issue tracker", create a file under `.scratch/<feature-slug>/`. When it says "fetch the relevant ticket", read the file at the referenced path.

## Wayfinding operations

Used by `/wayfinder`. The map is `.scratch/<effort>/map.md`; each child ticket is `.scratch/<effort>/issues/NN-<slug>.md`.

- A ticket's `Type:` line records `research`, `prototype`, `grilling`, or `task`; its `Status:` line records `claimed` or `resolved`.
- A `Blocked by: NN, NN` line near the top lists prerequisites.
- The frontier is the first numbered open, unblocked, unclaimed ticket.
- Claim by setting `Status: claimed` before work.
- Resolve by appending the answer under `## Answer`, setting `Status: resolved`, and adding a context pointer to the map's Decisions-so-far.
