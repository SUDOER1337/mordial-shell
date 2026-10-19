## Required process

1. Inspect the repository and locate the existing launcher, power menu, shared UI components, theme system, data providers, and system-action handlers.
2. Document the existing architecture and identify which functionality must be preserved.
3. Produce a file-level change plan before modifying shared infrastructure.
4. Implement the launcher and power menu as separate UI modules, reusing shared components where appropriate.
5. Test each menu independently, then verify their integration.
6. Compare the rendered results with the reference screenshots and correct discrepancies.

## Launcher requirements

The launcher must contain a top search field, a vertically stacked result list, and a bottom navigation bar with Apps, Commands, and Files tabs.

Result rows must support primary labels, optional inline descriptions, selection, keyboard navigation, scrolling, and activation.

Mode switching must update the active search provider and results without breaking focus or selection behavior.

## Power-menu requirements

The power menu must contain a two-part header, a separate uptime row, and five vertically stacked actions: Lock, Suspend, Logout, Reboot, and Shutdown.

Each action must contain a left-aligned icon and label. Keyboard navigation, selection, dismissal, and existing system-operation handlers must continue to work.

## Architectural constraints

- Preserve existing working functionality wherever possible.
- Reuse existing services, providers, models, and components when suitable.
- Keep presentation, application state, and system operations separated.
- Keep the launcher and power menu independently maintainable.
- Avoid duplicated logic and unnecessary new dependencies.
- Keep styling configurable and separate from layout logic.
- Do not modify unrelated shell modules without a demonstrated requirement.
- Do not invent filenames, APIs, services, or current repository structure; inspect the code first.

## Visual constraints

Use the supplied screenshots as the source of truth for geometry, spacing, alignment, component hierarchy, and proportions.

The immediate layout-and-functionality implementation must not depend on copying the reference color palette or font choices. Reuse Mordial's existing theme, keeping visual tokens independently configurable for later styling work.

## Completion criteria

The implementation must build and run in the existing environment, preserve existing functionality, satisfy the launcher and power-menu acceptance criteria, and introduce no known regressions.

Provide a final report containing:

- Files changed and the reason for each change.
- Components created or reused.
- Existing functionality preserved.
- Tests performed and their results.
- Visual discrepancies remaining.
- Known limitations and recommended next steps.

Do not claim that a test passed unless it was actually run.
