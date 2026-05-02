# AGENTS.md

Conventions for agents (and humans) contributing to this repo.

## Versioning

Strict [semver](https://semver.org). The "public API" of `tint` is the
CLI, the sourced public functions (`tint_pick`, `tint_lookup`,
`tint_resolve`, `tint_list`, `tint_set`, `tint_reset`,
`tint_supports_color`, `tint_reload_palette`), exit codes, output
format, and `--help` text. Internal helpers prefixed with `_tint_` are
private.

Bump `TINT_VERSION` per the matrix below.

| Change                                      | Bump  |
| ------------------------------------------- | ----- |
| Breaking change to CLI / public function    | MAJOR |
| New theme, new flag, new behavior, rename   | MINOR |
| Bug fix in `tint`                           | PATCH |
| `--help` / message text user-visibly edited | PATCH |
| Pure refactor of private internals          | none  |
| Comment-only / doc-only `tint` change       | none  |
| Test-only / CI-only change                  | none  |

A bump is what cuts a release. Unbumped PRs roll into the next
versioned PR. Don't bump just to "ship a refactor" — wait for the
next real change.

## Pull requests

- One focused change per PR. Defer noticed-but-unflagged cleanups to
  follow-up PRs rather than folding them in.
- When addressing a review comment, fix the flagged instance **and**
  audit the entire class of issue across the touched files. Name the
  class in the reply.
- PR title ≤ 42 chars (GitHub appends ` (#N)` on squash-merge; total
  must fit in 50). Not enforced in this repo's `pre-commit-config`;
  enforce at PR-creation time (e.g. read the title before running
  `gh pr create`).
- Set a label, assign yourself (`gh pr create --assignee @me`), mark
  ready for review.

## Commits

- Subject ≤ 50 chars, body wrapped at 72 (pre-commit hook enforces).
- Imperative mood ("Add X", not "Added X").
- Don't skip hooks (`--no-verify`).

## Tags

The release pipeline cuts tags from `TINT_VERSION` on push to master.
**Never create or delete tags manually** — they're shared infra.
