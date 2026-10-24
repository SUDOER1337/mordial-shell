// File: Commons/Look.qml
// =============================================================================
// Island look — impasto-inspired design tokens. The lock screen uses these
// unconditionally (it IS the island); the session menu opts in via settings.
// Purely visual: solid near-black grounds with white inks, so nothing here
// depends on blur or transparency. Accents and error still follow the active
// color scheme (Color.mPrimary / Color.mError); the only fixed hues are the
// status colors, which must not shift with the wallpaper.
//
// Functions:
//   scaleDuration(baseMs)     - Scale a motion duration by the global animation speed
//
// Section markers:
//   ── Gates ──       Scope switches mirrored from Settings
//   ── Surfaces ──    Opaque grounds, cards, borders
//   ── Inks ──        White washes for text and glyphs
//   ── Status ──      Fixed semantic colors
//   ── Lock wash ──   Album-art backdrop constants
//   ── Text shadow ── "Shadowed rather than dimming the background"
//   ── Shake ──       Wrong-password feedback on the pill
//   ── Motion ──      Hover/medium/morph durations
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  // ── Gates ────────────────────────────────────────────────────────────────
  // Read once per binding: components branch on these instead of Settings.
  // The lock screen is always island (no gate); the session menu opts in.

  readonly property bool sessionEnabled: Settings.data.islandLook.session

  // ── Surfaces ─────────────────────────────────────────────────────────────

  // The island is the identity: pure black, never palette-derived.
  readonly property color ground: "#000000"
  readonly property color surface: "#141414"
  readonly property color surfaceHover: "#1f1f1f"
  readonly property color border: "#262626"
  // Ground and ink over photographs (the lock's album wash).
  readonly property color scrim: "#bf000000"
  readonly property color scrimText: "#ffffff"

  // ── Inks ─────────────────────────────────────────────────────────────────

  readonly property color ink: "#ffffff"
  readonly property color inkDim: Qt.rgba(1, 1, 1, 0.72)
  readonly property color inkMuted: Qt.rgba(1, 1, 1, 0.55)
  // Hairline separator on black grounds (Impasto: #20ffffff).
  readonly property color hairline: "#20ffffff"

  // ── Status ───────────────────────────────────────────────────────────────
  // Fixed, so meaning never drifts with the palette.

  readonly property color statusBad: "#ff453a"
  readonly property color statusGood: "#32d74b"

  // ── Lock wash ────────────────────────────────────────────────────────────
  // The playing track's cover painted coarse at a tenth of the screen, then
  // stretched back up: a heavy, even wash instead of a legible image. A flat
  // black scrim sits on top for separation, not contrast.

  readonly property real washScale: 0.10
  readonly property real washBlur: 0.85
  readonly property int washBlurMax: 64
  readonly property real washBrightness: -0.28
  readonly property real washSaturation: 0.25
  readonly property real lockScrimOpacity: 0.18

  // ── Text shadow ──────────────────────────────────────────────────────────
  // Large display text is lifted with a soft black shadow instead of a dimmed
  // scrim under it, so the wash keeps its color.

  readonly property real textShadowOpacity: 0.45
  readonly property int textShadowOffset: 3

  // ── Shake ────────────────────────────────────────────────────────────────
  // Wrong-password feedback on the pill: horizontal nudge, red border.

  readonly property real shakeAmplitude: 9
  readonly property int shakeInterval: 55

  // ── Motion ───────────────────────────────────────────────────────────────

  readonly property int durationFast: scaleDuration(140)
  readonly property int durationMedium: scaleDuration(200)
  readonly property int durationMorph: scaleDuration(380)

  /** Scale a motion duration by the global animation speed. Fast speed (>1) shortens, slow (<1) lengthens; disabled animations always return 0.
  *  @param baseMs - Unscaled duration in milliseconds
  *  @returns Scaled duration in milliseconds
  */
  function scaleDuration(baseMs) {
    if (Settings.data.general.animationDisabled)
      return 0;
    return Math.round(baseMs / Settings.data.general.animationSpeed);
  }
}
