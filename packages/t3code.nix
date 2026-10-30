{
  lib,
  fetchurl,
  appimageTools,
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
in
appimageTools.wrapType2 {
  inherit pname src version;

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

  passthru.updateScript = nix-update-script { };

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
