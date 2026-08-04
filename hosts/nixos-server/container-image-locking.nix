{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mapAttrs
    assertMsg
    concatStringsSep
    attrNames
    hasInfix
    hasSuffix
    ;

  locks = builtins.fromJSON (builtins.readFile ./container-images.lock);

  # Placeholder used when a container's lock is missing, stale, or malformed. The
  # updater discovers the new source through this placeholder; a NixOS assertion
  # below prevents building or deploying with it.
  placeholderDigest = "sha256:0000000000000000000000000000000000000000000000000000000000000000";

  validDigest = digest: builtins.match "sha256:[0-9a-f]{64}" digest != null;

  # Transform one registry-backed container's image from `repository:tag` to
  # `repository:tag@sha256:<digest>`. Locally built/streamed images are untouched.
  pinContainer =
    name: container:
    if container.imageFile != null || container.imageStream != null then
      container
    else
      let
        source = container.image;
        lock = locks.${name} or null;

        lockIsCurrent = lock != null && lock.source == source && validDigest lock.digest;

        digest = if lockIsCurrent then lock.digest else placeholderDigest;
      in
      assert assertMsg (!hasInfix "@" source)
        "Container '${name}' must declare an unpinned repository:tag source; its digest is managed by container-images.lock";
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
  # Add only an `apply` transformation to the upstream OCI-container option, so it
  # runs after every container definition across the whole module graph has merged.
  # This relies on the upstream option not already defining its own `apply`. If
  # Nixpkgs later adds one to the same option, module evaluation should fail
  # clearly rather than silently conflict; `nix flake check` and server evaluation
  # must catch that during a reviewed Nixpkgs update.
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
