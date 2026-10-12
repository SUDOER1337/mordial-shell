{ config, lib, ... }:

{
  options.services.mordial-shell = {
    enable = lib.mkEnableOption "mordial-shell";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The mordial-shell package to use";
    };
  };

  config = lib.mkIf config.services.mordial-shell.enable {
    environment.systemPackages = [ config.services.mordial-shell.package ];
  };
}
