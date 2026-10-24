# Credits & Fork Notes

## Fork Status

**Mordial** is an independent fork of [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) v4. Noctalia v4 was discontinued in favor of a C++ rewrite (v5); Mordial keeps the original QML-based shell maintained.

- **Maintainer:** Nullfjord (SUDOER1337)
- **Repository:** https://github.com/SUDOER1337/mordial-shell

### Maintenance Approach

- **Goals:** keep the QML shell functional, support MangoWC only (via mmsg IPC), fix bugs, add fitting features, preserve existing configs/themes.
- **Non-goals:** C++/architectural rewrite, competing with Noctalia v5, official support or SLAs.

## Configuration Migration (from Noctalia v4)

Paths changed:

```
~/.config/noctalia/  →  ~/.config/mordial/
~/.cache/noctalia/   →  ~/.cache/mordial/
```

`MORDIAL_CONFIG_DIR` / `MORDIAL_CACHE_DIR` override the defaults. To migrate manually:

```bash
cp -r ~/.config/noctalia/ ~/.config/mordial/
cp -r ~/.cache/noctalia/ ~/.cache/mordial/
```

Then rename scheme names in `settings.json`: `"Noctalia (default)"` → `"Mordial (default)"`, `"Noctalia (legacy)"` → `"Mordial (legacy)"`.

## Upstream Relationship

Mordial runs on **upstream Quickshell**, not the archived `noctalia-qs` fork. Three features are re-applied as build-time patches in `nix/quickshell-patched.nix` (sources in `nix/patches/quickshell/`):

1. `PwAudioSpectrum` — `src/services/pipewire/spectrum.{hpp,cpp}`
2. `Region` `CornerState` — `src/core/region.{hpp,cpp}`
3. `QsWindow.flushWaylandState()` — `src/window/proxywindow.{hpp,cpp}`

The vendored `spectrum.*` sources are LGPL-3, same as Quickshell. Bumping the pinned nixpkgs may require rebasing these patches.

---

## Original Noctalia Credits

Mordial is based on Noctalia Shell, made possible by the work of many open-source projects and contributors.

- **[Quickshell](https://github.com/outfoxxed/quickshell)** — the Qt/QML Wayland shell framework
- **[Noctalia Team & contributors](https://github.com/noctalia-dev/noctalia-shell/graphs/contributors)** — original creators and maintainers

Upstream branding assets (the Noctalia owl/moon logo by MrDowntempo and the Talia mascot by [SaberJ2X](https://www.reddit.com/user/SaberJ64/)) are **not** included in Mordial.

### Runtime Dependencies

- **[brightnessctl](https://github.com/Hummer12007/brightnessctl)** — screen brightness
- **[ddcutil](https://www.ddcutil.com/)** — external display brightness
- **[wlsunset](https://sr.ht/~kennylevinsen/wlsunset/)** — night light / blue light filter
- **[wl-clipboard](https://github.com/bugaevc/wl-clipboard)** — Wayland clipboard
- **[cliphist](https://github.com/sentriz/cliphist)** — clipboard history
- **[wlr-randr](https://sr.ht/~emersion/wlr-randr/)** — display configuration
- **[ImageMagick](https://imagemagick.org/)** — image processing
- **[wget](https://www.gnu.org/software/wget/)** — downloads
- **[Python 3](https://www.python.org/)** — theming/calendar helpers

### Icons & Audio

- **[Tabler Icons](https://tabler.io/icons)** — shell icon set
- **[Riyan Resdian on Noun Project](https://thenounproject.com/creator/yaicon/)** — plug icon
- **[Universfield on Pixabay](https://pixabay.com/users/universfield-28281460/)** — notification sound
- **[DrNI on Freesound](https://freesound.org/people/DrNI/sounds/34562/)** — timer alarm sound
- **[Lucas McCallister on Freesound](http://www.freesound.org/samplesViewSingle.php?id=67091)** — volume-change sound

## Special Thanks

- The **Wayland** and **MangoWC** communities
- All original Noctalia contributors

## License

Mordial Shell is licensed under the MIT License (see [LICENSE](LICENSE)). Each dependency above is governed by its own license.
