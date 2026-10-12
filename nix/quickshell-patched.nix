/**
  Upstream quickshell (from nixpkgs) plus the three noctalia-qs features the
  Mordial shell depends on. The noctalia-qs fork is archived, so instead of
  tracking it we re-apply only what is actually used:

    1. PwAudioSpectrum              - src/services/pipewire/spectrum.{hpp,cpp}
    2. Region CornerState           - src/core/region.{hpp,cpp}
    3. QsWindow.flushWaylandState() - src/window/proxywindow.{hpp,cpp}

  The spectrum sources (LGPL-3, same license as quickshell) are vendored and
  dropped in via postPatch; the rest are ordinary text patches.
*/
{ quickshell }:
quickshell.overrideAttrs (
  final: prev: {
    patches = (prev.patches or [ ]) ++ [
      ./patches/quickshell/0001-pipewire-audio-spectrum.patch
      ./patches/quickshell/0002-region-corner-state.patch
      ./patches/quickshell/0003-proxiedwindow-flush-wayland-state.patch
    ];

    postPatch = (prev.postPatch or "") + ''
      cp ${./patches/quickshell/spectrum.hpp} src/services/pipewire/spectrum.hpp
      cp ${./patches/quickshell/spectrum.cpp} src/services/pipewire/spectrum.cpp
    '';
  }
)
