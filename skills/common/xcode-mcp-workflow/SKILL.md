---
name: xcode-mcp-workflow
description: Workflow guide for Apple platform development using Xcode MCP, with practical tool examples.
---

# Xcode MCP Workflow

## Overview

Provide an MCP-first workflow for Apple platform development.
Prioritize flows that help Claude Code and Codex use Xcode MCP efficiently, with concrete tool examples.

## MCP Setup (Xcode)

- Use `/mcp` to list available tools and confirm names.
- Run `XcodeListWindows` and capture `tabIdentifier` for subsequent calls.
- Prefer Xcode MCP when it is more efficient; fall back to CLI when MCP is missing a capability, too slow, or a task is better served by specialized tooling.

## Core Workflow (MCP-first)

1. **Edit loop**
   - Find: `XcodeGlob`, `XcodeGrep`, `XcodeLS`
   - Read: `XcodeRead`
   - Update/Create: `XcodeUpdate`, `XcodeWrite`
   - Move/Delete: `XcodeMV`, `XcodeRM`
2. **Self-check before review (iterative)**
   - `XcodeListNavigatorIssues` for project-wide issues
   - `XcodeRefreshCodeIssuesInFile` for a specific file
   - If tests exist, run `RunSomeTests` or `RunAllTests`
   - If issues or tests fail, fix and repeat until clean
3. **Docs lookup when unsure**
   - `DocumentationSearch` for Apple API and tooling references
4. **Tests**
   - `GetTestList` to discover targets/tests
   - `RunSomeTests` for small/local changes
   - `RunAllTests` for broad/risky changes
5. **Build only when needed**
   - `BuildProject` for large refactors, suspicious failures, or pre-delivery confidence
   - Use `GetBuildLog` on failures

## Practical Examples (Non-Exhaustive)

- **After finishing changes, before review**
  - Run `XcodeListNavigatorIssues`
  - Fix errors and rerun until clean
  - Run `GetTestList`
  - If tests exist:
    - Use `RunSomeTests` for small/local changes
    - Use `RunAllTests` for broad/risky changes
  - If tests fail:
    - Inspect `GetBuildLog`
    - Fix and repeat issues + tests until clean
- **Document lookup for API usage**
  - Run `DocumentationSearch` with a focused query (e.g., "URLSession data task", "SwiftUI List selection")
- **Targeted test run**
  - `GetTestList` → pick target/test → `RunSomeTests`
- **Full test run**
  - `RunAllTests` when change scope is large or risky
- **Preview check**
  - `RenderPreview` for SwiftUI previews (use `previewDefinitionIndexInFile` as needed)
- **File discovery**
  - `XcodeGlob` for locating files, `XcodeGrep` for pinpointing symbols
- **Quick experiment in context**
  - `ExecuteSnippet` to validate small logic in a file context

## Docs Delegation

- Use `ios-dev-docs` when deeper Apple documentation context is needed.
