# Client Smoke Tests

Use these tests after the Debug and Release regression tests pass.

## Layers

1. Regression tests check parsing, upgrades, validation, and transaction rules.
2. The client smoke test checks build, deployment, startup, orbit, and activity load.
3. A feature check uses its transaction log events after the client test passes.

Do not replace regression tests with screen input. Use screen input only for Client behavior.

## Client test

Run this command from the repo root:

```powershell
.\scripts\test-client-smoke.ps1 -Ref HEAD
```

The test does this work:

- Resolves the ref to one commit.
- Builds and deploys that exact commit.
- Uses only `D:\Games\Sunrise\ProjectSunrise` by default.
- Saves the current DLL and settings.
- Starts `destiny2.exe`.
- Selects a character.
- Opens the Director.
- Launches EDZ Trostland.
- Checks the Sunrise log for each completed stage.
- Stops the process.
- Restores the prior DLL and settings.

The test stores its result, log, backups, and failure image under `build/smoke/`.

Use `-PlanOnly` to check the ref and paths without a build or game launch:

```powershell
.\scripts\test-client-smoke.ps1 -Ref HEAD -PlanOnly
```

## Feature checks

Keep feature checks small. Test one user result in each check.

For item acquisition, equipment, and socket plug work, require these ordered results:

1. `ev=acquire` reports the successful transaction commit.
2. `ev=equip` reports the successful transaction commit.
3. `ev=socket_plug` reports the successful transaction commit.
4. The game process stays open and the destination remains loaded.

Add direct regression coverage for each state change first. Add stable Client input steps only when
the test account supplies the required owned items. Do not hard-code item definitions in the test.

## Failure rules

- A required hook failure fails the test.
- An early process exit fails the test.
- A missing stage marker fails the test at its time limit.
- A failed test must keep its log and failure image.
- A failed test must still restore the prior DLL and settings.
