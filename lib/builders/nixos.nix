{
  nixpkgs,
  home-manager,
  lib,
  lib-inputs,
  secrets,
  introspection,
}: {
  inputs,
  extraSpecialArgs,
  extraModules,
  configData,
  ...
}: let
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
      ++ (map (user: import ../defaults/nixos-user.nix {inherit user lib;}) users)
      # === Introspection ===
      ++ [(introspection.mkNixosIntrospection {inherit host users modules secrets;})]
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
                  key = loader.getModuleKey p;
                  path = p;
                }) (loader.filterActive host.system (host.modules ++ user.modules));
                operator = item:
                  map (p: {
                    key = loader.getModuleKey p;
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
                  (import ../defaults/hm.nix {
                    inherit user lib;
                    inherit (host) system;
                  })
                ]
                # === Introspection ===
                ++ [
                  (introspection.mkHomeIntrospection {
                    inherit host user secrets;
                    modules = userModules;
                  })
                ];
            })
            users
          );
        }
      ]
      ++ extraModules;
  }
