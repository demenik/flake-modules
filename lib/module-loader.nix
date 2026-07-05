{
  lib,
  inputs ? {},
  ...
}: rec {
  getModuleKey = moduleSource:
    if lib.isPath moduleSource || builtins.isString moduleSource
    then normalize moduleSource
    else let
      cfg =
        (lib.evalModules {
          modules = [./schemas/module.nix moduleSource];
          specialArgs = {inherit inputs;};
        }).config;
    in
      if cfg ? name && cfg.name != "unknown-module"
      then "external:${cfg.name}"
      else throw "External module imported from an attribute set or function must define a unique 'name' attribute.";

  evalModule = schema: moduleSource: let
    isPath = lib.isPath moduleSource || builtins.isString moduleSource;
    exists =
      if isPath
      then builtins.pathExists moduleSource
      else true;
    _assert =
      if exists
      then true
      else throw "Configuration path '${toString moduleSource}' does not exist on disk.";
    cfg =
      (lib.evalModules {
        modules = [schema moduleSource];
        specialArgs = {inherit inputs;};
      }).config;
    pathKey = getModuleKey moduleSource;
  in
    builtins.seq _assert (cfg // {_path = pathKey;});

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

  extractPath = system: item: let
    isConditional = lib.isAttrs item && item ? cond && item ? path;
  in
    if isConditional
    then
      (
        if item.cond system
        then item.path
        else null
      )
    else item;

  filterActive = system: items: lib.filter (x: x != null) (map (extractPath system) items);

  resolveModules = system: startingPaths: let
    activeStartingPaths = filterActive system startingPaths;

    resolved = lib.genericClosure {
      startSet =
        map (p: let
          loaded = loadModule p;
        in {
          key = loaded._path;
          path = p;
          inherit loaded;
        })
        activeStartingPaths;

      operator = item:
        map (p: let
          loaded = loadModule p;
        in {
          key = loaded._path;
          path = p;
          inherit loaded;
        })
        (filterActive system item.loaded.modules);
    };

    checkDuplicateNames = let
      grouped = lib.groupBy (m: m.name) (map (item: item.loaded) resolved);
      duplicates = lib.filterAttrs (name: ms: lib.length ms > 1 && name != "unknown-module") grouped;
    in
      if duplicates != {}
      then let
        dupInfo = lib.concatStringsSep "\n" (lib.mapAttrsToList (
            name: ms: "- Module '${name}' is defined in multiple files: ${lib.concatStringsSep ", " (map (m: m._path) ms)}"
          )
          duplicates);
      in
        throw "Duplicate module names detected:\n${dupInfo}"
      else true;

    checkedResolved =
      if checkDuplicateNames
      then resolved
      else [];
  in
    map (item: item.loaded) checkedResolved;
}
