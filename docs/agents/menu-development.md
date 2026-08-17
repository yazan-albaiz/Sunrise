# Sunrise Menu Development

Use this guide for changes to the Sunrise menu and its settings.

## Start

1. Read `CONTEXT.md`, `docs/agents/domain.md`, and `CODING_STANDARDS.md`.
2. Find the current menu view, stored settings, and run-time owner.
3. Create one `feature/` or `fix/` branch for one menu result.
4. Keep the default behavior unchanged unless the task changes it.

## Design rules

- Keep drawing and input code in the current menu layer.
- Keep stored values in the settings or state owner.
- Keep server behavior in the server layer.
- Keep Client hooks and memory access in the client layer.
- Do not put game rules in a button handler.
- Do not hard-code installed game definitions or hashes.
- Use the approved terms from `docs/agents/domain.md` in labels and code.
- Reuse current controls, spacing, colors, and navigation behavior.
- Make each setting clear when it needs a restart or world reload.

## Code map

- `Sunrise/src/core/ui/layout` owns the Sunrise window and page navigation.
- `Sunrise/src/core/ui/components` owns shared controls.
- `Sunrise/src/core/ui/modules/registry` owns page registration and page selection.
- `Sunrise/src/client/ui/runtime/client_ui_module_runtime.cpp` registers Client pages.
- `Sunrise/src/server/ui/runtime/server_ui_module_runtime.cpp` registers Server pages.
- `Sunrise/src/client/ui/teleport` is a Client page example.
- `Sunrise/src/server/ui/activity_override` is a Server page example.
- `Sunrise/src/core/settings` parses the main startup settings.
- `Sunrise/src/client/teleport/teleport_settings_store.cpp` shows a run-time save flow.

Use `PageRegistration::acquire` to register a page. Use a namespaced stable ID. Put page drawing
in its UI folder. Put state checks and writes in the state owner. The Teleport page reads a settings
snapshot, draws controls, validates a changed value, and calls `publish`. The store locks the value,
writes its small file, and reports errors in the Client log.

For each control, define these items before implementation:

- Label and help text.
- Stored value and default value.
- Valid values and error handling.
- Run-time owner and update time.
- Disabled state and dependency rules.
- Test method.

## Tests

- Test settings read, write, default, and upgrade behavior.
- Test the run-time action without the menu when a direct seam exists.
- Test keyboard and mouse input.
- Test small and large supported window sizes.
- Test long labels and error text.
- Run Debug and Release regression tests.
- Run the isolated-client smoke test.

Use `scripts/test-client-smoke.ps1` for the normal launch and activity check.
Extend its input steps and log checks when a menu feature needs run-time UI steps.

## Completion criteria

- The control uses the current menu style.
- The setting has one owner and one default.
- Invalid input cannot change run-time state.
- Settings upgrades keep old user files valid.
- The related run-time action works in the isolated client.
- The live Destiny 2 install stays unchanged.
