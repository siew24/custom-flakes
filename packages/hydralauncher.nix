{
  lib,
  fetchurl,
  appimageTools,
  nix-update-script,
}:
let
  pname = "hydralauncher";
  version = "4.2.0";
  src = fetchurl {
    url = "https://github.com/hydralauncher/hydra/releases/download/v${version}/hydralauncher-${version}.AppImage";
    hash = "sha256-p/97sPEx00DWhXR2WfkoNxEkBC7FKl94l8apD7zv3gc=";
  };

  appimageContents = appimageTools.extract { inherit pname src version; };
in
appimageTools.wrapType2 {
  inherit pname src version;

  # Hydra's bundled umu-run is a python script; it looks for /usr/bin/python3.
  # Hydra only offers GameMode when `ldconfig -p` lists libgamemode.so and
  # libgamemodeauto.so, and the host's libraries never reach the env's cache.
  extraPkgs = pkgs: [
    pkgs.python3
    pkgs.gamemode
  ];

  # Hydra forces PROTON_LOG=1, and Proton's default trace channels filled the
  # root disk (27.7 GB in one session). Proton keeps a WINEDEBUG that is
  # already set, so keep errors only.
  profile = ''
    export WINEDEBUG=-all,err+all
  '';

  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/hydralauncher.png \
      $out/share/icons/hicolor/512x512/apps/hydralauncher.png

    install -Dm644 ${appimageContents}/hydralauncher.desktop \
      $out/share/applications/hydralauncher.desktop
    substituteInPlace $out/share/applications/hydralauncher.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${placeholder "out"}/bin/hydralauncher'
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Game launcher with its own embedded bittorrent client";
    homepage = "https://github.com/hydralauncher/hydra";
    changelog = "https://github.com/hydralauncher/hydra/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ HeitorAugustoLN ];
    mainProgram = "hydralauncher";
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
