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
    hostsDir ? null,
    hosts ? {},
    inputs,
    extraSpecialArgs ? {},
    extraModules ? [],
  }: let
    discoveredHosts =
      if (hostsDir != null)
      then
        lib.mapAttrs
        (hostName: _: hostsDir + "/${hostName}")
        (getDirs hostsDir)
      else {};

    allHosts = discoveredHosts // hosts;
  in
    lib.mapAttrs
    (hostName: hostPath:
      mkHost {
        inherit hostPath inputs extraSpecialArgs extraModules;
      })
    allHosts;

  mkHomeConfigurations = {
    hostsDir ? null,
    hosts ? {},
    inputs,
    extraSpecialArgs ? {},
    extraModules ? [],
  }: let
    discoveredHosts =
      if (hostsDir != null)
      then
        lib.mapAttrs
        (hostName: _: hostsDir + "/${hostName}")
        (getDirs hostsDir)
      else {};

    allHosts = discoveredHosts // hosts;

    getUserConfigForHost = hostName: hostPath: let
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
                inherit hostPath userPath inputs extraSpecialArgs extraModules;
              })
          )
          host.users
        )
      else {};
  in
    lib.foldl' (acc: hostName: acc // (getUserConfigForHost hostName allHosts.${hostName})) {} (builtins.attrNames allHosts);
}
