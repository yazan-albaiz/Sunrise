# Coding Standards

These rules apply to all Sunrise code changes.

## Scope

- Build Sunrise as a C++20 x64 dynamic library.
- Keep the output name `steam_api64.dll`.
- Do not add copyrighted game data. Read required game data at run time.
- Put server behavior in server requests and pushes when possible.
- Use a Client patch only when the server cannot provide the behavior.
- Keep one feature or fix in each task branch.
- Do not merge partial or nonfunctional work.

## Design

- Read `CONTEXT.md` before code work.
- Use the approved domain terms in names and docs.
- Keep code in the current `core`, `client`, `middleware`, `server`, and `state` areas.
- Put shared services in `core`.
- Put Client hooks and Client memory access in `client`.
- Put protocol and data conversion code in `middleware`.
- Put local service behavior in `server`.
- Put stored and run-time state in `state`.
- Do not make a Client hook own server or stored-state rules.

## C++

- Follow `.clang-format`, `.clang-tidy`, and `.editorconfig`.
- Use four spaces. Do not use tabs.
- Keep lines at 100 columns or less.
- Use the `sunrise` namespace and the current folder-based child namespaces.
- Mark a result `[[nodiscard]]` when callers must check it.
- Use `noexcept` when a function does not let an exception leave it.
- Check sizes, offsets, handles, pointers, and external data before use.
- Keep warnings at level 4. Treat project warnings as errors.
- Do not enable project warning rules for third-party code.
- Add comments and docs for intent, limits, and non-obvious behavior.
- Do not add comments that only repeat the code.

## Changes

- Use `feature/<name>`, `fix/<name>`, `chore/<name>`, or `refactor/<name>`.
- Make each commit one complete change.
- Explain what changed, why it changed, and its effects.
- Update docs when behavior, setup, or domain language changes.
- Do not change files in the live Destiny 2 install.

## Checks

- Format all changed C++ files with the repo `.clang-format` file.
- Run clang-tidy with the repo `.clang-tidy` file when the tool is available.
- Build `Debug|x64` and `Release|x64`.
- Test changed run-time behavior in the separate Project Sunrise game directory.
- Back up the installed Sunrise DLL before a test deployment.
- Do not replace the test DLL while `destiny2.exe` runs.
