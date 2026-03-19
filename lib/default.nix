{
  nixpkgs,
  home-manager,
  lib,
  lib-inputs,
}: let
  builders = import ./builders.nix {
    inherit nixpkgs home-manager lib lib-inputs;
  };
  discovery = import ./discovery.nix {
    inherit nixpkgs lib;
    inherit (builders) mkHost mkHome;
  };
in {
  inherit (builders) mkHost mkHome;
  inherit (discovery) mkNixosConfigurations mkHomeConfigurations;
}
