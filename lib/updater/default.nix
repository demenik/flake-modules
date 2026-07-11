{
  pkgs,
  appName ? "overlay-update",
}:
pkgs.writeShellApplication {
  name = appName;
  runtimeInputs = with pkgs; [
    bash
    findutils
    python3
    git
    nix
    bubblewrap
    curl
    gnugrep
  ];
  text = ''
    export FM_UPDATE_APP_NAME="${appName}"
    export FM_UPDATE_SYSTEM="${pkgs.stdenv.hostPlatform.system}"
    export FM_UPDATE_PROGRAM_PATH="$0"
    python3 ${./src}/main.py "$@"
  '';
}
