---
name: manage-issue
description: "Use when creating or editing a GitHub issue (or issue comment) in this repository. Defines the issue format and the rules that keep the contributor's local environment details out of public issue text."
---

# Creating and Editing Issues

Issues in this repository are public. Anything written to an issue may be cached or
indexed even if it is edited or deleted later. Treat every issue title, body, and
comment as published text.

## Language and Format

- Write issues in English, unless the user explicitly requests otherwise.
- Use the matching template under `.github/ISSUE_TEMPLATE/` (`bug_report.md` for
  defects, `feature_request.md` for proposals) and keep its section headings.
- Add the matching label: `bug` or `enhancement`.
- Describe behavior, expected result, and acceptance criteria. Do not describe the
  contributor's machine, session, or tooling.

## Never Include Local Environment Information

Do not put any of the following in an issue title, body, or comment:

- Absolute local paths, especially ones containing a user name or home directory
  (`/home/<name>/...`, `/Users/<name>/...`, `C:\Users\<name>\...`), and temporary or
  session directories (`/tmp/...`, scratchpad paths, `mktemp` results).
- User names, host names, machine names, email addresses, or the git author identity.
- Secrets: tokens, keys, passwords, credentials, `Authorization` headers, and the
  values of environment variables.
- The full `PATH`, the full environment, shell prompts, shell history, or dotfile contents.
- IP addresses, private or internal URLs, and company or organization-internal names.
- Raw command output or logs that have not been reviewed line by line.

Instead:

- Use repository-relative paths (`lib/commands/command-update`) or placeholders
  (`~`, `$HOME`, `<repo>`, `<plugin-dir>`, `<user>`).
- Include only the minimum environment facts needed to reproduce a bug: asdf version,
  asdf-extras version, shell and version, and OS family (for example `Linux` or `macOS`).
- Quote only the relevant lines of output, with paths and identifiers replaced by placeholders.
- Do not attach files or screenshots from the local machine.
- Do not copy text from local files, memory, or other tools into an issue without
  reading it for the items above.

## Procedure

1. Confirm the target repository is this one: `gh repo view --json nameWithOwner -q .nameWithOwner`.
2. Write the body to a file in a temporary location outside the repository. Pass it
   with `--body-file`; do not inline long text in the command line.
3. Scan the file before publishing and fix every hit:

   ```bash
   body=path/to/body.md
   grep -nEi '/home/|/Users/|/root/|C:\\Users|/tmp/|scratchpad|[[:alnum:]._%+-]+@[[:alnum:].-]+\.[a-z]{2,}|ghp_|github_pat_|gho_|sk-[[:alnum:]]|AKIA|bearer |password|secret|token|([0-9]{1,3}\.){3}[0-9]{1,3}' "$body"
   for v in "$HOME" "$USER" "$(hostname)" "$(git config user.name)" "$(git config user.email)"; do
   	[[ -n "$v" ]] && grep -nF -- "$v" "$body"
   done
   ```

   No output means no hit. A hit that is legitimate repository text (for example the
   word `token` in a feature description) is fine; a hit that is local data is not.
4. Read the body once more yourself. The scan does not catch everything.
5. Create or edit the issue:

   ```bash
   gh issue create --title "<title>" --label <bug|enhancement> --body-file "$body"
   gh issue edit <number> --body-file "$body"
   ```

6. When editing, read the current body first (`gh issue view <number> --json body -q .body`),
   keep the existing text, and change only what was requested. Apply the same scan
   to the full resulting body.
7. Report the issue URL to the user. If a leak was found and published, tell the user
   immediately so the text can be removed and any exposed secret rotated.

## Related Skills

- `project-rules` for language and branch rules.
- `commit-and-pr` for commit messages and pull requests. Pull request text follows
  the same rule about local environment information.
