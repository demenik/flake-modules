{lib, ...}: rec {
  getDeclaredSecrets = modules: lib.foldl (acc: m: acc // m.secrets) {} modules;

  mkNixosConfig = {
    host,
    modules,
  }: let
    declaredSecrets = getDeclaredSecrets modules;
  in {
    sops = {
      age.sshKeyPaths = lib.mkDefault ["/etc/ssh/ssh_host_ed25519_key"];
      secrets = lib.mapAttrs (n: v: {sopsFile = v.path;}) host.secrets;
    };

    assertions =
      lib.mapAttrsToList (name: req: let
        description =
          if req.description != null
          then " (${req.description})"
          else "";
      in {
        assertion = (!req.required) || (host.secrets ? ${name});
        message = "NixOS: Module requires the secret '${name}'${description}, but it is not configured.";
      })
      declaredSecrets;
  };

  mkHomeConfig = {
    host,
    user,
    modules,
  }: let
    declaredSecrets = getDeclaredSecrets modules;
    resolvedSecrets = host.secrets // user.secrets;

    defaultSshKey =
      if host.system == "x86_64-darwin" || host.system == "aarch64-darwin"
      then "/Users/${user.username}/.ssh/id_ed25519"
      else "/home/${user.username}/.ssh/id_ed25519";
  in {
    sops = {
      age.sshKeyPaths = lib.mkDefault [defaultSshKey];
      secrets = lib.mapAttrs (n: v: {sopsFile = v.path;}) resolvedSecrets;
    };

    assertions =
      lib.mapAttrsToList (name: req: let
        description =
          if req.description != null
          then " (${req.description})"
          else "";
      in {
        assertion = (!req.required) || (resolvedSecrets ? ${name});
        message = "HM (${user.username}): Module requires the secret '${name}'${description}, but it is not configured.";
      })
      declaredSecrets;
  };
}
