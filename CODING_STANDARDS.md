# Coding Standards

These rules apply to all Sunrise code changes.

## Scope

- Build Sunrise as a C++20 x64 dynamic library.
- Keep the output name `steam_api64.dll`.
- Use Visual Studio 2026, platform toolset v145, and Windows SDK 10.0.26100.0.
- Do not add copyrighted game data, including test data. Read required game data at run time.
- Extract installed game tables and relations at run time. Do not hard-code them.
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
- Put protocol, opcode, request encoding, request decoding, and data conversion in `middleware`.
- Put local service behavior in `server`.
- Put stored and run-time state in `state`.
- Do not make a Client hook own server or stored-state rules.
- Keep names, comments, and error rules consistent with the implemented behavior.
- Return success only after the full request validates and commits.
- Validate ownership, item locks, placement, capacity, socket rules, and all batch members.
- When a request supports batches, process every member or reject the request before mutation.
- Do not publish a partial state change when validation, encoding, or output fails.
- Add an upgrade path when a settings format changes.
- Bump the cache format when cached data changes. Reject and rebuild old cache formats.

## C++

- Follow `.clang-format`, `.clang-tidy`, and `.editorconfig`.
- Use four spaces. Do not use tabs.
- Keep lines at 100 columns or less.
- Use the `sunrise` namespace and the current folder-based child namespaces.
- Mark a result `[[nodiscard]]` when callers must check it.
- Use `noexcept` when a function does not let an exception leave it.
- Do not use direct `new` or `delete`. Prefer standard containers and value types.
- Check sizes, offsets, handles, pointers, and external data before use.
- Log definition hashes in hexadecimal form.
- Keep warnings at level 4. Treat project warnings as errors.
- Do not enable project warning rules for third-party code.
- Add Doxygen parameter and result entries to documented functions.
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
- Run `git diff --check`.
- Build `Debug|x64` and `Release|x64` with no project warnings or errors.
- Run the Debug and Release regression tests when the repository supplies them.
- Test settings parsing and upgrade paths when a settings format changes.
- Test changed run-time behavior in the separate Project Sunrise game directory.
- Back up the installed Sunrise DLL before a test deployment.
- Do not replace the test DLL while `destiny2.exe` runs.
