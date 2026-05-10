{lib, ...}: rec {
  getDeclaredSecrets = modules: lib.foldl (acc: m: acc // m.secrets) {} modules;

  mkSopsAttrs = secrets:
    lib.mapAttrs (n: v: {
      sopsFile = v.path;
      key =
        if (v.key != null)
        then v.key
        else n;
    })
    secrets;

  mkNixosConfig = {
    host,
    users ? [],
    modules,
  }: let
    declaredSecrets = getDeclaredSecrets modules;
    hostSecrets = host.secrets or {};
    userSecrets = lib.foldl (acc: u: acc // (u.secrets or {})) {} users;
    allSecrets = hostSecrets // userSecrets;

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
  in {
    sops = {
      age.sshKeyPaths = lib.mkDefault ["/etc/ssh/ssh_host_ed25519_key"];
      secrets = mkSopsAttrs resolvedSecrets;
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
      nixosSecrets;
  };

  mkHomeConfig = {
    host,
    user,
    modules,
  }: let
    declaredSecrets = getDeclaredSecrets modules;
    hostSecrets = host.secrets or {};
    userSecrets = user.secrets or {};
    allSecrets = hostSecrets // userSecrets;

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

    defaultSshKey =
      if host.system == "x86_64-darwin" || host.system == "aarch64-darwin"
      then "/Users/${user.username}/.ssh/id_ed25519"
      else "/home/${user.username}/.ssh/id_ed25519";
  in {
    sops = {
      age.sshKeyPaths = lib.mkDefault [defaultSshKey];
      secrets = mkSopsAttrs resolvedSecrets;
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
