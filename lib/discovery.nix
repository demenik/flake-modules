{
  lib,
  mkHost,
  mkHome,
  ...
}: let
  getDirs = dir:
    if builtins.pathExists dir
    then lib.filterAttrs (name: type: type == "directory") (builtins.readDir dir)
    else {};
in {
  mkNixosConfigurations = {
    hostsDir,
    inputs,
  }:
    lib.mapAttrs
    (hostName: _:
      mkHost {
        hostPath = hostsDir + "/${hostName}";
        inherit inputs;
      })
    (getDirs hostsDir);

  mkHomeConfigurations = {
    hostsDir,
    inputs,
  }: let
    hostDirs = getDirs hostsDir;

    getUserConfigForHost = hostName: let
      hostPath = hostsDir + "/${hostName}";
      host = import hostPath;
    in
      if host ? users
      then
        lib.listToAttrs (
          map (
            userPath: let
              user = import userPath;
            in
              lib.nameValuePair
              "${user.username}@${hostName}"
              (mkHome {
                inherit hostPath userPath inputs;
              })
          )
          host.users
        )
      else {};
  in
    lib.foldl' (acc: hostName: acc // (getUserConfigForHost hostName)) {} (builtins.attrNames hostDirs);
}
