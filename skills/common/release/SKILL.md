---
name: release
description: Create a GitHub release with auto-generated release notes. Analyzes commits since the last release, categorizes changes, drafts release notes, and helps publish the release after user confirmation.
---

# Release

## Overview

Automate the creation of GitHub releases with well-structured release notes. This skill:
- Detects the latest release tag
- Determines the next version (user-specified or auto-suggested)
- Analyzes commits since the last release
- Categorizes changes (features, fixes, improvements, etc.)
- Generates a release notes draft
- Publishes the release after user confirmation (tag push / workflow trigger / GitHub UI)

## Workflow

1. **Check prerequisites**
   - Ensure the working directory is a git repository.
   - Check that `origin` remote exists.

2. **Determine GitHub repository context**
   - Determine `owner` and `repo` from `git remote get-url origin` (supports HTTPS/SSH URLs like `https://github.com/<owner>/<repo>.git` or `git@github.com:<owner>/<repo>.git`).
   - If it cannot be determined reliably, ask the user for `<owner>/<repo>`.

3. **Get existing releases**
   - List existing tags:
     ```sh
     git tag -l --sort=-v:refname | head -10
     ```
   - Get latest release via GitHub MCP `get_latest_release`:
     - If it exists, use its `tag_name` as `last_tag`.
     - If the repository has no releases, treat this as the first release and use the first commit (or ask the user for a base tag/commit).

4. **Determine the next version**
   - If the user specifies a version (e.g., `v0.2.0`), use it.
   - Otherwise, suggest the next version based on semantic versioning:
     - Analyze commit messages for breaking changes, features, or fixes.
     - `BREAKING CHANGE` or `!:` → major bump
     - `feat:` → minor bump
     - `fix:`, `chore:`, `docs:`, etc. → patch bump
   - Ask the user to confirm or specify a different version.

5. **Fetch commits since last release**
   - Get commit log:
     ```sh
     git log <last_tag>..HEAD --oneline --no-merges
     ```
   - Get detailed commit information:
     ```sh
     git log <last_tag>..HEAD --pretty=format:"%h %s" --no-merges
     ```
   - Get file change statistics:
     ```sh
     git diff <last_tag>..HEAD --stat
     ```

6. **Categorize changes**
   - Apply the user-facing gate first:
     - Include **user-facing changes only**.
     - Prefer items that are **user-visible changes**, have **external impact / customer-facing changes**, represent **behavioral changes**, or are **public API/behavior changes**.
     - Exclude internal-only work (tests, CI, build, refactor, internal docs) unless it has clear external impact.
     - If unclear, mark it for user confirmation during the draft review.
   - Parse commit messages and group by type:
     - **New Features**: `feat:` prefix or new functionality
     - **Bug Fixes**: `fix:` prefix
     - **Improvements**: `refactor:`, `perf:` prefixes
     - **Documentation**: `docs:` prefix (user-facing documentation only)
     - **Other Changes**: user-facing changes that do not fit other categories (e.g., minor compatibility changes, small UX tweaks, accessibility improvements, localization updates)
   - For non-conventional commits, infer category from content.

7. **Generate release notes draft**
   - Use this template:
     ```markdown
     ## <Project Name> <version>

     ### New Features

     **<Feature title>**

     - <Bullet point description>
     - <Additional details if needed>

     ### Bug Fixes

     - <Fix description>

     ### Improvements

     - <Improvement description>

     ### Other Changes
     *(User-facing only: minor compatibility changes, small UX tweaks, accessibility improvements, localization updates)*

     - <Other change description>

     **Full Changelog**: https://github.com/<owner>/<repo>/compare/<last_tag>...<new_tag>
     ```
   - Omit empty sections.
   - For significant changes, expand with context from:
     - Reading modified files
     - Examining PR descriptions (if available via GitHub MCP)
     - Analyzing the diff

8. **Present draft to user**
   - Display the generated release notes.
   - Call out any unclear items and ask whether they should be included as user-facing changes.
   - Ask for confirmation or edits:
     - Confirm and publish
     - Edit the notes (user provides corrections)
     - Cancel

9. **Publish the release**
   - This skill avoids `gh` CLI and uses GitHub MCP where possible.
   - Note: triggering workflows requires the GitHub MCP `actions` toolset (it is not included in the default toolset).
   - Typical flow:
     - Create and push the git tag (this often triggers an existing release workflow):
       - `git tag <version>`
       - `git push origin <version>`
     - If the repo uses a manual workflow for releases, trigger it via GitHub MCP:
       - Use `actions_list` with `method: "list_workflows"` to discover workflows
       - Use `actions_run_trigger` with `method: "run_workflow"` to trigger the selected workflow (provide `ref` and `inputs` as required by the workflow)
     - Verify whether a GitHub Release object exists:
       - Use GitHub MCP `get_release_by_tag` with `tag: <version>`
       - If it exists, report the release URL
   - If the repository does not have automation and a GitHub Release object is required:
     - Create it manually in the GitHub web UI and paste the generated notes.

## Version Format

- Default format: `v<major>.<minor>.<patch>` (e.g., `v1.2.3`)
- Support alternative formats if the project uses them:
  - Without `v` prefix: `1.2.3`
  - With pre-release: `v1.2.3-beta.1`
- Match the existing tag format in the repository.

## Release Notes Guidelines

- **User-facing changes only**: Include user-visible changes, external impact/customer-facing changes, behavioral changes, and public API/behavior changes. Use **Other Changes** only for user-facing items that do not fit other sections (e.g., minor compatibility changes, small UX tweaks, accessibility improvements, localization updates).
- **Be concise**: 1-2 sentences per item.
- **Focus on user impact**: What changed for users, not implementation details.
- **Group related changes**: Multiple commits for one feature become one entry.
- **Use active voice**: "Add dark mode" not "Dark mode was added".
- **Include context**: Brief explanation of why the change matters.

## Edge Cases

- **No commits since last release**: Report that there are no changes to release.
- **First release**: Use all commits from the beginning, or ask for a base commit.
- **Merge commits**: Skip merge commits (use `--no-merges`).
- **Squash-merged PRs**: Treat as single feature commits.
- **Pre-release versions**: Support `-alpha`, `-beta`, `-rc` suffixes.

## Options

### Specify version
```
/release v1.0.0
```

### Draft only (don't create)
```
/release --draft
```

### Include pre-release tag
```
/release v1.0.0-beta.1 --prerelease
```

## Examples

### Basic usage (auto-detect version)
```
/release
```

### Specify version explicitly
```
/release v2.0.0
```

### Create a pre-release
```
/release v1.0.0-rc.1 --prerelease
```

## Error Handling

- If no commits since last release, report and exit.
- If publish fails (permissions, missing workflows, etc.), show the error and suggest manual creation in the GitHub web UI.
