### Overview

Mordial uses a keyboard-first interaction model inspired by Vim. Interactive shell components such as the application launcher, powermenu, notification center, and other menus share a consistent set of navigation principles.

The goal is not to recreate Vim inside the shell, but to make navigating, editing, and executing actions predictable without requiring a mouse.

The system is built around three concepts:

- **Mode:** Determines how keyboard input is interpreted.
- **Focus:** Determines which interface region receives keyboard input.
- **Selection:** Determines which item is currently highlighted.

These concepts must remain independent so that components can share the same navigation system without sharing identical layouts or behavior.

## 1. Interaction Modes

### Normal Mode

The default mode for keyboard navigation and menu interaction.

| Key     | Action                                                   |
| ------- | -------------------------------------------------------- |
| `h`     | Navigate to the previous tab in the launcher             |
| `j`     | Select the next item                                     |
| `k`     | Select the previous item                                 |
| `l`     | Navigate to the next tab in the launcher                 |
| `i`     | Enter Insert Mode at the current input cursor position   |
| `a`     | Enter Insert Mode at the end of the current input        |
| `Enter` | Activate the selected item or execute the current action |
| `Esc`   | Close the menu or return to the parent context           |

Keybindings are context-aware. For example, `h` and `l` navigate between launcher tabs, while `j` and `k` navigate vertically through selectable items.

Components without tabs do not need to implement horizontal navigation unless their layouts require it.

### Insert Mode

Used for typing and editing text in input fields, such as the launcher's search box.

- Printable keys insert text normally.
- Standard text editing, cursor movement, selection, and clipboard shortcuts remain available.
- `Esc` returns to Normal Mode.
- `Enter` executes the selected result or submits the input, depending on the component.
- `Tab` may be used for focus switching when appropriate.

`i` and `a` both enter Insert Mode, following Vim's familiar insertion behavior:

- `i`: Insert at the current cursor position.
- `a`: Move to the end of the existing input, then insert.

In Insert Mode, navigation keys such as `h`, `j`, `k`, and `l` must behave as ordinary text when typed into the input field.

### Component-Specific Modes

Some components may introduce additional states, such as a confirmation view or an expanded notification.

These should be treated as component-specific interaction states rather than separate global modes whenever possible.

For example, the powermenu can reuse Normal Mode for selecting actions and introduce a confirmation state for destructive operations.

## 2. Focus and Selection

Focus and selection are separate concepts.

- **Focus** determines where keyboard input is directed.
- **Selection** determines which item is highlighted for navigation or activation.

The launcher has at least two focusable regions:

1. **Input:** The search field.
2. **Results:** The selectable list of applications or commands.

The selected result should remain highlighted independently of whether the input or results list currently has focus.

Changing focus should not clear the search query or unnecessarily reset the current selection.

When search results change, preserve the current selection if the corresponding item remains available. Otherwise, select the first matching result when one exists.

## 3. Application Launcher

### Initial State

When the launcher opens:

- Enter Normal Mode.
- Focus the results region.
- Select the first available result, if one exists.
- Preserve normal mouse interaction.

This allows users to navigate immediately without typing, while retaining a straightforward way to enter a search query.

### Input and Results Navigation

In Normal Mode:

- `j` / `k`: Navigate through results.
- `h` / `l`: Switch to the previous or next launcher tab.
- `i`: Focus the search field and enter Insert Mode at the current cursor position.
- `a`: Focus the search field and enter Insert Mode at the end of the existing query.
- `Enter`: Launch the selected application or execute the selected command.
- `Esc`: Close the launcher.

In Insert Mode:

- Typing updates the search query.
- Search results update according to the query.
- `Esc` returns to Normal Mode and restores focus to the results region.
- `Enter` activates the selected result when a valid selection exists.

The query should persist when switching between modes or tabs unless a particular launcher feature explicitly requires otherwise.

### Optional Focus Switching

`Tab` and `Shift+Tab` may provide an alternative way to switch between the input and results regions.

This is optional and should be implemented only if it improves usability without introducing conflicting behavior with existing input conventions.

The primary interaction remains `i` / `a` to enter Insert Mode and `Esc` to return to Normal Mode.

## 4. Powermenu

The powermenu uses the same navigation principles without requiring an input field.

- Open in Normal Mode.
- `j` / `k` navigate through available actions.
- `Enter` executes the selected action.
- `Esc` closes the menu or cancels the current confirmation.
- Destructive actions may require a separate confirmation state.

The powermenu should not introduce Insert Mode unless an editable field is added in the future.

## 5. Notification Center

The notification center reuses the same navigation system.

- `j` / `k` navigate through notifications.
- `Enter` opens or activates the selected notification when supported.
- Component-specific bindings may expand, dismiss, or otherwise interact with notifications.
- Editable fields, if introduced, follow the same Insert Mode rules.

Navigation must not trigger destructive notification actions accidentally. Dismissal and other potentially irreversible actions should have deliberate bindings.

## 6. Shared Keybinding Principles

### Context-Aware Input

A key's meaning depends on the active mode and component.

For example:

| Context                | Key   | Behavior              |
| ---------------------- | ----- | --------------------- |
| Launcher, Normal Mode  | `j`   | Select next result    |
| Launcher, Normal Mode  | `l`   | Switch to next tab    |
| Launcher, Insert Mode  | `j`   | Insert the letter `j` |
| Launcher, Insert Mode  | `l`   | Insert the letter `l` |
| Powermenu, Normal Mode | `j`   | Select next action    |
| Powermenu, Normal Mode | `Esc` | Close or cancel       |

The same key must not trigger competing actions within the same context.

### Escape Behavior

`Esc` follows a consistent priority:

1. Exit Insert Mode and return to Normal Mode.
2. Cancel an active confirmation or temporary interaction state.
3. Return to a parent view when one exists.
4. Close the menu when no higher-priority action applies.

A single press should perform only the highest-priority applicable action.

### Fallback Behavior

Components should define sensible behavior when an action is unavailable.

For example, attempting to navigate to a nonexistent tab should do nothing rather than unexpectedly changing focus or closing the menu.

Selection navigation should handle empty lists and list boundaries safely.

## 7. Visual Feedback

The interface should communicate the current interaction state without overwhelming the design.

- Provide a subtle indication of Normal Mode and Insert Mode when useful.
- Make the focused input field visually distinguishable.
- Clearly highlight the selected item.
- Indicate the active launcher tab.
- Maintain consistent focus styling across shell components.

Mode indicators are supplementary. The navigation system must remain predictable even when the user is not looking at a mode label.

## 8. Implementation Architecture

Implement keyboard navigation as a reusable interaction system rather than duplicating key handling in each component.

### Shared State

The interaction system should represent:

- Current mode.
- Currently focused region.
- Current selection.
- Available navigation actions.
- Component-specific interaction state, where necessary.

Mode, focus, and selection must be stored independently.

### Keyboard Event Routing

Keyboard events should be routed according to the active component, mode, and focus.

- Normal Mode interprets navigation keys as shell commands.
- Insert Mode delegates ordinary text entry and editing to the focused input.
- Component-specific bindings extend the shared behavior without overriding core text input.
- Handled key events should not trigger conflicting actions elsewhere in the interface.

Do not intercept all keyboard input globally. Only handle shortcuts that belong to the active interaction context.

### Component Integration

Each interactive component should declare or implement:

- Its available focusable regions.
- Its selectable items.
- Its supported navigation actions.
- Its mode-specific keybindings.
- Its activation, cancellation, and closing behavior.

Shared behavior should be centralized where practical, while component-specific differences remain explicit.

### Extensibility

The system should support future components without requiring a redesign of the core interaction model.

Potential extensions include:

- Additional launcher tabs and navigation layouts.
- Nested menus and confirmation views.
- Notification actions.
- Configurable keybindings.
- Conventional keyboard shortcuts alongside Vim-style navigation.

## 9. Implementation Roadmap

### Phase 1 — Define the Interaction Model

- [ ] Establish Normal Mode and Insert Mode.
- [ ] Separate mode, focus, and selection state.
- [ ] Define keybinding priority and Escape behavior.
- [ ] Specify how components register their navigation actions.

### Phase 2 — Implement the Launcher

- [ ] Open in Normal Mode with the results region focused.
- [ ] Implement `j` / `k` result navigation.
- [ ] Implement `h` / `l` tab navigation.
- [ ] Implement `i` / `a` input focus and insertion behavior.
- [ ] Preserve queries and selection state appropriately.
- [ ] Verify that Insert Mode supports ordinary text editing.

### Phase 3 — Integrate Other Menus

- [ ] Apply shared navigation to the powermenu.
- [ ] Add notification center navigation.
- [ ] Implement component-specific actions and confirmation states.
- [ ] Verify consistent Escape behavior.

### Phase 4 — Refine and Extend

- [ ] Add subtle mode and focus indicators.
- [ ] Test empty results, selection boundaries, and unavailable actions.
- [ ] Test keyboard and mouse interaction together.
- [ ] Consider optional `Tab` / `Shift+Tab` focus switching.
- [ ] Evaluate configurable keybindings after the shared system stabilizes.

## Guiding Principle

**Mordial treats keyboard navigation as a shared interaction language across the desktop shell.**

Users should be able to predict how menus behave based on a small set of consistent rules. Each component may have its own layout and actions, but the underlying principles of mode, focus, selection, and keyboard event routing should remain coherent.
