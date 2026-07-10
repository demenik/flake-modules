{
  pkgs,
  appName ? "overlay-update",
}:
pkgs.writeShellApplication {
  name = appName;
  runtimeInputs = with pkgs; [
    python3
    git
    nix
  ];
  text = ''
    export FM_UPDATE_APP_NAME="${appName}"
    export FM_UPDATE_SYSTEM="${pkgs.stdenv.hostPlatform.system}"
    python3 ${./src}/main.py "$@"
  '';
}
