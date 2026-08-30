{lib}: let
  getMetadata = {
    host,
    modules,
    secrets,
  }: {
    inherit (host) system;
    hostname =
      if host.hostname != null
      then host.hostname
      else "unspecified";
    modules =
      map (m: {
        inherit (m) name;
        path = m._path;
      })
      modules;
    secrets = lib.mapAttrs (name: val: {
      inherit (val) usedBy required description;
    }) (secrets.getDeclaredSecrets modules);
  };

  isModuleLoadedOption = lib.mkOption {
    type = lib.types.functionTo lib.types.bool;
    readOnly = true;
    description = "Introspection: Checks whether a module with the given name is loaded in this configuration. Usable to gate configuration (e.g. in user dotfiles) on a module's presence.";
  };

  isModuleLoaded = modules: name: lib.any (m: m.name == name) modules;
in {
  mkNixosIntrospection = {
    host,
    users,
    modules,
    secrets,
  }: {
    options.flake-modules = {
      hostname = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Introspection: Host name.";
      };
      system = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Introspection: Host system architecture.";
      };
      users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        readOnly = true;
        description = "Introspection: Host users.";
      };
      modules = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        readOnly = true;
        description = "Introspection: Host modules.";
      };
      secrets = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        readOnly = true;
        description = "Introspection: Host secrets.";
      };
      isModuleLoaded = isModuleLoadedOption;
    };
    config.flake-modules =
      (getMetadata {inherit host modules secrets;})
      // {
        users = map (u: u.username) users;
        isModuleLoaded = isModuleLoaded modules;
      };
  };

  mkHomeIntrospection = {
    host,
    user,
    modules,
    secrets,
  }: {
    options.flake-modules = {
      hostname = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Introspection: Host name.";
      };
      system = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Introspection: Host system architecture.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Introspection: Home Manager user.";
      };
      modules = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        readOnly = true;
        description = "Introspection: HM modules.";
      };
      secrets = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        readOnly = true;
        description = "Introspection: HM secrets.";
      };
      isModuleLoaded = isModuleLoadedOption;
    };
    config.flake-modules =
      (getMetadata {inherit host modules secrets;})
      // {
        user = user.username;
        isModuleLoaded = isModuleLoaded modules;
      };
  };
}
