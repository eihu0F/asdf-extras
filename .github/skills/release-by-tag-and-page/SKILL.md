---
name: release-by-tag-and-page
description: Create a release by pushing a git tag and creating a GitHub Release page. Use when the user asks for manual release publication.
---

# Manual Release By Tag + GitHub Release

Use this skill when the user wants a release flow that explicitly does both:

1. Create and push a git tag.
2. Create a GitHub Release page for that tag.

## Required Inputs

Collect these values before running commands:

- `tag`: Release tag (example: `v1.2.3`).
- `target`: Commit/branch to tag (default: `main`).
- `title`: Release title (default: same as tag).
- `notesMode`: `generate` or `manual`.
- `prerelease`: `true` or `false`.
- `draft`: `true` or `false`.

If the user did not provide them, ask concise questions first.

## Safety Rules

- Never overwrite or move an existing remote tag.
- Never use force-push for release tags.
- Stop if the working tree is dirty unless the user explicitly approves proceeding.
- Show a short execution plan and ask for confirmation before pushing the tag.

## Execution Steps

Run non-interactive commands in this order.

1. Validate repository state.

```bash
git fetch --tags origin
git status --short
git rev-parse --verify "refs/tags/$TAG" >/dev/null && echo "local tag exists"
git ls-remote --tags origin "refs/tags/$TAG"
```

2. Validate target exists.

```bash
git rev-parse --verify "$TARGET" >/dev/null
```

3. Create an annotated tag.

```bash
git tag -a "$TAG" "$TARGET" -m "Release $TAG"
```

4. Push the tag.

```bash
git push origin "$TAG"
```

5. Create GitHub Release page.

Generate notes mode:

```bash
gh release create "$TAG" \
  --target "$TARGET" \
  --title "$TITLE" \
  --generate-notes
```

Manual notes mode:

```bash
gh release create "$TAG" \
  --target "$TARGET" \
  --title "$TITLE" \
  --notes-file "$NOTES_FILE"
```

Optional flags:

- Add `--prerelease` when `prerelease=true`.
- Add `--draft` when `draft=true`.

## Fallback When `gh` Is Unavailable

If GitHub CLI is unavailable or unauthenticated:

1. Push the tag only after confirmation.
2. Provide the direct browser URL pattern for release creation:

```text
https://github.com/<owner>/<repo>/releases/new?tag=<TAG>
```

3. Tell the user exactly which values to paste (`title`, notes, prerelease, draft).

## Verification Output

After completion, report:

- Created tag and target commit SHA.
- Tag push result.
- Release URL.
- Whether release is draft/prerelease.

## Failure Handling

If tag push succeeds but release creation fails:

1. Report the failure reason and the `gh` error output summary.
2. Offer one-click manual completion via the release URL.
3. Do not delete the pushed tag unless the user explicitly requests rollback.
