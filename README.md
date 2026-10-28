# custom-flakes

My own dev shells and packages, in one flake registered as `custom`.

    nix develop custom#aria2

Shells are one file each in `shells/` (aria2 is a builder in `lib/`), wired up
in `flake.nix`. Everything here targets `x86_64-linux`.

Registry entry (per user, in `~/.config/nix/registry.json`):

    nix registry add custom github:siew24/custom-flakes

Or skip the registry and use the full reference:
`nix develop github:siew24/custom-flakes#aria2`.

## aria2

The BitTorrent and DHT port (51413, TCP and UDP) is open in the NixOS firewall
only while `aria2c` runs. The command opens the port itself: it shows one
polkit prompt, waits for the guard to confirm, then becomes aria2c. If you
cancel the prompt, it exits instead of pretending the port is open.

Three ways to get it. A dev shell with `aria2c` on PATH, or just the command:

    nix develop custom#aria2
    nix run custom#aria2c -- file.torrent

Or install it with a module. Home Manager:

    imports = [ custom.homeManagerModules.default ];
    custom.aria2 = {
      enable = true;
      downloadDir = "/mnt/data/Downloads"; # optional
    };

NixOS (system-wide; asserts the iptables firewall is on):

    imports = [ custom.nixosModules.default ];
    custom.aria2.enable = true;

Options, the same in both modules:
- `enable`: install the `aria2c` command.
- `downloadDir`: baked into the command. When null it is resolved when
  aria2c runs: `$XDG_DOWNLOAD_DIR`, then `~/Downloads`.
- `port`: defaults to 51413.

`aria2c` is a wrapper. It sets the listen ports, `--seed-time=0` and
`--file-allocation=falloc`, and downloads to the folder above. Extra flags win,
so a later `-d` overrides the folder.

How it works: `aria2c` starts a root guard through pkexec, passing its own PID.
The guard inserts four iptables rules (TCP and UDP, IPv4 and IPv6) into
`nixos-fw`, prints `ready`, then polls that PID and deletes the rules when it
disappears. `aria2c` then `exec`s the real aria2c, so the PID is the same and
the port closes when it exits, including on SIGKILL. Opening and closing are
logged: `journalctl -t aria2-fw-guard`.

Limits:
- NixOS with the iptables firewall only. It calls `/run/wrappers/bin/pkexec`
  and `/run/current-system/sw/bin/iptables`.
- A rebuild that restarts `firewall.service` drops the rules mid-run. Stop
  aria2c and start it again.
- Two runs at once each add their own rules and each removes only its own,
  but both listen on the same port, so only one aria2 can bind it.
- pkexec refuses to run when `$SHELL` is not in `/etc/shells`, and `nix
  develop` sets it to a store bash. The command overrides it for that one call.

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
To use it in place of the nixpkgs one, take this flake as an input and add its
overlay, which builds it with your `pkgs`:

    nixpkgs.overlays = [
      custom.overlays.default
    ];

To bump it, change `version` and `hash` in `packages/hydralauncher.nix`. Get the
hash with:

    nix store prefetch-file https://github.com/hydralauncher/hydra/releases/download/v<version>/hydralauncher-<version>.AppImage

A flake that takes this one as an input only sees the bump after a push and a
`nix flake update custom` on its side.
