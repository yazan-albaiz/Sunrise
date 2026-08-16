# D:\Games\Sunrise\AGENTS.md

## About

Project Sunrise is a community mod that restores playability in old builds of Destiny 2. There are no limits to the development done as there is no fear of any legal action since this is not infringing on the IP nor is is using any of the live game's services, servers, or net code.

## Development

The focus is local development and testing so you will not push to remote or open PRs unless I explicitly ask.

- Always start a new branch.
- Name branches `feature/<name>`, `fix/<name>`, `chore/<name>`, or `refactor/<name>`.
- Always commit atomically.
- Always test implementation.
- Before a task, fetch `origin` and `upstream`.
- Use a task branch from the intended base commit.
- After tests pass, merge the task branch into local `master`.
- Push only when the user gives a direct request.

## Agent skills

### Issue tracker

Issues use local Markdown files. Agents need explicit approval before creating an issue. See `docs/agents/issue-tracker.md`.

### Triage labels

The tracker uses the five standard triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

The repo uses a single domain context. See `docs/agents/domain.md`.

### Fork and PR integration

For fork, PR, upstream, or multi-branch work, see `docs/agents/fork-integration.md`.

### Sunrise menu

For Sunrise menu changes, see `docs/agents/menu-development.md`.
