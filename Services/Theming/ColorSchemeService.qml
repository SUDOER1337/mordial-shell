// File: Services/Theming/ColorSchemeService.qml
// =============================================================================
// Color scheme management — loading, resolving, and applying predefined schemes.
// Coordinates between:
//   - File system (scheme JSON files in Assets/ColorScheme and ~/.config/mordial/colorschemes/)
//   - Color.qml (30 color tokens consumed by the UI)
//   - WallpaperService (wallpaper-derived colors)
//   - AppThemeService (template generation for GTK, terminals, etc.)
//
// Functions:
//   init()                          - Initialize the service, load scheme list
//   loadColorSchemes()              - Scan for scheme JSON files via `find`
//   getBasename(path)               - Extract display name from a scheme file path
//   resolveSchemePath(nameOrPath)   - Convert display name to full file path
//   applyScheme(nameOrPath)         - Load and apply a scheme from disk
//   setPredefinedScheme(schemeName) - Set a scheme by name, with existence check
//   writeColorsToDisk(obj)          - Write parsed scheme to colors.json
//   hasEnabledTemplates()           - Check if any app templates are active
//   pushSystemColorScheme()         - Sync dark/light mode to GTK (appearance-only)
//
// Properties:
//   schemes                      - List of discovered scheme file paths
//   scanning                     - True while scheme discovery is in progress
//   schemesDirectory             - Path to preinstalled schemes
//   downloadedSchemesDirectory   - Path to user-downloaded schemes
//   colorsJsonFilePath           - Path to the active colors.json
//   lastPredefinedSchemeData     - Cache of the last fully-parsed scheme JSON
//   gtkRefreshScript             - Path to the GTK refresh Python script
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Helpers/ColorsConvert.js" as CC
import qs.Commons
import qs.Services.Theming
import qs.Services.UI

Singleton {
  id: root

  // === State ===
  property var schemes: []
  property bool scanning: false

  // === Paths ===
  property string schemesDirectory: Quickshell.shellDir + "/Assets/ColorScheme"
  property string downloadedSchemesDirectory: Settings.configDir + "colorschemes"
  property string colorsJsonFilePath: Settings.configDir + "colors.json"
  /** Cached full JSON of the last successfully loaded predefined scheme.
  *  Used to regenerate app templates on wallpaper changes without re-running
  *  applyScheme (avoids rewriting colors.json when only the wallpaper changed). */
  property var lastPredefinedSchemeData: null
  readonly property string gtkRefreshScript: Quickshell.shellDir + "/Scripts/python/src/theming/gtk-refresh.py"

  // -- GTK Color Scheme Sync --

  /** Push the current dark/light mode preference to the system GTK theme.
  *  Only sets "prefer-light"/"prefer-dark" — full template-based GTK theming
  *  is handled separately via TemplateProcessor.
  *  Skips if syncGsettings is off or a GTK template is already active. */
  function pushSystemColorScheme() // Sync dark/light mode to GTK
  {
    if (!Settings.data.colorSchemes.syncGsettings)
      return;
    if (TemplateProcessor.isTemplateEnabled("gtk"))
      return;
    const mode = Settings.data.colorSchemes.darkMode ? "dark" : "light";
    Quickshell.execDetached(["python3", gtkRefreshScript, "--appearance-only", mode]);
  }

  // -- Dark Mode Change Handler --
  Connections {
    target: Settings.data.colorSchemes
    function onDarkModeChanged() {
      Logger.d("ColorScheme", "Detected dark mode change");
      if (!Settings.data.colorSchemes.useWallpaperColors && Settings.data.colorSchemes.predefinedScheme) {
        // Re-apply current scheme to pick the right variant (dark/light)
        applyScheme(Settings.data.colorSchemes.predefinedScheme);
      }
      root.pushSystemColorScheme();
      // Toast: dark/light mode switched
      const enabled = !!Settings.data.colorSchemes.darkMode;
      const label = enabled ? "Dark Mode" : "Light Mode";
      const description = "Enabled";
      ToastService.showNotice(label, description, "dark-mode");
    }
  }

  // === Initialization ===

  /** Initialize the ColorSchemeService.
  *  Must be called once at shell startup to kick off scheme discovery.
  *  The Logger.i call also ensures the singleton is instantiated. */
  function init() // Start the service and load schemes
  {
    Logger.i("ColorScheme", "Service started");
    loadColorSchemes();
  }

  // === Scheme Discovery ===

  /** Scan filesystem for color scheme JSON files.
  *  Searches both the preinstalled directory and the user-downloaded directory.
  *  Uses a `find` subprocess to handle nested directory structures. */
  function loadColorSchemes() // Find all scheme JSON files
  {
    Logger.d("ColorScheme", "Load colorScheme");
    scanning = true;
    schemes = [];
    // Ensure the downloaded schemes directory exists before searching it
    Quickshell.execDetached(["mkdir", "-p", downloadedSchemesDirectory]);
    // Find in both preinstalled and downloaded directories, ignoring missing dirs
    findProcess.command = ["sh", "-c", "find -L '" + schemesDirectory + "' '" + downloadedSchemesDirectory + "' -mindepth 2 -name '*.json' -type f 2>/dev/null || true"];
    findProcess.running = true;
  }

  // -- Path Helpers --

  /** Extract a human-readable display name from a scheme file path.
  *  Converts file-format names (e.g. "Agnoctural-default") back to
  *  display names (e.g. "Agnoctural (default)").
  *  @param path - Full or partial scheme file path
  *  @returns Display name string */
  function getBasename(path) // Get display name from scheme path
  {
    if (!path)
      return "";
    var chunks = path.split("/");
    var filename = chunks[chunks.length - 1];
    var schemeName = filename.replace(".json", "");
    // Map file-safe names back to display-friendly names
    if (schemeName === "Mordial-default") {
      return "Mordial (default)";
    } else if (schemeName === "Mordial-legacy") {
      return "Mordial (legacy)";
    } else if (schemeName === "Tokyo-Night") {
      return "Tokyo Night";
    } else if (schemeName === "Rosepine") {
      return "Rose Pine";
    }
    return schemeName;
  }

  /** Resolve a scheme name or partial path to a full filesystem path.
  *  Handles display-name-to-filename conversion (e.g. "Tokyo Night" → "Tokyo-Night").
  *  Searches the loaded schemes list first, then falls back to directory convention.
  *  @param nameOrPath - Display name, file name, or full path
  *  @returns Full path to the scheme JSON file */
  function resolveSchemePath(nameOrPath) // Resolve scheme name to file path
  {
    if (!nameOrPath)
      return "";
    if (nameOrPath.indexOf("/") !== -1) {
      return nameOrPath;
    }
    var schemeName = nameOrPath.replace(".json", "");
    // Convert display names to file-safe directory names
    if (schemeName === "Mordial (default)") {
      schemeName = "Mordial-default";
    } else if (schemeName === "Mordial (legacy)") {
      schemeName = "Mordial-legacy";
    } else if (schemeName === "Tokyo Night") {
      schemeName = "Tokyo-Night";
    } else if (schemeName === "Rose Pine") {
      schemeName = "Rosepine";
    }
    var preinstalledPath = schemesDirectory + "/" + schemeName + "/" + schemeName + ".json";
    var downloadedPath = downloadedSchemesDirectory + "/" + schemeName + "/" + schemeName + ".json";
    // Search loaded schemes for a match to determine which directory it's in
    for (var i = 0; i < schemes.length; i++) {
      if (schemes[i].indexOf("/" + schemeName + "/") !== -1 || schemes[i].indexOf("/" + schemeName + ".json") !== -1) {
        return schemes[i];
      }
    }
    // Fallback: prefer preinstalled over downloaded
    return preinstalledPath;
  }

  // === Scheme Application ===

  /** Load and apply a color scheme from a JSON file.
  *  Bounces path to force a re-read even if the same scheme is selected. */
  function applyScheme(nameOrPath) // Load and apply a scheme from disk
  {
    var filePath = resolveSchemePath(nameOrPath);
    schemeReader.path = "";
    schemeReader.path = filePath;
  }

  /** Set a predefined scheme by display name, with existence validation.
  *  Shows a toast on success/error.
  *  @param schemeName - Display name of the scheme */
  function setPredefinedScheme(schemeName) // Set and apply a named scheme
  {
    Logger.i("ColorScheme", "Attempting to set predefined scheme to:", schemeName);

    var resolvedPath = resolveSchemePath(schemeName);
    var basename = getBasename(schemeName);

    // Verify the scheme actually exists in the loaded schemes list
    var schemeExists = false;
    for (var i = 0; i < schemes.length; i++) {
      if (getBasename(schemes[i]) === basename) {
        schemeExists = true;
        break;
      }
    }

    if (schemeExists) {
      Settings.data.colorSchemes.predefinedScheme = basename;
      applyScheme(schemeName);
      ToastService.showNotice("Color Scheme", basename, "settings-color-scheme");
    } else {
      Logger.e("ColorScheme", "Scheme not found:", schemeName);
      ToastService.showError("Color Scheme", `'${basename}' ` + "Not found");
    }
  }

  // -- Scheme File Discovery Process --

  /** Subprocess that runs `find` to discover scheme JSON files.
  *  On success, sorts the results alphabetically, updates `schemes`,
  *  normalizes the stored scheme name, and re-applies if needed. */
  Process {
    id: findProcess
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        var output = stdout.text.trim();
        var files = output.split('\n').filter(function (line) {
          return line.length > 0;
        });
        files.sort(function (a, b) {
          var nameA = getBasename(a).toLowerCase();
          var nameB = getBasename(b).toLowerCase();
          return nameA.localeCompare(nameB);
        });
        schemes = files;
        scanning = false;
        Logger.d("ColorScheme", "Listed", schemes.length, "schemes");
        // Normalize stored scheme name from e.g. display-name to basename
        var stored = Settings.data.colorSchemes.predefinedScheme;
        if (stored) {
          var basename = getBasename(stored);
          if (basename !== stored) {
            Settings.data.colorSchemes.predefinedScheme = basename;
          }
          if (!Settings.data.colorSchemes.useWallpaperColors) {
            applyScheme(basename);
          }
        }
      } else {
        Logger.e("ColorScheme", "Failed to find color scheme files");
        schemes = [];
        scanning = false;
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // -- Scheme JSON Reader --

  /** Reads a scheme JSON file and applies it.
  *  Supports both flat scheme objects and dark/light variant structures.
  *  Delegates to writeColorsToDisk() and triggers template generation. */
  FileView {
    id: schemeReader
    onLoaded: {
      try {
        var data = JSON.parse(text());
        var variant = data;
        // If the scheme file has dark/light variants, select the active one
        if (data && (data.dark || data.light)) {
          if (Settings.data.colorSchemes.darkMode) {
            variant = data.dark || data.light;
          } else {
            variant = data.light || data.dark;
          }
        }
        writeColorsToDisk(variant);
        lastPredefinedSchemeData = data;
        Logger.i("ColorScheme", "Applying color scheme:", getBasename(path));

        // Generate app templates (GTK, terminals, etc.) from predefined scheme data
        if (hasEnabledTemplates() || Settings.data.templates.enableUserTheming) {
          AppThemeService.generateFromPredefinedScheme(data);
        }
      } catch (e) {
        Logger.e("ColorScheme", "Failed to parse scheme JSON:", path, e);
      }
    }
  }

  /** Check if any app templates (GTK, terminals, etc.) are currently enabled.
  *  @returns true if at least one active template is enabled */
  function hasEnabledTemplates() // Check if any app templates are active
  {
    const activeTemplates = Settings.data.templates.activeTemplates;
    if (!activeTemplates || activeTemplates.length === 0) {
      return false;
    }
    for (let i = 0; i < activeTemplates.length; i++) {
      if (activeTemplates[i].enabled) {
        return true;
      }
    }
    return false;
  }

  // -- Colors JSON Writer --

  /** Writes parsed scheme colors to colors.json.
  *  The `out` JsonAdapter defaults are now initialized from the real fallback
  *  palette (matching Color.qml's defaultColors), so when an old-format scheme
  *  file is loaded, every token has a valid visual default instead of #000000. */
  FileView {
    id: colorsWriter
    path: colorsJsonFilePath
    printErrors: false
    onSaved:

    // Logger.i("ColorScheme", "Colors saved")
    {}
    JsonAdapter {
      id: out
      // Defaults match Color.qml's defaultColors block so that fallback
      // values are visually valid even when a scheme file lacks certain tokens.
      property color mPrimary: "#fff59b"
      property color mOnPrimary: "#0e0e43"
      property color mPrimaryContainer: "#3a3520"
      property color mOnPrimaryContainer: "#fff59b"

      property color mSecondary: "#a9aefe"
      property color mOnSecondary: "#0e0e43"
      property color mSecondaryContainer: "#20203a"
      property color mOnSecondaryContainer: "#a9aefe"

      property color mTertiary: "#9BFECE"
      property color mOnTertiary: "#0e0e43"
      property color mTertiaryContainer: "#203a20"
      property color mOnTertiaryContainer: "#9BFECE"

      property color mError: "#FD4663"
      property color mOnError: "#0e0e43"
      property color mErrorContainer: "#3a2020"
      property color mOnErrorContainer: "#FD4663"

      property color mSurface: "#070722"
      property color mOnSurface: "#f3edf7"
      property color mSurfaceVariant: "#11112d"
      property color mOnSurfaceVariant: "#7c80b4"
      property color mSurfaceContainerLow: "#0a0a2a"
      property color mSurfaceContainer: "#11112d"
      property color mSurfaceContainerHigh: "#181840"

      property color mBackground: "#070722"
      property color mOnBackground: "#f3edf7"

      property color mOutline: "#21215F"
      property color mOutlineVariant: "#3a3a6a"

      property color mShadow: "#070722"
      property color mHover: "#9BFECE"
      property color mOnHover: "#0e0e43"
    }
  }

  /** Write a parsed scheme object to colors.json.
  *  Maps both full-format (mPrimary) and shorthand (primary) key names
  *  to the 30-token output adapter. For the 14 new MD3 tokens, derives
  *  them from the scheme's 16 existing tokens when they are not present,
  *  using MD3-appropriate formulas from ColorsConvert.js.
  *  @param obj - Parsed scheme JSON object (flat variant, not dark/light wrapper) */
  function writeColorsToDisk(obj) // Write scheme data to colors.json
  {
    function pick(o, a, b, fallback) {
      if (!o)
        return fallback;
      // Try mCamelCase (e.g., mPrimary) or camelCase (e.g., primary)
      if (o[a])
        return o[a];
      if (o[b])
        return o[b];
      // Auto-generate snake_case from camelCase (e.g., onPrimary → on_primary)
      var snake = b.replace(/([A-Z])/g, '_$1').toLowerCase();
      if (o[snake])
        return o[snake];
      return fallback;
    }
    const isDark = Settings.data.colorSchemes.darkMode;
    out.mPrimary = pick(obj, "mPrimary", "primary", out.mPrimary);
    out.mOnPrimary = pick(obj, "mOnPrimary", "onPrimary", out.mOnPrimary);
    out.mSecondary = pick(obj, "mSecondary", "secondary", out.mSecondary);
    out.mOnSecondary = pick(obj, "mOnSecondary", "onSecondary", out.mOnSecondary);
    out.mTertiary = pick(obj, "mTertiary", "tertiary", out.mTertiary);
    out.mOnTertiary = pick(obj, "mOnTertiary", "onTertiary", out.mOnTertiary);
    out.mError = pick(obj, "mError", "error", out.mError);
    out.mOnError = pick(obj, "mOnError", "onError", out.mOnError);
    out.mSurface = pick(obj, "mSurface", "surface", out.mSurface);
    out.mOnSurface = pick(obj, "mOnSurface", "onSurface", out.mOnSurface);
    out.mSurfaceVariant = pick(obj, "mSurfaceVariant", "surfaceVariant", out.mSurfaceVariant);
    out.mOnSurfaceVariant = pick(obj, "mOnSurfaceVariant", "onSurfaceVariant", out.mOnSurfaceVariant);
    out.mOutline = pick(obj, "mOutline", "outline", out.mOutline);
    out.mShadow = pick(obj, "mShadow", "shadow", out.mShadow);
    out.mHover = pick(obj, "mHover", "hover", out.mHover);
    out.mOnHover = pick(obj, "mOnHover", "onHover", out.mOnHover);

    // 14 MD3 tokens — derived from scheme's own 16 tokens when missing
    out.mBackground = pick(obj, "mBackground", "background", obj.mSurface || out.mSurface);
    out.mOnBackground = pick(obj, "mOnBackground", "onBackground", obj.mOnSurface || out.mOnSurface);
    out.mPrimaryContainer = pick(obj, "mPrimaryContainer", "primaryContainer", CC.generateContainerColor(obj.mPrimary || out.mPrimary, isDark));
    out.mOnPrimaryContainer = pick(obj, "mOnPrimaryContainer", "onPrimaryContainer", obj.mPrimary || out.mPrimary);
    out.mSecondaryContainer = pick(obj, "mSecondaryContainer", "secondaryContainer", CC.generateContainerColor(obj.mSecondary || out.mSecondary, isDark));
    out.mOnSecondaryContainer = pick(obj, "mOnSecondaryContainer", "onSecondaryContainer", obj.mSecondary || out.mSecondary);
    out.mTertiaryContainer = pick(obj, "mTertiaryContainer", "tertiaryContainer", CC.generateContainerColor(obj.mTertiary || out.mTertiary, isDark));
    out.mOnTertiaryContainer = pick(obj, "mOnTertiaryContainer", "onTertiaryContainer", obj.mTertiary || out.mTertiary);
    out.mErrorContainer = pick(obj, "mErrorContainer", "errorContainer", CC.generateContainerColor(obj.mError || out.mError, isDark));
    out.mOnErrorContainer = pick(obj, "mOnErrorContainer", "onErrorContainer", obj.mError || out.mError);
    out.mSurfaceContainerLow = pick(obj, "mSurfaceContainerLow", "surfaceContainerLow", CC.generateSurfaceVariant(obj.mSurface || out.mSurface, 1, isDark));
    out.mSurfaceContainer = pick(obj, "mSurfaceContainer", "surfaceContainer", obj.mSurfaceVariant || CC.generateSurfaceVariant(obj.mSurface || out.mSurface, 2, isDark));
    out.mSurfaceContainerHigh = pick(obj, "mSurfaceContainerHigh", "surfaceContainerHigh", CC.generateSurfaceVariant(obj.mSurface || out.mSurface, 3, isDark));
    out.mOutlineVariant = pick(obj, "mOutlineVariant", "outlineVariant", CC.adjustLightnessAndSaturation(obj.mOutline || out.mOutline, isDark ? 10 : -10, isDark ? -10 : 10));

    // Bounce path to force FileView to re-detect the change and rewrite
    colorsWriter.path = "";
    colorsWriter.path = colorsJsonFilePath;
    colorsWriter.writeAdapter();
  }
}
