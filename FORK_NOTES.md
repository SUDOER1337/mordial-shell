# Fork Notes - Mordial Shell

This document explains the current state of Mordial as an independent fork of Noctalia Shell.

---

## Fork Status

**Mordial** is an independent fork of [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) (v4).

### Timeline

- **Original Noctalia v4** - Maintained by the Noctalia team as a complete QML/Quickshell desktop shell
- **Noctalia v5 Announcement** - Full rewrite in C++ (no longer QML-based), focus shifted to v5 development
- **Noctalia v4 Discontinued** - v4 no longer receives updates; replaced by C++ v5
- **Mordial Fork Created** - Forked from Noctalia v4 for independent maintenance and continued QML-based development

---

## Maintenance Approach

### Goals

- ✅ Keep the QML-based shell functional and maintained
- ✅ Maintain MangoWC as the sole supported compositor (via mmsg IPC)
- ✅ Fix bugs and add community-requested features
- ✅ Maintain compatibility with existing configs and themes

### Non-Goals

- ❌ Rewrite in C++ or major architectural changes
- ❌ Compete with Noctalia v5 (different approaches, both valid)
- ❌ Official support or SLAs

### Scope

- Bug fixes for existing functionality
- Compatibility updates for new Wayland compositor features
- Configuration path changes (e.g., `~/.config/mordial/`)
- Rebranding to reflect fork status
- Minor feature additions that fit the shell's scope

### Out of Scope

- Major new subsystems beyond the shell's responsibility
- Support for proprietary compositors or desktop environments
- Guarantees on update frequency or feature roadmap

---

## Configuration Migration

### For Existing Noctalia v4 Users

If you're migrating from Noctalia v4 to Mordial, note these changes:

**Old Config Path:**

```
~/.config/noctalia/
~/.cache/noctalia/
```

**New Config Path:**

```
~/.config/mordial/
~/.cache/mordial/
```

**Automatic Path Change:**

- Mordial uses `MORDIAL_CONFIG_DIR` and `MORDIAL_CACHE_DIR` environment variables
- If not set, defaults to `~/.config/mordial/` and `~/.cache/mordial/`

**Manual Migration:**

1. Copy your existing Noctalia v4 config:
   ```bash
   cp -r ~/.config/noctalia/ ~/.config/mordial/
   cp -r ~/.cache/noctalia/ ~/.cache/mordial/
   ```
2. Update color scheme names in `~/.config/mordial/settings.json`:
   - `"Noctalia (default)"` → `"Mordial (default)"`
   - `"Noctalia (legacy)"` → `"Mordial (legacy)"`

---

## Upstream Relationship

**Original Repository:** https://github.com/noctalia-dev/noctalia-shell

This fork does **not** submit pull requests upstream or claim to be the official continuation. It is maintained as an independent project.

**Why not merge back?**

- The Noctalia project has moved to v5 (C++ rewrite)
- The two projects have diverged in goals and maintenance model
- Both approaches are valid; users can choose which fits their needs

---

## Dependency Notes

### Quickshell Dependency

Mordial runs on **upstream Quickshell** (from nixpkgs), not the archived
`noctalia-qs` fork. The fork was only ever needed for three features, which are
re-applied to upstream at build time in `nix/quickshell-patched.nix`:

1. `PwAudioSpectrum` — `src/services/pipewire/spectrum.{hpp,cpp}`
2. `Region` `CornerState` — `src/core/region.{hpp,cpp}`
3. `QsWindow.flushWaylandState()` — `src/window/proxywindow.{hpp,cpp}`

The patches live in `nix/patches/quickshell/`. The vendored `spectrum.*` sources
are LGPL-3 (same license as Quickshell). Bumping the pinned nixpkgs may require
rebasing these patches if upstream changes the touched files.

**If the patches ever drift:**

- Rebase them against the new upstream source, or
- Fall back to tracking a specific Quickshell revision as a dedicated flake input

---

## Future Directions

### Potential Development Areas

- Bug fixes and stability improvements
- Support for new Wayland compositor features
- UI/UX refinements
- Theme and customization options
- Performance optimizations

### Not Planned

- Major architectural rewrites (C++, Rust, etc.)
- Support for non-Wayland environments
- Desktop environment features (file manager, settings daemon, etc.)

---

## How to Contribute

If you'd like to contribute to Mordial:

1. **Bug Reports** - Open an issue describing the problem and reproduction steps
2. **Feature Requests** - Open an issue or discuss in the repo's discussion section
3. **Pull Requests** - Fork, make changes, and submit a PR with a clear description
4. **Code Style** - Follow the existing QML conventions used in the project

---

## Disclaimer

Mordial is provided **as-is** without guarantees. It's a community-maintained fork, not an official project. Use at your own risk.

For the official Noctalia project and v5, visit: https://noctalia.dev
