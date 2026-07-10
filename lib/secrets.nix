{lib, ...}: let
  getUserSshKey = host: user:
    if user.sshKeyPath != null
    then user.sshKeyPath
    else if host.system == "x86_64-darwin" || host.system == "aarch64-darwin"
    then "/Users/${user.username}/.ssh/id_ed25519"
    else "/home/${user.username}/.ssh/id_ed25519";

  mergeSecretsChecked = contextMsg: a: b: let
    overlapping = lib.intersectAttrs a b;
    conflicts = lib.filterAttrs (name: _: a.${name} != b.${name}) overlapping;
  in
    if conflicts != {}
    then let
      conflictNames = lib.concatStringsSep ", " (lib.attrNames conflicts);
    in
      throw "${contextMsg}: Secret name collision for: ${conflictNames}. The same secret name is bound by both sources with different values. Rename one of the bindings to resolve this conflict."
    else a // b;
in rec {
  getDeclaredSecrets = modules:
    lib.foldl (acc: m: let
      merged = lib.mapAttrs (name: val: let
        existing = acc.${name} or null;
      in
        if existing == null
        then val
        else if existing.usedBy == val.usedBy && existing.required == val.required
        then val
        else throw "Secret conflict: Module '${m.name}' defines secret '${name}' with scope '${val.usedBy}' (required: ${toString val.required}), but it was already defined with scope '${existing.usedBy}' (required: ${toString existing.required}) by another module.")
      m.secrets;
    in
      acc // merged) {}
    modules;

  mkSopsAttrs = scope: secrets:
    lib.mapAttrs (
      n: v: let
        override = v.${scope} or null;
        applyOverride = field:
          if override != null && override.${field} != null
          then override.${field}
          else v.${field};
      in
        lib.filterAttrs (name: val: val != null) {
          sopsFile = v.path;
          key =
            if v.key != null
            then v.key
            else n;
          path = applyOverride "decryptedPath";
          mode = applyOverride "mode";
          owner = applyOverride "owner";
          group = applyOverride "group";
          restartUnits = applyOverride "restartUnits";
        }
    )
    secrets;

  mkNixosConfig = {
    host,
    users ? [],
    modules,
  }: let
    declaredSecrets = getDeclaredSecrets modules;
    hostSecrets = host.secrets or {};
    userSecrets = lib.foldl (acc: u:
      mergeSecretsChecked "NixOS secrets: user '${u.username}'" acc (u.secrets or {})) {}
    users;
    allSecrets = mergeSecretsChecked "NixOS secrets" hostSecrets userSecrets;

    resolvedSecrets =
      lib.filterAttrs
      (n: v:
        if declaredSecrets ? ${n}
        then declaredSecrets.${n}.usedBy == "nixos" || declaredSecrets.${n}.usedBy == "both"
        else true)
      allSecrets;

    nixosSecrets =
      lib.filterAttrs
      (n: req: req.usedBy == "nixos" || req.usedBy == "both")
      declaredSecrets;

    hmOnlySecrets =
      lib.filterAttrs
      (n: req: req.usedBy == "hm")
      declaredSecrets;

    userSshKeys = map (getUserSshKey host) users;
  in {
    sops = {
      age.sshKeyPaths = lib.mkDefault ([host.sshKeyPath] ++ userSshKeys);
      gnupg.sshKeyPaths = lib.mkDefault ((host.gnupgKeyPaths or []) ++ (lib.flatten (map (u: u.gnupgKeyPaths or []) users)));
      secrets = mkSopsAttrs "nixos" resolvedSecrets;
    };

    assertions =
      lib.mapAttrsToList (name: req: let
        description =
          if req.description != null
          then "${req.description}, "
          else "";
      in {
        assertion = !req.required || (allSecrets ? ${name});
        message = "NixOS: Module requires the secret '${name}' (${description}scope: ${req.usedBy}), but it is not configured.";
      })
      nixosSecrets
      ++ lib.mapAttrsToList (name: req: let
        description =
          if req.description != null
          then "${req.description}, "
          else "";
      in {
        assertion = !req.required || (userSecrets ? ${name});
        message = "NixOS: Module requires the HM secret '${name}' (${description}scope: hm), but no user has configured it. Add it to a user's secrets.";
      })
      hmOnlySecrets;
  };

  mkHomeConfig = {
    host,
    user,
    modules,
  }: let
    declaredSecrets = getDeclaredSecrets modules;
    hostSecrets = host.secrets or {};
    userSecrets = user.secrets or {};
    allSecrets = mergeSecretsChecked "HM (${user.username}) secrets" hostSecrets userSecrets;

    resolvedSecrets =
      lib.filterAttrs
      (n: v:
        if declaredSecrets ? ${n}
        then declaredSecrets.${n}.usedBy == "hm" || declaredSecrets.${n}.usedBy == "both"
        else true)
      allSecrets;

    hmSecrets =
      lib.filterAttrs
      (n: req: req.usedBy == "hm" || req.usedBy == "both")
      declaredSecrets;

    defaultSshKey = getUserSshKey host user;
  in {
    sops = {
      age.sshKeyPaths = lib.mkDefault [defaultSshKey];
      gnupg.sshKeyPaths = lib.mkDefault (user.gnupgKeyPaths or []);
      secrets = mkSopsAttrs "hm" resolvedSecrets;
    };

    assertions =
      lib.mapAttrsToList (name: req: let
        description =
          if req.description != null
          then "${req.description}, "
          else "";
      in {
        assertion = !req.required || (allSecrets ? ${name});
        message = "HM (${user.username}): Module requires the secret '${name}' (${description}scope: ${req.usedBy}), but it is not configured.";
      })
      hmSecrets;
  };
}
