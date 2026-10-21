# Platforms

**Convention:** Share behavior across NixOS, nix-darwin, and Home Manager where supported; make OS and architecture restrictions explicit and local.

## Prefer current capabilities over assumptions

Inspect the actual package and native-option support. Use `lib.systems.elaborate system` when the module supplies a system argument, and `isLinux` or `isDarwin` to express platform-specific attribute trees.

- `lib.optionalAttrs isLinux`: Linux-only settings.
- `lib.optionalAttrs isDarwin`: Darwin-only native integrations.
- `lib.optionals isLinux`: Linux-only list items.
- Ordinary `if`: meaningful alternative values.
- Explicit system allowlists: binaries only published for particular architectures.

The same semantic owner may map to different native option schemas on each OS. Preserve that distinction without inventing an ersatz common module API.

## Host exceptions

Hardware, VM network topology, packages, and recovery paths can justify host-local changes. For example, the Parallels ARM VM uses shared/NAT networking and Tailscale for normal remote access; do not introduce bridged LAN networking as a generic DNS fix.

A package available on one platform does not necessarily imply its associated graphical session, systemd integration, or service should be enabled there.

## Verification

Evaluate every affected host. Build architecture-specific packages on a compatible builder when packaging changes. An x86-64 `nix flake check` may omit aarch64 and Darwin systems; explicitly distinguish evaluated outputs from builds and live deployments.

**Exception:** A host-specific service or hardware driver need not become a cross-platform module just because Nix can evaluate part of it.
