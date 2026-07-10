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
      merged = lib.mapAttrs' (name: val: let
        qualName = "${m.name}/${name}";
      in
        lib.nameValuePair qualName (val
          // {
            inherit name;
            module = m.name;
            qualifiedName = qualName;
          }))
      m.secrets;
    in
      acc // merged) {}
    modules;

  resolveBindings = contextMsg: declaredSecrets: bindings: let
    groupedByUnqualified = lib.groupBy (s: s.name) (lib.attrValues declaredSecrets);
    resolved =
      lib.mapAttrs (
        qualName: decl: let
          directBinding = bindings.${qualName} or null;
          unqualBinding = bindings.${decl.name} or null;
          isAmbiguous = lib.length (groupedByUnqualified.${decl.name} or []) > 1;
        in
          if directBinding != null
          then directBinding
          else if unqualBinding != null
          then
            if isAmbiguous
            then throw "${contextMsg}: Ambiguous secret binding for '${decl.name}'. Multiple modules declare a secret with this name: ${lib.concatStringsSep ", " (map (s: s.module) groupedByUnqualified.${decl.name})}. Please use the fully qualified name (e.g. 'moduleName/secretName') in your bindings."
            else builtins.trace "warning: Unqualified secret binding for '${decl.name}' in ${contextMsg} is deprecated. Please change it to '${qualName}'." unqualBinding
          else null
      )
      declaredSecrets;
  in
    lib.filterAttrs (n: v: v != null) resolved;

  mkSopsAttrs = scope: declaredSecrets: resolvedSecrets: let
    groupedByUnqualified = lib.groupBy (s: s.name) (lib.attrValues declaredSecrets);
    sopsEntries =
      lib.mapAttrs (
        qualName: v: let
          decl = declaredSecrets.${qualName};
          override = v.${scope} or null;
          applyOverride = field:
            if override != null && override.${field} != null
            then override.${field}
            else v.${field};
          sopsKey =
            if v.key != null
            then v.key
            else decl.name;
        in
          lib.filterAttrs (name: val: val != null) {
            sopsFile = v.path;
            key = sopsKey;
            path = applyOverride "decryptedPath";
            mode = applyOverride "mode";
            owner = applyOverride "owner";
            group = applyOverride "group";
            restartUnits = applyOverride "restartUnits";
          }
      )
      resolvedSecrets;

    aliases =
      lib.concatMapAttrs (
        qualName: entry: let
          decl = declaredSecrets.${qualName};
          isUnique = lib.length (groupedByUnqualified.${decl.name} or []) == 1;
        in
          if isUnique && decl.name != qualName
          then {${decl.name} = entry;}
          else {}
      )
      sopsEntries;
  in
    sopsEntries // aliases;

  mkNixosConfig = {
    host,
    users ? [],
    modules,
  }: let
    declaredSecrets = getDeclaredSecrets modules;
    hostName =
      if host ? hostname && host.hostname != null
      then host.hostname
      else "unspecified";
    hostSecrets = resolveBindings "Host '${hostName}'" declaredSecrets (host.secrets or {});
    resolvedUserSecretsList = map (u: resolveBindings "User '${u.username}'" declaredSecrets (u.secrets or {})) users;
    userSecrets = lib.foldl (acc: uSecs: mergeSecretsChecked "NixOS user secrets" acc uSecs) {} resolvedUserSecretsList;

    resolvedSecrets =
      lib.filterAttrs
      (n: v:
        if declaredSecrets ? ${n}
        then declaredSecrets.${n}.usedBy == "nixos" || declaredSecrets.${n}.usedBy == "both"
        else true)
      hostSecrets;

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
      secrets = mkSopsAttrs "nixos" declaredSecrets resolvedSecrets;
    };

    assertions =
      lib.mapAttrsToList (qualName: req: let
        description =
          if req.description != null
          then "${req.description}, "
          else "";
      in {
        assertion = !req.required || (resolvedSecrets ? ${qualName});
        message = "NixOS: Module '${req.module}' requires the secret '${req.name}' (${description}scope: ${req.usedBy}), but it is not configured on the host.";
      })
      nixosSecrets
      ++ lib.mapAttrsToList (qualName: req: let
        description =
          if req.description != null
          then "${req.description}, "
          else "";
      in {
        assertion = !req.required || (userSecrets ? ${qualName});
        message = "NixOS: Module '${req.module}' requires the HM secret '${req.name}' (${description}scope: hm), but no user has configured it. Add it to a user's secrets.";
      })
      hmOnlySecrets;
  };

  mkHomeConfig = {
    host,
    user,
    modules,
  }: let
    declaredSecrets = getDeclaredSecrets modules;
    userSecrets = resolveBindings "User '${user.username}'" declaredSecrets (user.secrets or {});

    resolvedSecrets =
      lib.filterAttrs
      (n: v:
        if declaredSecrets ? ${n}
        then declaredSecrets.${n}.usedBy == "hm" || declaredSecrets.${n}.usedBy == "both"
        else true)
      userSecrets;

    hmSecrets =
      lib.filterAttrs
      (n: req: req.usedBy == "hm" || req.usedBy == "both")
      declaredSecrets;

    defaultSshKey = getUserSshKey host user;
  in {
    sops = {
      age.sshKeyPaths = lib.mkDefault [defaultSshKey];
      gnupg.sshKeyPaths = lib.mkDefault (user.gnupgKeyPaths or []);
      secrets = mkSopsAttrs "hm" declaredSecrets resolvedSecrets;
    };

    assertions =
      lib.mapAttrsToList (qualName: req: let
        description =
          if req.description != null
          then "${req.description}, "
          else "";
      in {
        assertion = !req.required || (userSecrets ? ${qualName});
        message = "HM (${user.username}): Module '${req.module}' requires the secret '${req.name}' (${description}scope: ${req.usedBy}), but it is not configured in user secrets.";
      })
      hmSecrets;
  };
}
