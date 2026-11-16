# Platforms

Share behavior across supported operating systems and architectures, but do not assume a compatible package implies compatible service, option, or desktop support.

## Platform boundaries

Inspect package availability, native module interfaces, and runtime requirements for each target system. Use system metadata and explicit conditions to exclude unsupported declarations.

Keep OS-specific native options within the matching platform branch. Use architecture allowlists when a publisher supports only certain systems. Share data across differing option schemas instead of fabricating a universal native module interface.

## Host exceptions

Hardware dependencies, virtualization limitations, and host-only services justify local differences. Keep these within the relevant host's semantic scope rather than imposing them globally.

Evaluate every affected host. Build packages on compatible target systems where architecture matters, and distinguish evaluation from builds and runtime verification. A check executed on one architecture does not prove the others work.
