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
    modules,
  }: let
    declaredSecrets = getDeclaredSecrets modules;
    hostSecrets = host.secrets or {};

    nixosSecrets =
      lib.filterAttrs
      (n: req: req.requiredBy == "nixos" || req.requiredBy == "both")
      declaredSecrets;
  in {
    sops = {
      age.sshKeyPaths = lib.mkDefault ["/etc/ssh/ssh_host_ed25519_key"];
      secrets = mkSopsAttrs hostSecrets;
    };

    assertions =
      lib.mapAttrsToList (name: req: let
        description =
          if req.description != null
          then "${req.description}, "
          else "";
      in {
        assertion = hostSecrets ? ${name};
        message = "NixOS: Module requires the secret '${name}' (${description}scope: ${req.requiredBy}), but it is not configured.";
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
    resolvedSecrets = hostSecrets // userSecrets;

    hmSecrets =
      lib.filterAttrs
      (n: req: req.requiredBy == "home" || req.requiredBy == "both")
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
        assertion =
          if req.requiredBy == "home"
          then (userSecrets ? ${name})
          else (hostSecrets ? ${name});
        message = "HM (${user.username}): Module requires the secret '${name}' (${description}scope: ${req.requiredBy}), but it is not configured.";
      })
      hmSecrets;
  };
}
