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
    assertions = [
      {
        assertion = config.networking.firewall.enable && !config.networking.nftables.enable;
        message = "custom.aria2: the guard needs the iptables-based NixOS firewall (networking.firewall.enable = true and networking.nftables.enable = false).";
      }
    ];

    environment.systemPackages = [ aria2.aria2c ];
  };
}
