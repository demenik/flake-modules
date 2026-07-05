{
  nixpkgs,
  home-manager,
  lib,
  lib-inputs,
  ...
}: let
  secrets = import ./secrets.nix {inherit lib;};
  introspection = import ./introspection.nix {inherit lib;};

  resolveConfig = {
    hostPath,
    inputs,
    userPaths ? null,
  }: let
    loader = import ./module-loader.nix {inherit lib inputs;};
    host = loader.loadHost hostPath;

    resolvedUserPaths =
      if userPaths == null
      then host.users
      else userPaths;
    users = map loader.loadUser resolvedUserPaths;

    modulePaths = host.modules ++ (lib.flatten (map (u: u.modules) users));
    modules = loader.resolveModules host.system modulePaths;

    options =
      map (m: {
        _file = "moduleOptions in '${m.name}'";
        options = m.moduleOptions;
      })
      modules;
  in {
    inherit host users modules options loader;
  };

  mkNixosHost = import ./builders/nixos.nix {
    inherit nixpkgs home-manager lib lib-inputs secrets introspection;
  };
in {
  inherit resolveConfig mkNixosHost;

  mkHost = {
    hostPath,
    inputs,
    extraSpecialArgs ? {},
    extraModules ? [],
    customBuilders ? {},
  }: let
    configData = resolveConfig {inherit hostPath inputs;};
    hostType =
      if lib.hasSuffix "darwin" configData.host.system
      then "darwin"
      else "nixos";

    builders =
      {
        nixos = mkNixosHost;
      }
      // customBuilders;
  in
    if builders ? ${hostType}
    then builders.${hostType} {inherit hostPath inputs extraSpecialArgs extraModules configData;}
    else throw "Unsupported host type '${hostType}' for system '${configData.host.system}'. No builder registered for this type.";

  mkHome = import ./builders/home.nix {
    inherit nixpkgs home-manager lib lib-inputs secrets introspection resolveConfig;
  };
}
