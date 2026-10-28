# Dev shell for torrenting with aria2. The BitTorrent port is open in the
# NixOS firewall only while the shell is open.
{ pkgs }:
let
  port = "51413";

  # Runs as root, started by pkexec from the shell hook. Opens the port,
  # tells the shell it is ready, then waits for the shell's PID to vanish
  # and closes the port. Watching the PID rather than trapping a signal
  # means the port closes even if the shell is killed with SIGKILL.
  # Uses the system's own iptables so the rules land in the same tables as
  # the NixOS firewall, whatever nixpkgs this flake was locked to.
  guard = pkgs.writeShellApplication {
    name = "aria2-fw-guard";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      port=${port}
      ipt=/run/current-system/sw/bin/iptables
      ip6t=/run/current-system/sw/bin/ip6tables

      if [ "$(id -u)" -ne 0 ] || [ -z "''${PKEXEC_UID:-}" ] || [ "$PKEXEC_UID" -eq 0 ]; then
        echo "aria2-fw-guard: started by the dev shell only" >&2
        exit 1
      fi

      pid="''${1:-}"
      [[ $pid =~ ^[0-9]+$ ]] || { echo "aria2-fw-guard: need a PID" >&2; exit 2; }
      # Only watch a process the caller owns, so the port cannot be pinned
      # open by naming an unrelated long-lived process.
      [ "$(stat -c %u "/proc/$pid" 2>/dev/null)" = "$PKEXEC_UID" ] \
        || { echo "aria2-fw-guard: PID $pid is not yours" >&2; exit 1; }

      rule() {
        for proto in tcp udp; do
          "$ipt" -w "$1" nixos-fw -p "$proto" --dport "$port" -j nixos-fw-accept
          "$ip6t" -w "$1" nixos-fw -p "$proto" --dport "$port" -j nixos-fw-accept
        done
      }
      count() { "$1" -S nixos-fw | grep -c -- "--dport $port" || true; }

      close_ports() {
        set +e
        rule -D 2>/dev/null
        logger -t aria2-fw-guard "closed port $port: v4=$(count "$ipt") v6=$(count "$ip6t")"
      }
      trap close_ports EXIT
      trap 'exit 0' INT TERM HUP

      rule -I
      logger -t aria2-fw-guard "opened port $port for shell PID $pid (uid $PKEXEC_UID): v4=$(count "$ipt") v6=$(count "$ip6t")"
      echo "ready v4=$(count "$ipt") v6=$(count "$ip6t")" || true

      while kill -0 "$pid" 2>/dev/null; do sleep 1; done
    '';
  };

  # aria2c with this shell's defaults. Later flags override earlier ones.
  aria2c = pkgs.writeShellScriptBin "aria2c" ''
    dir="''${ARIA2_BT_DIR:-''${XDG_DOWNLOAD_DIR:-$HOME/Downloads}}"
    mkdir -p "$dir"
    exec ${pkgs.aria2}/bin/aria2c \
      --listen-port=${port} --dht-listen-port=${port} \
      --seed-time=0 --file-allocation=falloc \
      -d "$dir" "$@"
  '';
in
{
  inherit guard;

  shell = pkgs.mkShellNoCC {
    packages = [ aria2c ];
    shellHook = ''
      # pkexec has to be the setuid NixOS wrapper. Its stdout is a pipe the
      # guard writes "ready" into once the rules are in.
      # nix develop points SHELL at a bare store bash that is not in
      # /etc/shells, and pkexec then refuses to run at all, with no prompt
      # ("The value for the SHELL variable was not found in /etc/shells").
      exec {aria2_fw_fd}< <(SHELL=/run/current-system/sw/bin/bash \
        /run/wrappers/bin/pkexec ${guard}/bin/aria2-fw-guard $$ </dev/null)
      if ! read -r -t 180 -u "$aria2_fw_fd" aria2_fw_reply || [[ $aria2_fw_reply != ready* ]]; then
        echo "aria2 shell: the port was not opened (prompt cancelled or timed out)" >&2
        exit 1
      fi
      exec {aria2_fw_fd}<&-
      echo "Port ${port} (TCP and UDP) is open. Run aria2c, then type exit to close it. [$aria2_fw_reply]"
    '';
  };
}
