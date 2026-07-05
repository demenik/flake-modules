{
  nixpkgs,
  home-manager,
  lib,
  lib-inputs,
}: let
  builders = import ./builders.nix {
    inherit nixpkgs home-manager lib lib-inputs;
  };
  discovery = import ./discovery.nix {
    inherit nixpkgs lib;
    inherit (builders) mkHost mkHome;
  };
  secretsLib = import ./secrets.nix {inherit lib;};

  queryHost = {
    hostPath,
    inputs,
  }: let
    configData = builders.resolveConfig {inherit hostPath inputs;};
    declaredSecrets = secretsLib.getDeclaredSecrets configData.modules;
  in {
    hostname =
      if configData.host.hostname != null
      then configData.host.hostname
      else "unspecified";
    system = configData.host.system;
    users = map (u: u.username) configData.users;
    modules =
      map (m: {
        inherit (m) name;
        path = m._path;
      })
      configData.modules;
    secrets =
      lib.mapAttrs (name: val: {
        inherit (val) usedBy required description;
      })
      declaredSecrets;
  };
in {
  inherit (builders) mkHost mkHome;
  inherit (discovery) mkNixosConfigurations mkHomeConfigurations;
  inherit queryHost;
}
