{
  lib,
  inputs ? {},
  ...
}: rec {
  evalModule = schema: path: let
    cfg =
      (lib.evalModules {
        modules = [schema path];
        specialArgs = {inherit inputs;};
      }).config;
  in
    cfg // {_path = normalize path;};

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
    resolved = lib.genericClosure {
      startSet =
        map (p: let
          loaded = loadModule p;
        in {
          key = normalize p;
          path = p;
          inherit loaded;
        })
        startingPaths;

      operator = item:
        map (p: let
          loaded = loadModule p;
        in {
          key = normalize p;
          path = p;
          inherit loaded;
        })
        item.loaded.modules;
    };
  in
    map (item: item.loaded) resolved;
}
