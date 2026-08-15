# Branch Builds

Sunrise builds as `steam_api64.dll`. The game data does not change for each source revision.

## Requirements

- Install Visual Studio 2026 or Build Tools 2026.
- Select the **Desktop development with C++** workload.
- Install the v145 platform toolset and Windows SDK 10.0.26100.
- Keep the Project Sunrise game files in `D:\Games\Sunrise\ProjectSunrise`.

## Build a Ref

Run this command from the repo root:

```powershell
.\scripts\build-ref.ps1 -Ref feature/example
```

You can use a branch name, tag, or commit hash. The default build is `Release|x64`.

The script creates a detached Git worktree. It puts the DLL here:

```text
build\refs\<commit>\Release\steam_api64.dll
```

## Build and Deploy

Close `destiny2.exe`. Then run:

```powershell
.\scripts\build-ref.ps1 -Ref <commit> -Configuration Release -Deploy
```

The script performs these actions:

1. Resolves the ref to one commit.
2. Builds that commit in a separate worktree.
3. Saves the built DLL under `build\refs`.
4. Stops if `destiny2.exe` runs.
5. Backs up the current test DLL.
6. Replaces only `ProjectSunrise\bin\x64\steam_api64.dll`.

The script rejects the live Destiny 2 directory as a deployment target.
