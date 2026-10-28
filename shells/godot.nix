# Godot 4.7 editor. Launch it from inside the shell with `godot`.
{ pkgs }:
pkgs.mkShell {
  packages = [ pkgs.godotPackages_4_7.godot ];
}
