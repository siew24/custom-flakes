{
  description = "Personal dev shells and packages. Enter a shell with `nix develop custom#<name>`.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/release-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # aria2 is a builder in ./lib shared by the shell, packages and modules.
      # The other shells are one file each in ./shells, taking { pkgs }.
      aria2 = import ./lib/aria2.nix { inherit pkgs; };
      csharp = import ./shells/csharp.nix { inherit nixpkgs system; };
      godot = import ./shells/godot.nix { inherit pkgs; };
    in
    {
      devShells.${system} = {
        aria2 = aria2.shell;
        inherit csharp godot;
      };

      homeManagerModules.default = ./modules/home-manager.nix;
      nixosModules.default = ./modules/nixos.nix;

      # Newer hydralauncher than release-26.05 has, built with the consumer's pkgs.
      overlays.default = final: prev: {
        hydralauncher = final.callPackage ./packages/hydralauncher.nix { };
      };

      packages.${system} = {
        aria2-fw-guard = aria2.guard;
        inherit (aria2) aria2c;
        # Newer than the release-26.05 one; the overlay above is the way to use it.
        hydralauncher = pkgs.callPackage ./packages/hydralauncher.nix { };
      };
    };
}
