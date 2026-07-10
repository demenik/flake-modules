{
  lib,
  mkHost,
  mkHome,
  ...
}: let
  discoverHostsInDir = dir:
    if dir != null && builtins.pathExists dir
    then let
      files = builtins.readDir dir;
      filteredFiles = lib.filterAttrs (name: type: !lib.hasPrefix "." name) files;
      dirs = lib.filterAttrs (name: type: type == "directory") filteredFiles;
      nixFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix") filteredFiles;

      discoveredDirs = lib.mapAttrs (name: _: dir + "/${name}") dirs;
      discoveredFiles = lib.listToAttrs (map (name: {
        name = lib.removeSuffix ".nix" name;
        value = dir + "/${name}";
      }) (lib.attrNames nixFiles));
    in
      discoveredDirs // discoveredFiles
    else {};
in {
  mkNixosConfigurations = {
    hostsDir ? null,
    hosts ? {},
    inputs,
    extraSpecialArgs ? {},
    extraModules ? [],
    customBuilders ? {},
  }: let
    discoveredHosts = discoverHostsInDir hostsDir;
    allHosts = discoveredHosts // hosts;
  in
    lib.mapAttrs
    (hostName: hostPath:
      mkHost {
        inherit hostPath inputs extraSpecialArgs extraModules customBuilders;
      })
    allHosts;

  mkHomeConfigurations = {
    hostsDir ? null,
    hosts ? {},
    inputs,
    extraSpecialArgs ? {},
    extraModules ? [],
  }: let
    loader = import ./module-loader.nix {inherit lib inputs;};
    discoveredHosts = discoverHostsInDir hostsDir;
    allHosts = discoveredHosts // hosts;

    getUserConfigForHost = hostName: hostPath: let
      host = loader.loadHost hostPath;
    in
      lib.listToAttrs (
        map (
          userPath: let
            user = loader.loadUser userPath;
          in
            lib.nameValuePair
            "${user.username}@${hostName}"
            (mkHome {
              inherit hostPath userPath inputs extraSpecialArgs extraModules;
            })
        )
        host.users
      );
  in
    lib.foldl' (acc: hostName: acc // (getUserConfigForHost hostName allHosts.${hostName})) {} (builtins.attrNames allHosts);

  mkUpdaterApp = import ./updater/app.nix {
    inherit lib discoverHostsInDir;
  };
}
