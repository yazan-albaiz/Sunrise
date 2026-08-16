# Sunrise Menu Development

Use this guide for changes to the Sunrise menu and its settings.

## Start

1. Read `CONTEXT.md`, `DOMAIN.md`, and `CODING_STANDARDS.md`.
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
- Use the approved terms from `DOMAIN.md` in labels and code.
- Reuse current controls, spacing, colors, and navigation behavior.
- Make each setting clear when it needs a restart or world reload.

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
