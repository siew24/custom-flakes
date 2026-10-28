{
  description = "Personal dev shells and packages. Enter a shell with `nix develop custom#<name>`.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/release-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # One file per shell in ./shells. Each takes { pkgs } and returns the
      # shell plus any helper packages it needs.
      aria2 = import ./shells/aria2.nix { inherit pkgs; };
      csharp = import ./shells/csharp.nix { inherit nixpkgs system; };
      godot = import ./shells/godot.nix { inherit pkgs; };
    in
    {
      devShells.${system} = {
        aria2 = aria2.shell;
        inherit csharp godot;
      };

      packages.${system} = {
        aria2-fw-guard = aria2.guard;
        # Newer than the release-26.05 one; my system flake overlays it in.
        hydralauncher = pkgs.callPackage ./packages/hydralauncher.nix { };
      };
    };
}
