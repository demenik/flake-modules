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

  normalize = p: let
    s = toString p;
    s1 =
      if lib.hasSuffix "/" s
      then lib.removeSuffix "/" s
      else s;
  in
    if lib.hasSuffix "/default.nix" s1
    then lib.removeSuffix "/default.nix" s1
    else s1;

  resolveModules = startingPaths: let
    resolvedPaths = map (item: item.path) (
      lib.genericClosure {
        startSet =
          map (p: {
            key = normalize p;
            path = p;
          })
          startingPaths;

        operator = item:
          map (p: {
            key = normalize p;
            path = p;
          })
          (loadModule item.path).modules;
      }
    );
  in
    map loadModule resolvedPaths;
}
