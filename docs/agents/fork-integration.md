# Fork and PR Integration

Use this process for upstream commits, fork branches, pull requests, and combined work.

## Safety rules

- Fetch all remote refs before you select a base commit.
- Record each source ref and commit ID in the task notes.
- Do not merge untested source work directly into `master`.
- Do not rebase or change a contributor branch.
- Do not push unless the user asks.
- Keep the live Destiny 2 install unchanged.

## Import one source branch

1. Fetch `origin`, `upstream`, and the contributor remote.
2. Resolve the requested source ref to a commit ID.
3. Create a task branch from that exact commit.
4. Use the correct `feature/`, `fix/`, `chore/`, or `refactor/` prefix.
5. Make fixes as small, complete commits.
6. Run the checks in `CODING_STANDARDS.md`.
7. Build and test the exact task commit with `scripts/build-ref.ps1`.

For a GitHub pull request, fetch its head without changing a local source branch:

```powershell
git fetch upstream pull/<number>/head:refs/remotes/upstream/pr/<number>
git rev-parse upstream/pr/<number>
git switch -c fix/<name> upstream/pr/<number>
```

For a contributor branch, add a read-only source remote when it helps trace the source:

```powershell
git remote add <contributor> <fork-url>
git fetch <contributor> <branch>
git rev-parse <contributor>/<branch>
git switch -c fix/<name> <contributor>/<branch>
```

## Combine branches

Use a new integration branch when work has more than one source.

1. Create `feature/<goal>-integration` from local `master`.
2. Merge one tested task branch.
3. Resolve conflicts from domain behavior, not line order.
4. Run focused tests after each merge.
5. Merge the next tested task branch.
6. Run the full checks and the isolated-client smoke test.
7. Fast-forward local `master` only after all checks pass.

Treat `upstream/master` as one source branch. Merge it on the integration branch.
This keeps local `master` usable when upstream and local work have conflicts.

```powershell
git switch -c feature/<goal>-integration master
git merge --no-ff upstream/master
git merge --no-ff feature/<first-task>
git merge --no-ff feature/<second-task>
```

If a merge has broad conflicts, abort it. Recheck the base and source commits.
Do not accept all changes from one side without a file-by-file review.

## Build and run the result

Build a named branch or commit with the existing build tool:

```powershell
.\scripts\build-ref.ps1 <ref> -Configuration Release
```

Run the repeatable client check after the normal build and regression tests:

```powershell
.\scripts\test-client-smoke.ps1 -Ref <ref>
```

The scripts use the separate `ProjectSunrise` client. They reject the live Steam path.
See `docs/agents/smoke-tests.md` for the test layers and failure rules.

## Completion criteria

- The task branch identifies its source commit.
- Each commit contains one complete change.
- Debug and Release builds pass.
- Debug and Release regression tests pass.
- The isolated-client smoke test reaches the test destination.
- Local `master` contains the tested result.
- The worktree is clean.
