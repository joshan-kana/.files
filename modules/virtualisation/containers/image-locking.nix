{ lockFile }:
{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    assertMsg
    attrNames
    concatStringsSep
    filterAttrs
    hasInfix
    hasSuffix
    mapAttrs
    ;

  scopeEnabled = path: lib.attrByPath (path ++ [ "enable" ]) null config.dotfiles.scopes != false;
  enabled =
    scopeEnabled [ "virtualisation" ]
    && scopeEnabled [
      "virtualisation"
      "containers"
    ]
    && scopeEnabled [
      "virtualisation"
      "containers"
      "imageLocking"
    ];

  parsedLocks = builtins.fromJSON (builtins.readFile lockFile);
  locks = if builtins.isAttrs parsedLocks then parsedLocks else { };

  placeholderDigest = "sha256:0000000000000000000000000000000000000000000000000000000000000000";

  validDigest =
    digest: builtins.isString digest && builtins.match "sha256:[0-9a-f]{64}" digest != null;

  pinContainer =
    name: container:
    if container.imageFile != null || container.imageStream != null then
      container
    else
      let
        source = container.image;
        lock = locks.${name} or null;
        lockIsCurrent =
          builtins.isAttrs lock
          && lock ? source
          && builtins.isString lock.source
          && lock.source == source
          && lock ? digest
          && validDigest lock.digest;
        digest = if lockIsCurrent then lock.digest else placeholderDigest;
      in
      assert assertMsg (source != "" && !hasInfix "@" source)
        "Container '${name}' must declare a non-empty repository:tag source without a digest; its digest is managed by container-images.lock";
      container
      // {
        image = "${source}@${digest}";
      };

  applyLocks = containers: if enabled then mapAttrs pinContainer containers else containers;

  registryContainers = filterAttrs (
    _name: container: container.imageFile == null && container.imageStream == null
  ) config.virtualisation.oci-containers.containers;

  invalidContainers = filterAttrs (
    _name: container: hasSuffix "@${placeholderDigest}" container.image
  ) registryContainers;
in
{
  # Extend the upstream OCI-container option without replacing its schema.
  options.virtualisation.oci-containers.containers = lib.mkOption {
    apply = applyLocks;
  };

  config.assertions = lib.optionals enabled [
    {
      assertion = invalidContainers == { };
      message = ''
        Container image locks are missing, stale, or malformed:

        ${concatStringsSep "\n" (map (name: "  - ${name}") (attrNames invalidContainers))}

        Run:
          sysfu server --containers-only

        Or refresh selected containers with:
          sysfu server --container <name>
      '';
    }
  ];
}
