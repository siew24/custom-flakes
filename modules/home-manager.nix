{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.aria2;
  # Built with the consumer's pkgs, not this flake's nixpkgs.
  aria2 = import ../lib/aria2.nix { inherit pkgs; inherit (cfg) downloadDir port; };
in
{
  imports = [ ./aria2-options.nix ];

  config = lib.mkIf cfg.enable {
    home.packages = [ aria2.aria2c ];
  };
}
