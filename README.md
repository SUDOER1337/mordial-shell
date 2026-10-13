<div align="center">

<img src="Assets/mordial.svg" alt="Mordial Shell logo" width="120" />

# Mordial Shell

</div>

> Independent fork of [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) v4. Noctalia is now v5 (C++), so this fork maintains the original QML-based shell for continued use.

A minimal desktop shell for Wayland built on [Quickshell](https://quickshell.org/)

## Features

- Native support for MangoWC (via mmsg IPC)
- Extensive theming with color schemes and automatic wallpaper color generation
- Wallpaper management with Wallhaven integration --(planned to remove Wallhaven)
- Notifications with history and Do Not Disturb
- Lock screen, OSD (volume/brightness), desktop widgets
- Plugin system for extending functionality
- Multi-monitor support
- Setup wizard for first-time configuration

## Requirements

- [MangoWC](https://github.com/mango-wm/mango-wm) (mmsg must be on PATH)
- [Quickshell](https://quickshell.org/) (upstream; patched at build time, see `nix/quickshell-patched.nix`)
- See `flake.nix` for additional dependencies

## Installation

**Via Nix:**

```bash
nix run github:SUDOER1337/mordial-shell
```

**Via NixOS (home-manager):**

```nix
programs.mordial-shell = {
  enable = true;
};
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
- GitHub Issues for questions
- Original [Noctalia Discord](https://discord.gg/) community

## Credits

- **Mordial Fork**: Maintained by Nullfjord (SUDOER1337)
- **Original Noctalia**: [noctalia-dev](https://github.com/noctalia-dev/noctalia-shell)
- **Quickshell**: [quickshell.org](https://quickshell.org/)

## License

MIT License - see [LICENSE](./LICENSE) for details.

## Links

- [GitHub (this fork)](https://github.com/SUDOER1337/mordial-shell)
- [Original Noctalia](https://github.com/noctalia-dev/noctalia-shell)
- [Noctalia v5](https://noctalia.dev)
