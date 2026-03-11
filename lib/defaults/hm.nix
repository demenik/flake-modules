{
  user,
  system,
  lib,
  ...
}: let
  isDarwin = lib.strings.hasSuffix "darwin" system;
in {
  home = {
    username = lib.mkDefault user.username;
    homeDirectory = lib.mkDefault (
      if isDarwin
      then "/Users/${user.username}"
      else "/home/${user.username}"
    );
  };
}
