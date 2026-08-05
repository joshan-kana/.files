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

  parsedLocks = builtins.fromJSON (builtins.readFile ./container-images.lock);

  # A non-object JSON root is treated as an empty lock so individual container
  # images remain discoverable through placeholders. Invalid JSON syntax may
  # still fail parsing, which is appropriate.
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

  registryContainers = filterAttrs (
    _name: container: container.imageFile == null && container.imageStream == null
  ) config.virtualisation.oci-containers.containers;

  invalidContainers = filterAttrs (
    _name: container: hasSuffix "@${placeholderDigest}" container.image
  ) registryContainers;
in
{
  # Add only `apply` to the upstream OCI-container option. A future upstream
  # `apply` on this option should cause a clear module evaluation conflict.
  options.virtualisation.oci-containers.containers = lib.mkOption {
    apply = mapAttrs pinContainer;
  };

  config.assertions = [
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
