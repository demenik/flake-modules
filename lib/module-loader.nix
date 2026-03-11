{lib, ...}: rec {
  getFile = path:
    if builtins.isPath path || builtins.isString path
    then toString path
    else "inline";

  evalModule = schema: path:
    (lib.evalModules {
      modules = [schema path];
    }).config;

  loadHost = path: evalModule ./schemas/host.nix path;
  loadUser = path: evalModule ./schemas/user.nix path;
  loadModule = path: evalModule ./schemas/module.nix path;
}
