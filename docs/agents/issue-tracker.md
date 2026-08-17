# Issue Tracker: Local Markdown

Issues and specs use Markdown files in `.scratch/`.

## Approval Rule

An agent must ask before it creates an issue.

The user must give explicit approval. Do not treat a task request as issue approval.

## File Layout

- Use one directory for each feature: `.scratch/<feature-slug>/`.
- Put its spec in `.scratch/<feature-slug>/spec.md`.
- Put issues in `.scratch/<feature-slug>/issues/`.
- Name each issue `<NN>-<slug>.md`, starting with `01`.
- Put a `Status:` line near the top.
- Put comments under a `## Comments` heading.

## Create an Issue

First, describe the proposed issue and ask for approval.

After approval, create the file in `.scratch/<feature-slug>/issues/`.

## Read an Issue

Read the path or issue number that the user gives.
