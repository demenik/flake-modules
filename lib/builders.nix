{
  nixpkgs,
  home-manager,
  lib,
  lib-inputs,
  ...
}: let
  secrets = import ./secrets.nix {inherit lib;};

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
in {
  mkHost = {
    hostPath,
    inputs,
    extraSpecialArgs ? {},
    extraModules ? [],
  }: let
    configData = resolveConfig {inherit hostPath inputs;};
    inherit (configData) host users modules options loader;

    nixosOverlays =
      if host.useGlobalPkgs
      then
        host.overlays.nixos
        ++ host.overlays.home
        ++ host.overlays.both
        ++ (lib.concatMap (u: u.overlays.nixos ++ u.overlays.home ++ u.overlays.both) users)
        ++ (lib.concatMap (m: m.overlays.nixos ++ m.overlays.home ++ m.overlays.both) modules)
      else
        host.overlays.nixos
        ++ host.overlays.both
        ++ (lib.concatMap (u: u.overlays.nixos ++ u.overlays.both) users)
        ++ (lib.concatMap (m: m.overlays.nixos ++ m.overlays.both) modules);
  in
    nixpkgs.lib.nixosSystem {
      inherit (host) system;
      specialArgs = {inherit inputs host users;} // extraSpecialArgs;

      modules =
        [{system.stateVersion = host.stateVersion;}]
        # === Module config ===
        ++ options
        ++ (map (m: m.moduleConfig) modules)
        ++ [host.moduleConfig]
        ++ (map (u: u.moduleConfig) users)
        # === NixOS modules ===
        ++ (map (m: m.nixos) modules)
        ++ [host.nixosConfig]
        ++ (map (u: u.nixosConfig) users)
        # === NixOS overlays ===
        ++ [{nixpkgs.overlays = nixosOverlays;}]
        # === Hostname ===
        ++ lib.optional (host.hostname != null) {networking.hostName = lib.mkDefault host.hostname;}
        # === Secrets ===
        ++ [
          lib-inputs.sops-nix.nixosModules.sops
          (secrets.mkNixosConfig {inherit host users modules;})
        ]
        # === NixOS defaults ===
        ++ (map (user: import ./defaults/nixos-user.nix {inherit user lib;}) users)
        # === Home-Manager ===
        ++ [
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              inherit (host) useGlobalPkgs;
              useUserPackages = true;
              extraSpecialArgs =
                {
                  inherit inputs host users;
                  isStandalone = false;
                }
                // extraSpecialArgs;
            };

            home-manager.users = lib.listToAttrs (
              map (user: let
                modulesByPath = lib.listToAttrs (map (m: {
                    name = m._path;
                    value = m;
                  })
                  modules);

                userModuleClosure = lib.genericClosure {
                  startSet = map (p: {
                    key = loader.normalize p;
                    path = p;
                  }) (loader.filterActive host.system (host.modules ++ user.modules));
                  operator = item:
                    map (p: {
                      key = loader.normalize p;
                      path = p;
                    }) (loader.filterActive host.system (modulesByPath.${item.key}.modules or []));
                };

                userModules = map (item: modulesByPath.${item.key}) userModuleClosure;
                userOverlays =
                  host.overlays.home
                  ++ host.overlays.both
                  ++ user.overlays.home
                  ++ user.overlays.both
                  ++ (lib.concatMap (m: m.overlays.home ++ m.overlays.both) userModules);
              in {
                name = user.username;
                value.imports =
                  [{home.stateVersion = host.hmStateVersion;}]
                  # === Module config ===
                  ++ (
                    map (m: {
                      _file = "moduleOptions in '${m.name}'";
                      options = m.moduleOptions;
                    })
                    userModules
                  )
                  ++ (map (m: m.moduleConfig) userModules)
                  ++ [host.moduleConfig user.moduleConfig]
                  # === HM modules ===
                  ++ (map (m: m.home) userModules)
                  ++ [host.homeConfig user.homeConfig]
                  # === HM overlays ===
                  ++ lib.optional (!host.useGlobalPkgs) {nixpkgs.overlays = userOverlays;}
                  # === Secrets ===
                  ++ [
                    lib-inputs.sops-nix.homeModules.sops
                    (secrets.mkHomeConfig {
                      inherit host user;
                      modules = userModules;
                    })
                  ]
                  # === HM defaults ===
                  ++ [
                    (import ./defaults/hm.nix {
                      inherit user lib;
                      inherit (host) system;
                    })
                  ];
              })
              users
            );
          }
        ]
        ++ extraModules;
    };

  mkHome = {
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
          (import ./defaults/hm.nix {
            inherit user lib;
            inherit (host) system;
          })
        ]
        # === Warnings ===
        ++ (map mkModuleWarning modules)
        ++ extraModules;
    };
}
