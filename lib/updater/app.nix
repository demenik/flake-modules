{
  lib,
  discoverHostsInDir,
}: {
  pkgs,
  hostsDir ? null,
  hosts ? {},
  inputs,
  appName ? "overlay-update",
}: let
  loader = import ../module-loader.nix {inherit lib inputs;};
  discoveredHosts = discoverHostsInDir hostsDir;
  allHosts = discoveredHosts // hosts;

  allOverlays =
    lib.flatten
    (
      lib.mapAttrsToList (
        hostName: hostPath: let
          host = loader.loadHost hostPath;
          users = map loader.loadUser host.users;
          modulePaths = host.modules ++ (lib.flatten (map (u: u.modules) users));
          modules = loader.resolveModules host.system modulePaths;
        in
          host.overlays.nixos
          ++ host.overlays.home
          ++ host.overlays.both
          ++ (lib.concatMap (u: u.overlays.nixos ++ u.overlays.home ++ u.overlays.both) users)
          ++ (lib.concatMap (m: m.overlays.nixos ++ m.overlays.home ++ m.overlays.both) modules)
      )
      allHosts
    );

  updaterMetadata = import ./metadata.nix {
    inherit lib pkgs;
    overlays = allOverlays;
    repoRoot = toString inputs.self.outPath;
  };

  overlayUpdatePkg = import ./default.nix {
    inherit pkgs appName;
  };
  overlayUpdatePkgWithMetadata =
    pkgs.runCommand "${appName}-wrapped" {
      metadataJson = builtins.toJSON updaterMetadata;
    } ''
      mkdir -p $out/bin
      ln -s ${overlayUpdatePkg}/bin/${appName} $out/bin/${appName}
      echo -n "$metadataJson" > $out/metadata.json
    '';
in {
  type = "app";
  program = "${overlayUpdatePkgWithMetadata}/bin/${appName}";
}
