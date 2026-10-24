<div align="center">

<img src="Assets/mordial.svg" alt="Mordial Shell logo" width="120" />

# Mordial Shell

</div>

> Independent fork of [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) v4. Noctalia moved to a C++ rewrite (v5), so this fork maintains the original QML-based shell for continued use. Full provenance and attribution are in [`CREDITS.md`](CREDITS.md).

A minimal desktop shell for Wayland built on [Quickshell](https://quickshell.org/)

## Features

- Native support for MangoWC (via mmsg IPC)
- Extensive theming with color schemes and automatic wallpaper color generation
- Wallpaper management
- Notifications with history and Do Not Disturb
- Lock screen, OSD (volume/brightness), desktop widgets
- Extensible bar with draggable widgets, configurable per monitor and section
- Multi-monitor support
- Setup wizard for first-time configuration

## Requirements

- [MangoWC](https://github.com/mango-wm/mango-wm) (mmsg must be on PATH)
- [Quickshell](https://quickshell.org/) (upstream; patched at build time, see `nix/quickshell-patched.nix`)
- Runtime dependencies (packaged via Nix): `brightnessctl`, `cliphist`, `ddcutil`, `wlsunset`, `wl-clipboard`, `wlr-randr`, `imagemagick`, `wget`, `python3`
- See `flake.nix` for additional dependencies

## Installation

**Via Nix:**

```bash
nix run github:SUDOER1337/mordial-shell
```

**Via NixOS (home-manager):**

```nix
{
  inputs.mordial-shell.url = "github:SUDOER1337/mordial-shell";

  # in your home-manager config:
  imports = [ inputs.mordial-shell.homeModules.default ];

  programs.mordial-shell.enable = true;
}
```

**Via NixOS (system module):**

```nix
{
  inputs.mordial-shell.url = "github:SUDOER1337/mordial-shell";

  # in your NixOS config:
  imports = [ inputs.mordial-shell.nixosModules.default ];

  services.mordial-shell.enable = true;
}
```

## Configuration

Config files: `~/.config/mordial/`

- `settings.json` — Main settings
- `colors.json` — Current color scheme (auto-generated)
- `colorschemes/` — Downloaded schemes

Environment variables:

- `MORDIAL_CONFIG_DIR` — Override config directory
- `MORDIAL_CACHE_DIR` — Override cache directory
- `MORDIAL_DEBUG` — Enable debug logging

## Development

Setup:

```bash
git clone https://github.com/SUDOER1337/mordial-shell
cd mordial-shell
nix flake show
```

Build:

```bash
nix build
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and submit a pull request

## Scope

Mordial is a **desktop shell**, not a full desktop environment. It handles the visual layer (bars, panels, notifications, widgets) but not file management, display greeter, window management/tiling, or system login.

## Documentation

Most Noctalia v4 documentation applies:

- [Noctalia Docs](https://docs.noctalia.dev)
- Contributor docs: [`Docs/`](Docs/) — start with [`Docs/bar-widgets.md`](Docs/bar-widgets.md) and [`Docs/desktop-widgets.md`](Docs/desktop-widgets.md)
- GitHub Issues for questions

## Credits

Mordial is a fork of Noctalia Shell; see [`CREDITS.md`](CREDITS.md) for full attribution and fork notes.

## License

MIT License - see [LICENSE](./LICENSE) for details.

## Links

- [GitHub (this fork)](https://github.com/SUDOER1337/mordial-shell)
- [Original Noctalia](https://github.com/noctalia-dev/noctalia-shell)
- [Noctalia v5](https://noctalia.dev)
