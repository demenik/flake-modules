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
    };
    config.flake-modules =
      (getMetadata {inherit host modules secrets;})
      // {
        users = map (u: u.username) users;
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
    };
    config.flake-modules =
      (getMetadata {inherit host modules secrets;})
      // {
        user = user.username;
      };
  };
}
