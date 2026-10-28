# Options shared by the home-manager and NixOS modules.
{ lib, ... }:
{
  options.custom.aria2 = {
    enable = lib.mkEnableOption "aria2c that opens the BitTorrent port only while it runs";

    downloadDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/mnt/data/Downloads";
      description = ''
        Where aria2c downloads to. When null it is resolved when aria2c runs:
        `$XDG_DOWNLOAD_DIR`, falling back to `~/Downloads`. A `-d` flag
        passed to aria2c overrides either.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 51413;
      description = "BitTorrent and DHT port, opened for TCP and UDP while aria2c runs.";
    };
  };
}
