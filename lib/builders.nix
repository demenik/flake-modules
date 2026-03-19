{
  nixpkgs,
  home-manager,
  lib,
  lib-inputs,
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

    hostModules = loader.resolveModules host.modules;
    modulePaths = host.modules ++ (lib.flatten (map (u: u.modules) users));
    modules = loader.resolveModules modulePaths;

    options = map (m: {options = m.moduleOptions;}) modules;
  in
    nixpkgs.lib.nixosSystem {
      inherit (host) system;
      specialArgs = {inherit inputs host;};

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
        # === Secrets ===
        ++ [
          lib-inputs.sops-nix.nixosModules.sops
          (secrets.mkNixosConfig {inherit host modules;})
        ]
        # === NixOS defaults ===
        ++ (map (user: import ./defaults/nixos-user.nix {inherit user lib;}) users)
        # === Home-Manager ===
        ++ [
          home-manager.nixosModules.home-manager
          {
            home-manager.users = lib.listToAttrs (
              map (user: let
                userModules = loader.resolveModules user.modules;
              in {
                name = user.username;
                value.imports =
                  [{home.stateVersion = host.hmStateVersion;}]
                  # === Module config ===
                  ++ options
                  ++ (map (m: m.moduleConfig) hostModules)
                  ++ (map (m: m.moduleConfig) userModules)
                  ++ [host.moduleConfig user.moduleConfig]
                  # === HM modules ===
                  ++ (map (m: m.home) hostModules)
                  ++ (map (m: m.home) userModules)
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

    modulePaths = host.modules ++ user.modules;
    modules = loader.resolveModules modulePaths;

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
        ++ (map mkModuleWarning modules);
    };
}
