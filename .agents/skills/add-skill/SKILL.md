---
name: add-skill
description: "Use when creating, renaming, changing, or deleting a skill in this repository. Keeps .agents/skills/ as the source of truth and mirrors it as real copies in .claude/skills/."
---

# Adding or Changing a Skill

Different tools discover skills in different directories, and symlinks are not
assumed to work on every contributor's machine. The repository therefore keeps
one source of truth and a plain copy.

| Directory | Role | Read by |
| --- | --- | --- |
| `.agents/skills/<name>/` | Source of truth. Edit only here. | Codex, GitHub Copilot |
| `.claude/skills/<name>/` | Copy of the source. Never edit directly. | Claude Code (also read by GitHub Copilot) |

## Steps

1. Create or edit `.agents/skills/<name>/SKILL.md`. The directory name must equal
   `name` in the frontmatter, and `description` must say when to use the skill.
   Finish all edits here first; never edit `.claude/skills/` directly.
2. When the edits are done, mirror the whole skills directory into `.claude/skills/`:

   ```bash
   rm -rf .claude/skills && mkdir -p .claude && cp -R .agents/skills .claude/skills
   ```

3. Verify that nothing differs:

   ```bash
   diff -r .agents/skills .claude/skills && echo "skills in sync"
   ```

4. Commit `.agents/skills/` and `.claude/skills/` together.

## Rules

- Never create symlinks between the two directories.
- Do not add per-tool instruction files for content that a skill can carry. Tool entry points (`AGENTS.md`, `.claude/CLAUDE.md`, `.github/copilot-instructions.md`) only tell the agent to load the `project-rules` skill.
- Reference other skills by name, not by path, so the text is valid in both directories.
