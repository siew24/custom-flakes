# C# and .NET shell with Rider. Rider is unfree, and nixpkgs.legacyPackages
# does not inherit any allowUnfree setting, so this shell imports its own.
{ nixpkgs, system }:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in
pkgs.mkShell {
  packages = [
    pkgs.jetbrains.rider
    pkgs.dotnet-sdk
  ];
  DOTNET_ROOT = "${pkgs.dotnet-sdk}";
}
