{
  nixpkgs,
  home-manager,
  lib,
  lib-inputs,
  secrets,
  introspection,
  resolveConfig,
}: {
  hostPath,
  userPath,
  inputs,
  extraSpecialArgs ? {},
  extraModules ? [],
}: let
  configData = resolveConfig {
    inherit hostPath inputs;
    userPaths = [userPath];
  };
  inherit (configData) host users modules options;
  user = builtins.elemAt users 0;

  homeOverlays =
    host.overlays.home
    ++ host.overlays.both
    ++ user.overlays.home
    ++ user.overlays.both
    ++ (lib.concatMap (m: m.overlays.home ++ m.overlays.both) modules);

  pkgs = import nixpkgs {
    inherit (host) system;
    overlays = homeOverlays;
  };

  mkModuleWarning = module: let
    baseMsg = "Module '${module.name}' has NixOS configuration, which doesn't get applied in standalone HM mode.";
    instructionMsg =
      if (module.hostInstructions != null)
      then "\nInstructions to replicate:\n${module.hostInstructions}"
      else "";
  in {
    warnings = lib.optional (module.nixos != {}) "${baseMsg}${instructionMsg}";
  };
in
  home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs =
      {
        inherit inputs host user;
        users = [user];
        isStandalone = true;
      }
      // extraSpecialArgs;

    modules =
      [{home.stateVersion = host.hmStateVersion;}]
      # === Module config ===
      ++ options
      ++ (map (m: m.moduleConfig) modules)
      ++ [host.moduleConfig user.moduleConfig]
      # === HM modules ===
      ++ (map (m: m.home) modules)
      ++ [host.homeConfig user.homeConfig]
      # === Secrets ===
      ++ [
        lib-inputs.sops-nix.homeModules.sops
        (secrets.mkHomeConfig {inherit host user modules;})
      ]
      # === HM defaults ===
      ++ [
        (import ../defaults/hm.nix {
          inherit user lib;
          inherit (host) system;
        })
      ]
      # === Introspection ===
      ++ [(introspection.mkHomeIntrospection {inherit host user modules secrets;})]
      # === Warnings ===
      ++ (map mkModuleWarning modules)
      ++ extraModules;
  }
