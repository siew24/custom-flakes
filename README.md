# custom-flakes

My own dev shells and packages, in one flake registered as `custom`.

    nix develop custom#aria2

Each shell is one file in `shells/`, wired up in `flake.nix`. Everything here
targets `x86_64-linux`.

Registry entry (per user, in `~/.config/nix/registry.json`):

    nix registry add custom github:siew24/custom-flakes

Or skip the registry and use the full reference:
`nix develop github:siew24/custom-flakes#aria2`.

## aria2

The BitTorrent and DHT port (51413, TCP and UDP) is open in the NixOS firewall
only while the shell is open.

    nix develop custom#aria2
    aria2c file.torrent
    exit                      # closes the port

One command also works: `nix develop custom#aria2 -c aria2c file.torrent`. The
port closes when aria2c ends.

Entering the shell shows one polkit prompt. If you cancel it, the shell exits
instead of pretending the port is open.

`aria2c` in the shell is a wrapper. It sets the listen ports, `--seed-time=0`
and `--file-allocation=falloc`, and downloads to `$ARIA2_BT_DIR`, falling back
to `$XDG_DOWNLOAD_DIR` and then `~/Downloads`. Extra flags win, so a later `-d`
overrides the folder.

How it works: the shell hook starts a root guard through pkexec. The guard
inserts four iptables rules (TCP and UDP, IPv4 and IPv6) into `nixos-fw`,
prints `ready`, then polls the shell's PID and deletes the rules when it
disappears. That covers `exit`, Ctrl-D, closing the terminal and SIGKILL.
Opening and closing are logged: `journalctl -t aria2-fw-guard`.

Limits:
- NixOS with the iptables firewall only. It calls `/run/wrappers/bin/pkexec`
  and `/run/current-system/sw/bin/iptables`.
- A rebuild that restarts `firewall.service` drops the rules mid-session.
  Leave and re-enter the shell.
- Two shells at once each add their own rules and each removes only its own,
  but both listen on the same port, so only one aria2 can bind it.
- pkexec refuses to run when `$SHELL` is not in `/etc/shells`, and `nix
  develop` sets it to a store bash. The hook overrides it for that one call.

## csharp

Rider and the .NET SDK, with `DOTNET_ROOT` set.

    nix develop custom#csharp

Rider is unfree, so the shell imports nixpkgs with `allowUnfree` itself. The
first entry downloads Rider and its JetBrains runtime.

## godot

The Godot 4.7 editor.

    nix develop custom#godot -c godot

There is no desktop entry, so launch it from a terminal.

## hydralauncher

Hydra Launcher pinned ahead of nixpkgs release-26.05, which is stuck on 3.9.5.
To use it in place of the nixpkgs one, take this flake as an input and overlay
it:

    nixpkgs.overlays = [
      (final: prev: { hydralauncher = custom.packages.${prev.system}.hydralauncher; })
    ];

To bump it, change `version` and `hash` in `packages/hydralauncher.nix`. Get the
hash with:

    nix store prefetch-file https://github.com/hydralauncher/hydra/releases/download/v<version>/hydralauncher-<version>.AppImage

A flake that takes this one as an input only sees the bump after a push and a
`nix flake update custom` on its side.
