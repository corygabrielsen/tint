@README.md @CONTRIBUTING.md

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

## Opening a PR

```bash
git push -u origin <branch-name>
gh pr create --title "<subject>" --assignee "@me" --label "<label>"
```

## Tags

The release pipeline cuts tags from `TINT_VERSION` on push to master.
**Never create or delete tags manually** — they're shared infra.
