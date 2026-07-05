{
  lib,
  inputs ? {},
  ...
}: rec {
  evalModule = schema: path: let
    exists = builtins.pathExists path;
    _assert =
      if exists
      then true
      else throw "Configuration path '${toString path}' does not exist on disk.";
    cfg =
      (lib.evalModules {
        modules = [schema path];
        specialArgs = {inherit inputs;};
      }).config;
  in
    builtins.seq _assert (cfg // {_path = normalize path;});

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

  extractPath = system: item:
    if lib.isPath item
    then item
    else if lib.isAttrs item && item ? cond && item ? path
    then
      (
        if item.cond system
        then item.path
        else null
      )
    else throw "Invalid module dependency declaration: ${builtins.toJSON item}";

  filterActive = system: items: lib.filter (x: x != null) (map (extractPath system) items);

  resolveModules = system: startingPaths: let
    activeStartingPaths = filterActive system startingPaths;

    resolved = lib.genericClosure {
      startSet =
        map (p: let
          loaded = loadModule p;
        in {
          key = normalize p;
          path = p;
          inherit loaded;
        })
        activeStartingPaths;

      operator = item:
        map (p: let
          loaded = loadModule p;
        in {
          key = normalize p;
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
