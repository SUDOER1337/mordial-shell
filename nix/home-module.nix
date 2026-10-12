{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.mordial-shell;
  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };

  generateJson =
    name: value:
    if lib.isString value then
      pkgs.writeText "mordial-${name}.json" value
    else if builtins.isPath value || lib.isStorePath value then
      value
    else
      jsonFormat.generate "mordial-${name}.json" value;
in
{
  options.programs.mordial-shell = {
    enable = lib.mkEnableOption "Mordial shell configuration";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "The mordial-shell package to use";
    };

    settings = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
        {
          bar = {
            position = "bottom";
            floating = true;
            backgroundOpacity = 0.95;
          };
          general = {
            animationSpeed = 1.5;
            radiusRatio = 1.2;
          };
          colorSchemes = {
            darkMode = true;
            useWallpaperColors = true;
          };
        }
      '';
      description = ''
        Mordial shell configuration settings as an attribute set, string
        or filepath, to be written to ~/.config/mordial/settings.json.
      '';
    };

    colors = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
         {
           mError = "#dddddd";
           mOnError = "#111111";
           mOnPrimary = "#111111";
           mOnSecondary = "#111111";
           mOnSurface = "#828282";
           mOnSurfaceVariant = "#5d5d5d";
           mOnTertiary = "#111111";
           mOutline = "#3c3c3c";
           mPrimary = "#aaaaaa";
           mSecondary = "#a7a7a7";
           mShadow = "#000000";
           mSurface = "#111111";
           mSurfaceVariant = "#191919";
           mTertiary = "#cccccc";
        }
      '';
      description = ''
        Mordial shell color configuration as an attribute set, string
        or filepath, to be written to ~/.config/mordial/colors.json.
      '';
    };

    user-templates = lib.mkOption {
      default = { };
      type =
        with lib.types;
        oneOf [
          tomlFormat.type
          str
          path
        ];
      example = lib.literalExpression ''
        {
          templates = {
            neovim = {
              input_path = "~/.config/mordial/templates/template.lua";
              output_path = "~/.config/nvim/generated.lua";
              post_hook = "pkill -SIGUSR1 nvim";
            };
          };
        }
      '';
      description = ''
        Template definitions for Mordial, to be written to ~/.config/mordial/user-templates.toml.

        This option accepts:
        - a Nix attrset (converted to TOML automatically)
        - a string containing raw TOML
        - a path to an existing TOML file
      '';
    };

    plugins = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
        {
          sources = [
            {
              enabled = true;
              name = "Mordial Plugins";
              url = "https://github.com/noctalia-dev/noctalia-plugins";
            }
          ];
          states = {
            catwalk = {
              enabled = true;
              sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
            };
          };
          version = 2;
        }
      '';
      description = ''
        Mordial shell plugin configuration as an attribute set, string
        or filepath, to be written to ~/.config/mordial/plugins.json.
      '';
    };

    pluginSettings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          jsonFormat.type
          str
          path
        ]);
      default = { };
      example = lib.literalExpression ''
        {
          catwalk = {
            minimumThreshold = 25;
            hideBackground = true;
          };
        }
      '';
description = ''
        Each plugin's settings as an attribute set, string
        or filepath, to be written to ~/.config/mordial/plugins/plugin-name/settings.json.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    xdg.configFile = {
      "mordial/settings.json" = lib.mkIf (cfg.settings != { }) {
        source = generateJson "settings" cfg.settings;
      };
      "mordial/colors.json" = lib.mkIf (cfg.colors != { }) {
        source = generateJson "colors" cfg.colors;
      };
      "mordial/plugins.json" = lib.mkIf (cfg.plugins != { }) {
        source = generateJson "plugins" cfg.plugins;
      };
      "mordial/user-templates.toml" = lib.mkIf (cfg.user-templates != { }) {
        source =
          if lib.isString cfg.user-templates then
            pkgs.writeText "mordial-user-templates.toml" cfg.user-templates
          else if builtins.isPath cfg.user-templates || lib.isStorePath cfg.user-templates then
            cfg.user-templates
          else
            tomlFormat.generate "mordial-user-templates.toml" cfg.user-templates;
      };
    }
    // lib.mapAttrs' (
      name: value:
      lib.nameValuePair "mordial/plugins/${name}/settings.json" {
        source = generateJson "${name}-settings" value;
      }
    ) cfg.pluginSettings;


  };
}
