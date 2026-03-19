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

  resolveModules = startingPaths: let
    resolvedPaths = map (item: item.path) (
      lib.genericClosure {
        startSet =
          map (p: {
            key = toString p;
            path = p;
          })
          startingPaths;

        operator = item:
          map (p: {
            key = toString p;
            path = p;
          })
          (loadModule item.path).modules;
      }
    );
  in
    map loadModule resolvedPaths;
}
