{
  nixpkgs,
  home-manager,
  lib,
}: let
  builders = import ./builders.nix {
    inherit nixpkgs home-manager lib;
  };
  discovery = import ./discovery.nix {
    inherit nixpkgs lib;
    inherit (builders) mkHost mkHome;
  };
in {
  inherit (builders) mkHost mkHome;
  inherit (discovery) mkNixosConfigurations mkHomeConfigurations;
}
