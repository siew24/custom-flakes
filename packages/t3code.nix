{
  lib,
  fetchurl,
  appimageTools,
  runCommand,
  nodejs,
  nix-update-script,
}:
let
  pname = "t3code";
  version = "0.1.5";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-kz/53ExlCnWqQIfJjyrmxlQMIz8OL+sy6/+VCwm+hJ0=";
  };

  appimageContents = appimageTools.extract { inherit pname src version; };

  # Linked environments refuse plain http except to loopback and Tailscale.
  # Also accept a 100.64.0.0/10 address that the local NetBird daemon, while
  # connected, lists as this machine or a connected peer. Any other address in
  # that range (WARP, CGNAT) is still refused. This is the check proposed in
  # pingdotgg/t3code#26840, modelled on #26475's Tailscale one.
  #
  # It goes inline in peerOrigin's condition, where `parsed` is the peer URL.
  # The bundle is ESM, hence getBuiltinModule rather than require.
  netbirdPeerCheck = ''
    !(isSharedAddressSpaceHost(parsed.hostname) && (() => {
    	try {
    		const status = JSON.parse(process.getBuiltinModule("node:child_process").execFileSync("netbird", ["status", "--json"], { encoding: "utf8", timeout: 5000, stdio: ["ignore", "pipe", "ignore"] }));
    		const address = (cidr) => String(cidr ?? "").split("/")[0];
    		return status.management?.connected === true && (address(status.netbirdIp) === parsed.hostname || (status.peers?.details ?? []).some((peer) => peer.status === "Connected" && address(peer.netbirdIp) === parsed.hostname));
    	} catch {
    		return false;
    	}
    })())'';

  patchedContents = runCommand "${pname}-${version}-patched" { nativeBuildInputs = [ nodejs ]; } ''
    cp -a ${appimageContents} $out
    chmod -R u+w $out
    node ${./t3code-asar-replace.mjs} $out/resources/app.asar \
      apps/server/dist/binCli-1k0PQRR7.mjs \
      '!isTailnetHost(parsed.hostname)) return fail$1(new PeerLinkError' \
      '!isTailnetHost(parsed.hostname) && ${netbirdPeerCheck}) return fail$1(new PeerLinkError'
  '';
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = patchedContents;

  # Chromium's ICU can't work out the zone from a /nix/store /etc/localtime, so
  # Intl reports undefined and Electron apps can open to a blank window.
  profile = ''
    if [ -z "$TZ" ]; then
      _tz=$(readlink -f /etc/localtime 2>/dev/null | sed -n 's#.*/zoneinfo/##p')
      [ -n "$_tz" ] && export TZ="$_tz"
    fi
  '';

  extraInstallCommands = ''
    mkdir -p $out/share
    cp -r ${appimageContents}/usr/share/icons $out/share/

    install -Dm644 ${appimageContents}/t3code.desktop \
      $out/share/applications/t3code.desktop
    # On Wayland the window's app id is com.t3tools.T3Code, not the t3code the
    # desktop file claims, so launchers wouldn't match the two up.
    substituteInPlace $out/share/applications/t3code.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${placeholder "out"}/bin/t3code' \
      --replace-fail 'StartupWMClass=t3code' 'StartupWMClass=com.t3tools.T3Code'
  '';

  passthru = {
    # nix-update reads the AppImage from src, and the t3 CLI shim runs the
    # server from the patched contents.
    inherit src;
    contents = patchedContents;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Desktop app for coding agents";
    homepage = "https://github.com/pingdotgg/t3code";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "t3code";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
