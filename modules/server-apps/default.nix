_: {
  /**
    Shared tooling that exposes controlled agent capabilities from the server.
  */
  agentTools = import ./agent-tools;

  /**
    Attic binary-cache service and storage integration.
  */
  attic = import ./attic;

  /**
    Git hosting service and its persistent server state.
  */
  gitea = import ./gitea;

  /**
    Native Home Assistant service, LAN integration, and persistent automation state.
  */
  homeAssistant = import ./home-assistant;

  /**
    Hermes Agent service integration.
  */
  hermesAgent = import ./hermes-agent;

  /**
    Native Immich deployment.

    Bulk media and generated assets live on the Vault while database state is
    protected through logical backups. Existing media can remain in place as an
    external library rather than being copied into application storage.

    External-library registration is application-managed state rather than a
    Nix interface. The existing library is registered at `/srv/vault/media-library`;
    recreate that registration after a fresh application database before starting
    its scan. Initial thumbnail, metadata, face, search, and video processing can
    be CPU-intensive.

    Recovery requires compatible media and database state. A NixOS generation
    rollback is not a database downgrade mechanism after an application migration.
  */
  immich = import ./immich;

  /**
    Matrix bridge services and their persistent state.
  */
  matrix = import ./matrix;

  /**
    Native Matter Server service with persistent state and local discovery support.
  */
  matterServer = import ./matter-server;

  /**
    n8n workflow automation and its persistent application state.
  */
  n8n = import ./n8n;

  /**
    Private ntfy event bus used by infrastructure services on the LAN/Tailnet.

    Topics are application-owned interfaces. The service itself owns persistence,
    authentication, and LAN firewall exposure; individual event integrations stay
    with the application that publishes or consumes them.
  */
  ntfy = import ./ntfy;

  /**
    Loopback webhook receiver and Tailscale Funnel ingress for authenticated
    external events.

    Hook definitions belong to the application being triggered rather than to the
    shared ingress service, so adding an event source does not turn this scope into
    a central workflow registry.
  */
  webhook = import ./webhook;

  /**
    OneDev source hosting and development service.
  */
  onedev = import ./onedev;

  /**
    OpenClaw container and its host integration.

    Repository access, local-model connectivity, credentials, and provider
    routing are expressed by the module itself. Runtime secrets remain outside
    the Nix store and are supplied through service credentials/environment files.

    Host administration and repository operations deliberately cross the
    container boundary through dedicated wrappers. Those wrappers preserve
    ownership and provide a stable interface; they are not a security boundary
    against the OpenClaw workload.

    Local Ollama access uses a loopback nginx endpoint. A timer selects the Mac's
    reachable LAN address first and a numeric Tailscale fallback otherwise, so
    nginx does not depend on mDNS remaining resolvable during reloads.

    OpenRouter provider lanes use independently scoped credentials and no
    automatic fallback between privacy classes. Free-provider lanes are for
    non-sensitive prompts only.
  */
  openclaw = import ./openclaw;

  /**
    Open WebUI service and local model integration.
  */
  openWebui = import ./open-webui;

  /**
    Native Paperless-ngx deployment.

    Document media belongs on bulk storage while smaller application state and
    logical database backups participate in the normal application-data backup.
    The consume directory is an inbox, not the authoritative document archive.

    Create the initial application user with `paperless-manage createsuperuser`.
    A complete recovery requires both document media and compatible application
    database state.
  */
  paperless = import ./paperless;
}
