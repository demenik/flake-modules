{
  nixpkgs,
  home-manager,
  lib,
  ...
}: let
  secrets = import ./secrets.nix {inherit lib;};
in {
  mkHost = {
    hostPath,
    inputs,
  }: let
    loader = import ./module-loader.nix {inherit lib;};

    host = loader.loadHost hostPath;
    users = map loader.loadUser host.users;

    hostModules = map loader.loadModule host.modules;
    userModules = lib.flatten (map (u: map loader.loadModule u.modules) users);
    modules = hostModules ++ userModules;

    options = map (m: {options = m.moduleOptions;}) modules;
  in
    nixpkgs.lib.nixosSystem {
      inherit (host) system;
      specialArgs = {inherit inputs host;};

      modules =
        [{system.stateVersion = host.stateVersion;}]
        # === Module config ===
        ++ options
        ++ [host.moduleConfig]
        ++ (map (u: u.moduleConfig) users)
        # === NixOS modules ===
        ++ (map (m: m.nixos) modules)
        ++ [host.nixosConfig]
        ++ (map (u: u.nixosConfig) users)
        # === Secrets ===
        ++ [
          inputs.sops-nix.nixosModules.sops
          (secrets.mkNixosConfig {inherit host modules;})
        ]
        # === NixOS defaults ===
        ++ (map (user: import ./defaults/nixos-user.nix {inherit user lib;}) users)
        # === Home-Manager ===
        ++ [
          home-manager.nixosModules.home-manager
          {
            home-manager.users = lib.listToAttrs (
              map (user: {
                name = user.username;
                value.imports =
                  [{home.stateVersion = host.hmStateVersion;}]
                  # === Module config ===
                  ++ options
                  ++ [host.moduleConfig user.moduleConfig]
                  # === HM modules ===
                  ++ (map (m: m.home) hostModules)
                  ++ (map (m: m.home) (map loader.loadModule user.modules))
                  ++ [host.homeConfig user.homeConfig]
                  # === Secrets ===
                  ++ [
                    inputs.sops-nix.homeModules.sops
                    (secrets.mkHomeConfig {inherit host user modules;})
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
        ];
    };

  mkHome = {
    hostPath,
    userPath,
    inputs,
  }: let
    loader = import ./module-loader.nix {inherit lib;};

    host = loader.loadHost hostPath;
    user = loader.loadUser userPath;

    pkgs = nixpkgs.legacyPackages.${host.system};

    hostModules = map loader.loadModule host.modules;
    userModules = map loader.loadModule user.modules;
    modules = hostModules ++ userModules;

    options = map (m: {options = m.moduleOptions;}) modules;

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
      extraSpecialArgs = {inherit inputs host user;};

      modules =
        [{home.stateVersion = host.hmStateVersion;}]
        # === Module config ===
        ++ options
        ++ [host.moduleConfig user.moduleConfig]
        # === HM modules ===
        ++ (map (m: m.home) modules)
        ++ [host.homeConfig user.homeConfig]
        # === Secrets ===
        ++ [
          inputs.sops-nix.homeModules.sops
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
        ++ (map mkModuleWarning modules);
    };
}
