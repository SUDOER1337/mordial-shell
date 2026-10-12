{
  version ? "dirty",
  extraPackages ? [ ],
  runtimeDeps ? [
    brightnessctl
    cliphist
    ddcutil
    wlsunset
    wl-clipboard
    wlr-randr
    imagemagick
    wget
    (python3.withPackages (pp: lib.optional calendarSupport pp.pygobject3))
  ],

  lib,
  stdenvNoCC,
  # build
  qt6,
  quickshell,
  # GL/EGL provider — must match the shell's runtime glibc, see preFixup below
  mesa,
  # runtime deps
  brightnessctl,
  cliphist,
  ddcutil,
  wlsunset,
  wl-clipboard,
  wlr-randr,
  imagemagick,
  wget,
  python3,
  wayland-scanner,
  # calendar support
  calendarSupport ? false,
  evolution-data-server,
  libical,
  glib,
  libsoup_3,
  json-glib,
  gobject-introspection,
}:
let
  src = lib.cleanSourceWith {
    src = ../.;
    filter =
      path: type:
      !(builtins.any (prefix: lib.path.hasPrefix (../. + prefix) (/. + path)) [
        /.github
        /.gitignore
        /Assets/Screenshots
        /Scripts/dev
        /nix
        /LICENSE
        /README.md
        /flake.nix
        /flake.lock
        /shell.nix
        /lefthook.yml
        /CLAUDE.md
        /CREDITS.md
      ]);
  };

  giTypelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    evolution-data-server
    libical
    glib.out
    libsoup_3
    json-glib
    gobject-introspection
  ];
in
stdenvNoCC.mkDerivation {
  pname = "mordial-shell";
  inherit version src;

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtmultimedia
    # Referenced by the wrapper below so libglvnd loads THIS mesa, not the
    # system one (see preFixup).
    mesa
  ];

  installPhase = ''
    mkdir -p $out/share/mordial-shell $out/bin
    cp -r . $out/share/mordial-shell
    ln -s ${quickshell}/bin/qs $out/bin/mordial-shell
  '';

  preFixup = ''
    qtWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath (runtimeDeps ++ extraPackages)}
      --prefix XDG_DATA_DIRS : ${wayland-scanner}/share
      --set-default QS_CONFIG_PATH "$out/share/mordial-shell"
      # Force libglvnd to use the mesa bundled from THIS flake's pinned nixpkgs
      # instead of /run/opengl-driver's. Both libglvnds carry the same default
      # vendor dir (/run/opengl-driver/share/glvnd/egl_vendor.d), but this
      # shell's runtime is glibc 2.42 while the system mesa (26.2.4) is built
      # against glibc 2.44 and its libgallium needs GLIBC_2.43 — so loading the
      # system vendor fails ("EGL not available" -> no GL context -> the shell
      # renders nothing and the lock screen SIGABRTs). The pinned mesa
      # (26.1.0) needs only GLIBC_2.38 and loads fine here.
      --set __EGL_VENDOR_LIBRARY_FILENAMES "${mesa}/share/glvnd/egl_vendor.d/50_mesa.json"
      ${lib.optionalString calendarSupport "--prefix GI_TYPELIB_PATH : ${giTypelibPath}"}
    )
  '';

  meta = {
    description = "A sleek and minimal desktop shell thoughtfully crafted for Wayland, built with Quickshell.";
    homepage = "https://github.com/SUDOER1337/mordial-shell";
    license = lib.licenses.mit;
    mainProgram = "mordial-shell";
  };
}
