{lib}:
with lib; {
  overlaySubmodule = types.submodule {
    options = {
      nixos = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "List of overlays applied to the NixOS packages set.";
      };
      home = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "List of overlays applied to the Home Manager packages set.";
      };
      both = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "List of overlays applied to both NixOS and Home Manager packages sets.";
      };
    };
  };

  secretBindingSubmodule = types.submodule {
    options = {
      path = mkOption {
        type = types.path;
        description = "Path to the sops-encrypted file containing this secret.";
      };
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Key name inside the sops file to extract. Defaults to the secret name.";
      };
      decryptedPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override the default path where the decrypted secret is written.";
      };
      mode = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Permissions mode of the decrypted secret file (e.g. '0400').";
      };
      owner = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Owner of the decrypted secret file.";
      };
      group = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Group of the decrypted secret file.";
      };
      restartUnits = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Systemd units to restart when the secret changes.";
      };
    };
  };

  modulesType = types.listOf (types.either (types.either types.path types.raw) (types.submodule {
    options = {
      path = mkOption {
        type = types.either types.path types.raw;
        description = "Path or raw configuration of the imported module.";
      };
      cond = mkOption {
        type = types.raw;
        description = "Condition predicate function taking system string.";
      };
    };
  }));
}
