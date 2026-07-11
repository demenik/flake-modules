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
    export FM_UPDATE_PROGRAM_PATH="$0"
    python3 ${./src}/main.py "$@"
  '';
}
