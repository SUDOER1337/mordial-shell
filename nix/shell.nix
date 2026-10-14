{
  quickshell,
  # GL/EGL provider — used by shellHook, must match the shell's runtime glibc
  mesa,
  nixfmt,
  statix,
  deadnix,
  shfmt,
  shellcheck,
  jsonfmt,
  lefthook,
  python3,
  kdePackages,
  mkShellNoCC,
}:
mkShellNoCC {
  #it's faster than mkDerivation / mkShell
  packages = [
    quickshell

    # nix
    nixfmt # formatter
    statix # linter
    deadnix # linter

    # shell
    shfmt # formatter
    shellcheck # linter

    # json
    jsonfmt # formatter

    # python
    python3 # settings search index generator

    # CoC
    lefthook # githooks
    kdePackages.qtdeclarative # qmlfmt, qmllint, qmlls and etc; Qt6
  ];

  # The devshell runs `qs` unwrapped, unlike the packaged `mordial-shell`
  # wrapper. Without this, libglvnd falls back to the host's
  # /run/opengl-driver mesa — built against a newer glibc than this flake's
  # runtime — which fails to dlopen and leaves the shell with no EGL context
  # (renders nothing). Point it at this flake's own mesa instead, mirroring
  # the wrapper set in nix/package.nix.
  shellHook = ''
    export __EGL_VENDOR_LIBRARY_FILENAMES=${mesa}/share/glvnd/egl_vendor.d/50_mesa.json
  '';
}
