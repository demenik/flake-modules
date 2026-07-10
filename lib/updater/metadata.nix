{
  lib,
  pkgs,
  overlays,
  repoRoot,
}: let
  evalOverlay = overlay: let
    final = pkgs // (overlay final pkgs);
    res = overlay final pkgs;
  in
    builtins.tryEval res;

  tryGetFetcherInfo = val:
    if !lib.isDerivation val
    then null
    else if val ? src && lib.isDerivation val.src
    then tryGetFetcherInfo val.src
    else if val ? rev && (val ? outputHash || val ? hash)
    then {
      inherit (val) rev;
      hash = val.outputHash or val.hash;
      url = val.url or null;
      owner = val.owner or null;
      repo = val.repo or null;
      leaveDotGit = val.leaveDotGit or false;
      deepClone = val.deepClone or false;
      fetchSubmodules = val.fetchSubmodules or val.gitSubmodules or false;
      sparseCheckout = val.sparseCheckout or null;
    }
    else null;

  extractAttrs = path: prevSet: finalSet: let
    keys = builtins.attrNames finalSet;
  in
    lib.flatten (map (
        name: let
          pos = builtins.unsafeGetAttrPos name finalSet;
          isLocal = pos != null && lib.hasPrefix repoRoot pos.file;
        in
          if isLocal
          then let
            resTry = builtins.tryEval (
              let
                val = finalSet.${name};
                prevVal =
                  if builtins.isAttrs prevSet
                  then (prevSet.${name} or null)
                  else null;
                isDifferent = prevVal == null || val != prevVal;
              in
                if isDifferent
                then let
                  fullName =
                    if path == ""
                    then name
                    else "${path}.${name}";
                in
                  if lib.isDerivation val
                  then let
                    fetcherInfo = tryGetFetcherInfo val;
                  in
                    if fetcherInfo != null
                    then [
                      {
                        name = fullName;
                        inherit (pos) file line column;
                        inherit (fetcherInfo) rev hash url owner repo leaveDotGit deepClone fetchSubmodules sparseCheckout;
                      }
                    ]
                    else []
                  else if builtins.isAttrs val && !lib.isDerivation val
                  then
                    extractAttrs fullName (
                      if builtins.isAttrs prevVal && !lib.isDerivation prevVal
                      then prevVal
                      else {}
                    )
                    val
                  else []
                else []
            );
          in
            if resTry.success
            then resTry.value
            else []
          else []
      )
      keys);

  extractOverlayMetadata = overlay: let
    evalRes = evalOverlay overlay;
  in
    if evalRes.success
    then extractAttrs "" pkgs evalRes.value
    else [];
in
  lib.flatten (map extractOverlayMetadata overlays)
