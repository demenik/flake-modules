{lib, ...}: let
  getUserSshKey = host: user:
    if user.sshKeyPath != null
    then user.sshKeyPath
    else if host.system == "x86_64-darwin" || host.system == "aarch64-darwin"
    then "/Users/${user.username}/.ssh/id_ed25519"
    else "/home/${user.username}/.ssh/id_ed25519";
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
          binding =
            if directBinding != null
            then directBinding
            else if unqualBinding != null
            then
              if isAmbiguous
              then throw "${contextMsg}: Ambiguous secret binding for '${decl.name}'. Multiple modules declare a secret with this name: ${lib.concatStringsSep ", " (map (s: s.module) groupedByUnqualified.${decl.name})}. Please use the fully qualified name (e.g. 'moduleName/secretName') in your bindings."
              else builtins.trace "warning: Unqualified secret binding for '${decl.name}' in ${contextMsg} is deprecated. Please change it to '${qualName}'." unqualBinding
            else null;
          hasHmOverride = binding != null && binding ? hm && binding.hm != null;
          hasNixosOverride = binding != null && binding ? nixos && binding.nixos != null;
        in
          if hasHmOverride && decl.usedBy == "nixos"
          then builtins.trace "warning: Secret binding '${qualName}' in ${contextMsg} specifies an 'hm' override, but the secret's scope is 'nixos'. This override has no effect and will be ignored." binding
          else if hasNixosOverride && decl.usedBy == "hm"
          then builtins.trace "warning: Secret binding '${qualName}' in ${contextMsg} specifies a 'nixos' override, but the secret's scope is 'hm'. This override has no effect and will be ignored." binding
          else binding
      )
      declaredSecrets;
  in
    lib.filterAttrs (n: v: v != null) resolved;

  mkSopsAttrs = scope: declaredSecrets: resolvedSecrets: let
    groupedByUnqualified = lib.groupBy (s: s.name) (lib.attrValues declaredSecrets);
    sopsEntries =
      lib.mapAttrs (
        qualName: v: let
          realQualName =
            if lib.hasPrefix "user/" qualName
            then let
              parts = lib.splitString "/" qualName;
              realParts = lib.drop 2 parts;
            in
              lib.concatStringsSep "/" realParts
            else qualName;
          decl = declaredSecrets.${realQualName} or (throw "Internal error: declared secret not found for '${realQualName}' (from '${qualName}')");
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
          realQualName =
            if lib.hasPrefix "user/" qualName
            then let
              parts = lib.splitString "/" qualName;
              realParts = lib.drop 2 parts;
            in
              lib.concatStringsSep "/" realParts
            else qualName;
          decl = declaredSecrets.${realQualName};
          isUnique = lib.length (groupedByUnqualified.${decl.name} or []) == 1;
          hasUserPrefix = lib.hasPrefix "user/" qualName;
        in
          if isUnique && decl.name != qualName && !hasUserPrefix
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

    # Resolve user secrets individually per user
    resolvedUserSecrets =
      map (u: {
        inherit (u) username;
        secrets = resolveBindings "User '${u.username}'" declaredSecrets (u.secrets or {});
      })
      users;

    # Merge all resolved user secrets for assertion checks
    allUserSecretsMerged = lib.foldl (acc: uSecInfo: acc // uSecInfo.secrets) {} resolvedUserSecrets;

    # Filter host secrets to NixOS/both scopes
    nixosHostSecrets =
      lib.filterAttrs
      (n: v:
        if declaredSecrets ? ${n}
        then declaredSecrets.${n}.usedBy == "nixos" || declaredSecrets.${n}.usedBy == "both"
        else true)
      hostSecrets;

    # Prepare user-provided secrets (both or nixos) mapped to user-specific paths
    nixosUserSecrets = lib.foldl (acc: uSecInfo: let
      relevantSecs =
        lib.filterAttrs (
          n: v:
            if declaredSecrets ? ${n}
            then declaredSecrets.${n}.usedBy == "both" || declaredSecrets.${n}.usedBy == "nixos"
            else false
        )
        uSecInfo.secrets;
      mapped =
        lib.mapAttrs' (
          qualName: v:
            lib.nameValuePair "user/${uSecInfo.username}/${qualName}" v
        )
        relevantSecs;
    in
      acc // mapped) {}
    resolvedUserSecrets;

    nixosSecrets =
      lib.filterAttrs
      (n: req: req.usedBy == "nixos" || req.usedBy == "both")
      declaredSecrets;

    hmOnlySecrets =
      lib.filterAttrs
      (n: req: req.usedBy == "hm")
      declaredSecrets;

    # Determine which user secrets are bound by exactly one user to generate aliases
    userSecretBindingsCount = lib.foldl (acc: uSecInfo: let
      relevantNames = lib.attrNames (lib.filterAttrs (
          n: v:
            declaredSecrets.${n}.usedBy or null == "both" || declaredSecrets.${n}.usedBy or null == "nixos"
        )
        uSecInfo.secrets);
    in
      lib.foldl (a: name: a // {${name} = (a.${name} or 0) + 1;}) acc relevantNames) {}
    resolvedUserSecrets;

    userAliases =
      lib.concatMapAttrs (
        qualName: count: let
          bindingUser = lib.findFirst (uSecInfo: uSecInfo.secrets ? ${qualName}) null resolvedUserSecrets;
          req = declaredSecrets.${qualName} or {};
        in
          if count == 1 && bindingUser != null && !(req.perUser or false) && !(nixosHostSecrets ? ${qualName})
          then
            builtins.trace "warning: Secret '${qualName}' from user '${bindingUser.username}' is implicitly mapped globally to NixOS. This is deprecated. Please bind it explicitly in host.secrets as well." {
              ${qualName} = nixosUserSecrets."user/${bindingUser.username}/${qualName}";
            }
          else {}
      )
      userSecretBindingsCount;

    sopsAttrsForHost = mkSopsAttrs "nixos" declaredSecrets nixosHostSecrets;
    sopsAttrsForUser = mkSopsAttrs "nixos" declaredSecrets nixosUserSecrets;
    sopsAttrsForAliases = mkSopsAttrs "nixos" declaredSecrets userAliases;

    # Merge secrets: user-specific first, then aliases, then host bindings (host wins conflicts)
    allNixosSopsSecrets = sopsAttrsForUser // sopsAttrsForAliases // sopsAttrsForHost;

    userSshKeys = map (getUserSshKey host) users;
  in {
    sops = {
      age.sshKeyPaths = lib.mkDefault ([host.sshKeyPath] ++ userSshKeys);
      gnupg.sshKeyPaths = lib.mkDefault ((host.gnupgKeyPaths or []) ++ (lib.flatten (map (u: u.gnupgKeyPaths or []) users)));
      secrets = allNixosSopsSecrets;
    };

    assertions =
      lib.mapAttrsToList (qualName: req: let
        description =
          if req.description != null
          then "${req.description}, "
          else "";
      in {
        assertion =
          if req.perUser or false
          then (!req.required || allUserSecretsMerged ? ${qualName})
          else (!req.required || nixosHostSecrets ? ${qualName} || (req.usedBy == "both" && allUserSecretsMerged ? ${qualName}));
        message =
          if req.perUser or false
          then "NixOS: Module '${req.module}' requires the secret '${req.name}' (${description}scope: ${req.usedBy}), but no user has configured it (perUser is enabled)."
          else "NixOS: Module '${req.module}' requires the secret '${req.name}' (${description}scope: ${req.usedBy}), but it is not configured on the host.";
      })
      nixosSecrets
      ++ lib.mapAttrsToList (qualName: req: let
        description =
          if req.description != null
          then "${req.description}, "
          else "";
        hasBinding = allUserSecretsMerged ? ${qualName} || (!req.perUser or false && hostSecrets ? ${qualName});
      in {
        assertion = !req.required || hasBinding;
        message = "NixOS: Module '${req.module}' requires the HM secret '${req.name}' (${description}scope: hm), but no user has configured it (and no global host fallback was found).";
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
    hostName =
      if host ? hostname && host.hostname != null
      then host.hostname
      else "unspecified";
    hostSecrets = resolveBindings "Host '${hostName}'" declaredSecrets (host.secrets or {});

    # Resolve HM/both secrets applying host-level fallbacks if not perUser
    resolvedSecrets = lib.filterAttrs (qualName: binding: binding != null) (
      lib.mapAttrs (
        qualName: decl: let
          userBinding = userSecrets.${qualName} or null;
          hostBinding = hostSecrets.${qualName} or null;
          isPerUser = decl.perUser or false;
          isRelevant = decl.usedBy == "hm" || decl.usedBy == "both";
        in
          if !isRelevant
          then null
          else if userBinding != null
          then userBinding
          else if !isPerUser && hostBinding != null
          then hostBinding
          else null
      )
      declaredSecrets
    );

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
        assertion = !req.required || (resolvedSecrets ? ${qualName});
        message = "HM (${user.username}): Module '${req.module}' requires the secret '${req.name}' (${description}scope: ${req.usedBy}), but it is not configured in user secrets (and no global host fallback was found).";
      })
      hmSecrets;
  };
}
