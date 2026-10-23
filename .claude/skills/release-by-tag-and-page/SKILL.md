---
name: release-by-tag-and-page
description: Release skill for this repository. Prefer release-please workflow execution; use manual tag and GitHub Release page flow as fallback.
---

# Release Skill For This Repository

This repository has a release workflow at `.github/workflows/release.yml`:

- Trigger: push to `main` or `workflow_dispatch`
- Action: `googleapis/release-please-action@v5`
- Mode: `release-type: simple`

Use this skill in two modes:

1. **Workflow mode (default)**: run `release-please` and let it create/update the release PR.
2. **Manual mode (fallback)**: create/push a tag and create a GitHub Release page.

## Mode Selection Rules

- If user says only "release" and does not explicitly require manual tagging, use **workflow mode**.
- Use **manual mode** only when user explicitly asks for tag-based/manual publishing.

## Workflow Mode (Preferred)

### Preflight Checks

Run:

```bash
gh auth status
gh workflow view release.yml
```

Then verify repository settings in GitHub UI when needed:

- Settings > Actions > General
- Workflow permissions: `Read and write permissions`
- `Allow GitHub Actions to create and approve pull requests`: enabled

If the run fails with:

`GitHub Actions is not permitted to create or approve pull requests`

report that this repository/org setting must be enabled before retry.

### Execute

Dispatch the workflow:

```bash
gh workflow run release.yml --ref main
```

Monitor status:

```bash
gh run list --workflow release.yml --limit 5
```

If release-please opens/updates a PR, report its URL and title.

## Manual Mode (Fallback)

Use this flow only when requested or when workflow mode cannot be used.

### Required Inputs

- `tag`: release tag (example: `0.2.1` or `v0.2.1`)
- `target`: commit/branch to tag (default: `main`)
- `title`: release title (default: same as tag)
- `notesMode`: `generate` or `manual`
- `prerelease`: `true` or `false`
- `draft`: `true` or `false`

### Safety Rules

- Never overwrite or move existing tags.
- Never force-push release tags.
- Stop on dirty working tree unless user explicitly approves.

### Steps

```bash
git fetch --tags origin
git status --short --branch
git rev-parse --verify "refs/tags/$TAG" >/dev/null && echo "local tag exists"
git ls-remote --tags origin "refs/tags/$TAG"
git rev-parse --verify "$TARGET" >/dev/null
git tag -a "$TAG" "$TARGET" -m "Release $TAG"
git push origin "$TAG"
```

Create release page:

```bash
gh release create "$TAG" --target "$TARGET" --title "$TITLE" --generate-notes
```

Or manual notes:

```bash
gh release create "$TAG" --target "$TARGET" --title "$TITLE" --notes-file "$NOTES_FILE"
```

Optional flags:

- `--prerelease` when `prerelease=true`
- `--draft` when `draft=true`

## Output Requirements

Always report:

- Chosen mode (`workflow` or `manual`)
- Executed command summary
- PR URL (workflow mode) or release URL (manual mode)
- Any blocking setting issues and exact fix path in GitHub UI
