// File: Commons/Color.qml
// =============================================================================
// Color Token Singleton — 30 semantic color tokens for the shell UI.
// Serves as the single source of truth for all color references.
// Every UI component binds to Color.mPrimary (and friends), never to raw values.
//
// Functions:
//   resolveColorKey(key)          - Map "primary"/"secondary"/"tertiary"/"error" → main color
//   resolveOnColorKey(key)        - Map to corresponding "on" color
//   resolveColorKeyOptional(key)  - Same but returns "transparent" for unknown keys
//   adaptiveOpacity(baseOpacity)  - Adjust opacity for dark/light + performance mode
//   smartAlpha(baseColor)        - Alpha with translucency toggle + performance mode
//   scheduleExternalColorReload() - Debounced reload from colors.json watcher
//   startTransition()             - Set isTransitioning flag for animation
//   _refreshToken(token)          - Apply saturation then assign to root property
//   _refreshSlot(slot)            - Refresh all tokens in a slot
//
// Properties (30 color tokens):
//   mPrimary, mOnPrimary, mPrimaryContainer, mOnPrimaryContainer
//   mSecondary, mOnSecondary, mSecondaryContainer, mOnSecondaryContainer
//   mTertiary, mOnTertiary, mTertiaryContainer, mOnTertiaryContainer
//   mError, mOnError, mErrorContainer, mOnErrorContainer
//   mSurface, mOnSurface, mSurfaceVariant, mOnSurfaceVariant
//   mSurfaceContainerLow, mSurfaceContainer, mSurfaceContainerHigh
//   mBackground, mOnBackground
//   mOutline, mOutlineVariant
//   mShadow, mHover, mOnHover
// =============================================================================

// -- Slot & Token Index --
// primary    | mPrimary, mOnPrimary, mPrimaryContainer, mOnPrimaryContainer
// secondary  | mSecondary, mOnSecondary, mSecondaryContainer, mOnSecondaryContainer
// tertiary   | mTertiary, mOnTertiary, mTertiaryContainer, mOnTertiaryContainer
// error      | mError, mOnError, mErrorContainer, mOnErrorContainer
// surface    | mSurface, mOnSurface, mSurfaceVariant, mOnSurfaceVariant,
//            | mSurfaceContainerLow, mSurfaceContainer, mSurfaceContainerHigh
// background | mBackground, mOnBackground
// outline    | mOutline, mOutlineVariant
// unaffiliated | mShadow, mHover, mOnHover

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Helpers/ColorsConvert.js" as CC
import qs.Commons
import qs.Services.Power

Singleton {
  id: root

  property bool reloadColors: false

  // === External File Watching ===

  /** Debounced timer that fires 200ms after the last external change notification.
  *  Prevents rapid re-reads when atomic file swaps or batch writes occur. */
  Timer {
    id: externalColorReloadTimer
    running: false
    interval: 200
    onTriggered: {
      if (customColorsFile.path !== undefined) {
        Logger.d("Color", "Reloading colors from disk");
        reloadColors = true;
        customColorsFile.reload();
      }
    }
  }

  /** Schedule a deferred reload of colors.json.
  *  Guards against calls before config directories exist. */
  function scheduleExternalColorReload() // Deferred reload from file watcher
  {
    if (!Settings.directoriesCreated || customColorsFile.path === undefined) {
      return;
    }
    externalColorReloadTimer.restart();
  }

  // Suppress transition animations until the first colors.json load completes
  // (avoids flashing from default → initial scheme transition)
  property bool skipTransition: true

  // Flag indicating theme colors are currently transitioning (used by consumers to gate animations)
  property bool isTransitioning: false

  /** Timer that clears the transitioning flag after the longest animation completes.
  *  Duration = Style.animationSlowest + 50ms fudge factor to ensure all parallel animations finish. */
  Timer {
    id: transitionTimer
    interval: Style.animationSlowest + 50
    onTriggered: root.isTransitioning = false
  }

  // === ACCENT COLORS ===

  // -- Primary --
  property color mPrimary: defaultColors.mPrimary
  property color mOnPrimary: defaultColors.mOnPrimary
  property color mPrimaryContainer: defaultColors.mPrimaryContainer
  property color mOnPrimaryContainer: defaultColors.mOnPrimaryContainer

  // -- Secondary --
  property color mSecondary: defaultColors.mSecondary
  property color mOnSecondary: defaultColors.mOnSecondary
  property color mSecondaryContainer: defaultColors.mSecondaryContainer
  property color mOnSecondaryContainer: defaultColors.mOnSecondaryContainer

  // -- Tertiary --
  property color mTertiary: defaultColors.mTertiary
  property color mOnTertiary: defaultColors.mOnTertiary
  property color mTertiaryContainer: defaultColors.mTertiaryContainer
  property color mOnTertiaryContainer: defaultColors.mOnTertiaryContainer

  // -- Error --
  property color mError: defaultColors.mError
  property color mOnError: defaultColors.mOnError
  property color mErrorContainer: defaultColors.mErrorContainer
  property color mOnErrorContainer: defaultColors.mOnErrorContainer

  // === SURFACE & BACKGROUND ===

  // -- Surface --
  property color mSurface: defaultColors.mSurface
  property color mOnSurface: defaultColors.mOnSurface
  property color mSurfaceVariant: defaultColors.mSurfaceVariant
  property color mOnSurfaceVariant: defaultColors.mOnSurfaceVariant
  property color mSurfaceContainerLow: defaultColors.mSurfaceContainerLow
  property color mSurfaceContainer: defaultColors.mSurfaceContainer
  property color mSurfaceContainerHigh: defaultColors.mSurfaceContainerHigh

  // -- Background --
  property color mBackground: defaultColors.mBackground
  property color mOnBackground: defaultColors.mOnBackground

  // === OUTLINE ===
  property color mOutline: defaultColors.mOutline
  property color mOutlineVariant: defaultColors.mOutlineVariant

  // === DECORATIVE (no saturation control) ===
  property color mShadow: defaultColors.mShadow
  property color mHover: defaultColors.mHover
  property color mOnHover: defaultColors.mOnHover

  // === Behavior: Color Transition Animations (all 30 tokens) ===
  Behavior on mPrimary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnPrimary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mPrimaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnPrimaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSecondary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSecondary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSecondaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSecondaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mTertiary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnTertiary {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mTertiaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnTertiaryContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mError {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnError {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mErrorContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnErrorContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurface {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSurface {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurfaceVariant {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnSurfaceVariant {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurfaceContainerLow {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurfaceContainer {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mSurfaceContainerHigh {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mBackground {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnBackground {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOutline {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOutlineVariant {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mShadow {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mHover {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }
  Behavior on mOnHover {
    enabled: !root.skipTransition
    ColorAnimation {
      duration: Style.animationSlowest
      easing.type: Easing.OutCubic
    }
  }

  /** Flag the beginning of a color transition animation.
  *  Sets isTransitioning = true, then clears it after Style.animationSlowest + 50ms.
  *  Consumers use this to coordinate their own animations during scheme switches. */
  function startTransition() // Begin color transition animation window
  {
    root.isTransitioning = true;
    transitionTimer.restart();
  }

  // -- Saturation-Aware Color Update Internals --

  /** Apply saturation from ColorSaturation then assign to the root property.
  *  @param token - Token name like "mPrimary"
  *  @param maybeRaw - Optional raw color override; defaults to customColorsData[token]
  *  Triggers a transition animation if not in skipTransition mode. */
  function _refreshToken(token, maybeRaw) // Saturate and set a single token
  {
    const raw = maybeRaw !== undefined ? maybeRaw : customColorsData[token];
    if (raw === undefined)
      return;

    if (!root.skipTransition)
      startTransition();
    root[token] = ColorSaturation.apply(token, raw);
  }

  /** Refresh all tokens within a semantic slot.
  *  Called when any ColorSaturation per-slot value changes (e.g. saturationPrimary slider moved).
  *  @param slot - Slot name like "primary", "surface", etc. */
  function _refreshSlot(slot) // Refresh all tokens in a saturation slot
  {
    const tokens = ColorSaturation.slotTokens[slot];
    if (!tokens)
      return;
    for (let i = 0; i < tokens.length; i++) {
      _refreshToken(tokens[i]);
    }
  }

  // === Connections: customColorsData changes → apply saturation and set property ===
  Connections {
    target: customColorsData

    function onMPrimaryChanged() {
      _refreshToken("mPrimary");
    }
    function onMOnPrimaryChanged() {
      _refreshToken("mOnPrimary");
    }
    function onMPrimaryContainerChanged() {
      _refreshToken("mPrimaryContainer");
    }
    function onMOnPrimaryContainerChanged() {
      _refreshToken("mOnPrimaryContainer");
    }

    function onMSecondaryChanged() {
      _refreshToken("mSecondary");
    }
    function onMOnSecondaryChanged() {
      _refreshToken("mOnSecondary");
    }
    function onMSecondaryContainerChanged() {
      _refreshToken("mSecondaryContainer");
    }
    function onMOnSecondaryContainerChanged() {
      _refreshToken("mOnSecondaryContainer");
    }

    function onMTertiaryChanged() {
      _refreshToken("mTertiary");
    }
    function onMOnTertiaryChanged() {
      _refreshToken("mOnTertiary");
    }
    function onMTertiaryContainerChanged() {
      _refreshToken("mTertiaryContainer");
    }
    function onMOnTertiaryContainerChanged() {
      _refreshToken("mOnTertiaryContainer");
    }

    function onMErrorChanged() {
      _refreshToken("mError");
    }
    function onMOnErrorChanged() {
      _refreshToken("mOnError");
    }
    function onMErrorContainerChanged() {
      _refreshToken("mErrorContainer");
    }
    function onMOnErrorContainerChanged() {
      _refreshToken("mOnErrorContainer");
    }

    function onMSurfaceChanged() {
      _refreshToken("mSurface");
    }
    function onMOnSurfaceChanged() {
      _refreshToken("mOnSurface");
    }
    function onMSurfaceVariantChanged() {
      _refreshToken("mSurfaceVariant");
    }
    function onMOnSurfaceVariantChanged() {
      _refreshToken("mOnSurfaceVariant");
    }
    function onMSurfaceContainerLowChanged() {
      _refreshToken("mSurfaceContainerLow");
    }
    function onMSurfaceContainerChanged() {
      _refreshToken("mSurfaceContainer");
    }
    function onMSurfaceContainerHighChanged() {
      _refreshToken("mSurfaceContainerHigh");
    }

    function onMBackgroundChanged() {
      _refreshToken("mBackground");
    }
    function onMOnBackgroundChanged() {
      _refreshToken("mOnBackground");
    }

    function onMOutlineChanged() {
      _refreshToken("mOutline");
    }
    function onMOutlineVariantChanged() {
      _refreshToken("mOutlineVariant");
    }

    function onMShadowChanged() {
      _refreshToken("mShadow");
    }
    function onMHoverChanged() {
      _refreshToken("mHover");
    }
    function onMOnHoverChanged() {
      _refreshToken("mOnHover");
    }
  }

  // === Connections: ColorSaturation changes → refresh affected tokens ===
  Connections {
    target: ColorSaturation
    function onSaturationPrimaryChanged() {
      _refreshSlot("primary");
    }
    function onSaturationSecondaryChanged() {
      _refreshSlot("secondary");
    }
    function onSaturationTertiaryChanged() {
      _refreshSlot("tertiary");
    }
    function onSaturationErrorChanged() {
      _refreshSlot("error");
    }
    function onSaturationSurfaceChanged() {
      _refreshSlot("surface");
    }
    function onSaturationBackgroundChanged() {
      _refreshSlot("background");
    }
    function onSaturationOutlineChanged() {
      _refreshSlot("outline");
    }
  }

  // === Public: Color Resolution Helpers ===

  /** Resolve a semantic slot key to its main color.
  *  Falls back to mOnSurface (text color) for unknown keys so UI elements never get "transparent".
  *  @param key - "primary", "secondary", "tertiary", or "error"
  *  @returns The resolved color */
  function resolveColorKey(key) // Map slot key → main accent color
  {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      return root.mOnSurface;
    }
  }

  /** Resolve a semantic slot key to its "on" (text/icon) color.
  *  Falls back to mSurface for unknown keys.
  *  @param key - "primary", "secondary", "tertiary", or "error"
  *  @returns The resolved "on" color */
  function resolveOnColorKey(key) // Map slot key → on-color for text/icons
  {
    switch (key) {
    case "primary":
      return root.mOnPrimary;
    case "secondary":
      return root.mOnSecondary;
    case "tertiary":
      return root.mOnTertiary;
    case "error":
      return root.mOnError;
    default:
      return root.mSurface;
    }
  }

  /** Resolve a slot key to its main color, returning "transparent" for unknown keys.
  *  Used in contexts where an invisible default is safer than a visible fallback.
  *  @param key - "primary", "secondary", "tertiary", or "error"
  *  @returns The resolved color or "transparent" */
  function resolveColorKeyOptional(key) // Map slot key → color, unknown → transparent
  {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      return "transparent";
    }
  }

  // -- Opacity Helpers --

  /** Adjust base opacity for dark/light mode.
  *  In performance mode, always returns 1.0 (no translucency).
  *  In light mode, the opacity curve is raised by 1.5× to compensate for
  *  lighter backgrounds where translucency is less visible.
  *  @param baseOpacity - Original opacity value (0.0-1.0)
  *  @returns Adjusted opacity */
  function adaptiveOpacity(baseOpacity) // Dark/light-aware opacity
  {
    if (PowerProfileService.profile === PowerProfile.Performance)
      return 1.0;
    return Settings.data.colorSchemes.darkMode ? baseOpacity : Math.pow(baseOpacity, 1.5);
  }

  /** Apply translucent effect to a color.
  *  Gated by performance mode and translucentWidgets toggle.
  *  Subtracts the difference between desired and base alpha from the existing alpha.
  *  @param baseColor - The color to make translucent
  *  @param minAlpha - Minimum alpha floor (default 0.4)
  *  @returns Adjusted color */
  function smartAlpha(baseColor, minAlpha = 0.4) // Apply translucency-aware alpha
  {
    if (PowerProfileService.profile === PowerProfile.Performance)
      return baseColor;

    if (!Settings.data.ui.translucentWidgets)
      return baseColor;

    let alpha = Math.max(adaptiveOpacity(Settings.data.ui.panelBackgroundOpacity), minAlpha);

    // Shrink color's alpha by the inverse of the panel opacity
    // so final blended result lands at the desired panel opacity
    let resultAlpha = Math.max(0, baseColor.a - (1.0 - alpha));
    return Qt.alpha(baseColor, resultAlpha);
  }

  readonly property var colorKeyModel: [
    {
      "key": "none",
      "name": "None"
    },
    {
      "key": "primary",
      "name": "Primary"
    },
    {
      "key": "secondary",
      "name": "Secondary"
    },
    {
      "key": "tertiary",
      "name": "Tertiary"
    },
    {
      "key": "error",
      "name": "Error"
    }
  ]

  // === Default Colors: Mordial (default) Dark ===
  /** Fallback palette used when no colors.json exists yet.
  *  All 30 tokens initialized here so the shell has a valid visual state
  *  before any scheme is loaded. Matches the "Mordial (default)" scheme. */
  QtObject {
    id: defaultColors

    readonly property color mPrimary: "#fff59b"
    readonly property color mOnPrimary: "#0e0e43"
    readonly property color mPrimaryContainer: "#3a3520"
    readonly property color mOnPrimaryContainer: "#fff59b"

    readonly property color mSecondary: "#a9aefe"
    readonly property color mOnSecondary: "#0e0e43"
    readonly property color mSecondaryContainer: "#20203a"
    readonly property color mOnSecondaryContainer: "#a9aefe"

    readonly property color mTertiary: "#9BFECE"
    readonly property color mOnTertiary: "#0e0e43"
    readonly property color mTertiaryContainer: "#203a20"
    readonly property color mOnTertiaryContainer: "#9BFECE"

    readonly property color mError: "#FD4663"
    readonly property color mOnError: "#0e0e43"
    readonly property color mErrorContainer: "#3a2020"
    readonly property color mOnErrorContainer: "#FD4663"

    readonly property color mSurface: "#070722"
    readonly property color mOnSurface: "#f3edf7"
    readonly property color mSurfaceVariant: "#11112d"
    readonly property color mOnSurfaceVariant: "#7c80b4"
    readonly property color mSurfaceContainerLow: "#0a0a2a"
    readonly property color mSurfaceContainer: "#11112d"
    readonly property color mSurfaceContainerHigh: "#181840"

    readonly property color mBackground: "#070722"
    readonly property color mOnBackground: "#f3edf7"

    readonly property color mOutline: "#21215F"
    readonly property color mOutlineVariant: "#3a3a6a"

    readonly property color mShadow: "#070722"
    readonly property color mHover: "#9BFECE"
    readonly property color mOnHover: "#0e0e43"
  }

  // === File I/O: Custom Colors from colors.json ===

  /** Reads colors.json from disk via a JsonAdapter.
  *  Watches for external changes (atomic file swaps from wallpaper pipelines)
  *  and debounces reloads to avoid rapid re-evaluation. */
  FileView {
    id: customColorsFile
    path: Settings.directoriesCreated ? (Settings.configDir + "colors.json") : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalColorReload()
    onAdapterUpdated: {
      Logger.d("Color", "Writing colors to disk");
      writeAdapter();
    }

    onLoaded: {
      if (root.skipTransition) {
        Qt.callLater(function () {
          root.skipTransition = false;
        });
      }
    }

    onPathChanged: {
      if (path !== undefined) {
        reload();
      }
    }
    onLoadFailed: function (error) {
      // Suppress retry debounce for programmatic reloads
      if (reloadColors) {
        reloadColors = false;
        return;
      }

      if (root.skipTransition) {
        Qt.callLater(function () {
          root.skipTransition = false;
        });
      }

      // On "file not found", write defaults so colors.json exists for next launch
      if (error === 2 || error.toString().includes("No such file")) {
        writeAdapter();
      }
    }

    /** In-memory representation of colors.json.
    *  All 30 tokens default to the fallback palette so the shell is always
    *  in a valid visual state, even on first launch with no colors.json. */
    JsonAdapter {
      id: customColorsData

      // Original 16 tokens (pre-color-revamp)
      property color mPrimary: defaultColors.mPrimary
      property color mOnPrimary: defaultColors.mOnPrimary
      property color mSecondary: defaultColors.mSecondary
      property color mOnSecondary: defaultColors.mOnSecondary
      property color mTertiary: defaultColors.mTertiary
      property color mOnTertiary: defaultColors.mOnTertiary
      property color mError: defaultColors.mError
      property color mOnError: defaultColors.mOnError
      property color mSurface: defaultColors.mSurface
      property color mOnSurface: defaultColors.mOnSurface
      property color mSurfaceVariant: defaultColors.mSurfaceVariant
      property color mOnSurfaceVariant: defaultColors.mOnSurfaceVariant
      property color mOutline: defaultColors.mOutline
      property color mShadow: defaultColors.mShadow
      property color mHover: defaultColors.mHover
      property color mOnHover: defaultColors.mOnHover

      // New tokens (14 added in color revamp — containers, background, surface levels)
      property color mPrimaryContainer: defaultColors.mPrimaryContainer
      property color mOnPrimaryContainer: defaultColors.mOnPrimaryContainer
      property color mSecondaryContainer: defaultColors.mSecondaryContainer
      property color mOnSecondaryContainer: defaultColors.mOnSecondaryContainer
      property color mTertiaryContainer: defaultColors.mTertiaryContainer
      property color mOnTertiaryContainer: defaultColors.mOnTertiaryContainer
      property color mErrorContainer: defaultColors.mErrorContainer
      property color mOnErrorContainer: defaultColors.mOnErrorContainer
      property color mSurfaceContainerLow: defaultColors.mSurfaceContainerLow
      property color mSurfaceContainer: defaultColors.mSurfaceContainer
      property color mSurfaceContainerHigh: defaultColors.mSurfaceContainerHigh
      property color mBackground: defaultColors.mBackground
      property color mOnBackground: defaultColors.mOnBackground
      property color mOutlineVariant: defaultColors.mOutlineVariant
    }
  }

  // -- Directory Watcher Fallback --
  /** Watches the config directory for file-level changes.
  *  Some editors / scripts swap files atomically at the directory level,
  *  which the file watcher above might miss without this fallback. */
  FileView {
    id: colorsDirWatcher
    path: Settings.directoriesCreated ? Settings.configDir : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalColorReload()
  }
}
