{
  lib,
  inputs ? {},
  ...
}: rec {
  evalModule = schema: path:
    (lib.evalModules {
      modules = [schema path];
      specialArgs = {inherit inputs;};
    }).config;

  loadHost = path: evalModule ./schemas/host.nix path;
  loadUser = path: evalModule ./schemas/user.nix path;
  loadModule = path: evalModule ./schemas/module.nix path;
}
