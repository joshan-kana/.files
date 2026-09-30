_: {
  /**
    Controlled agent tooling exposed from the server.
  */
  agentTools = import ./agent-tools;

  /**
    Attic binary-cache service.
  */
  attic = import ./attic;

  /**
    Gitea Git hosting service.
  */
  gitea = import ./gitea;

  /**
    Native Home Assistant service.
  */
  homeAssistant = import ./home-assistant;

  /**
    Hermes Agent service.
  */
  hermesAgent = import ./hermes-agent;

  /**
    Native Immich media service.
  */
  immich = import ./immich;

  /**
    Matrix bridge services.
  */
  matrix = import ./matrix;

  /**
    Native Matter Server service.
  */
  matterServer = import ./matter-server;

  /**
    n8n workflow automation service.
  */
  n8n = import ./n8n;

  /**
    Private ntfy event-bus service.
  */
  ntfy = import ./ntfy;

  /**
    Authenticated external-event webhook ingress.
  */
  webhook = import ./webhook;

  /**
    OneDev source hosting service.
  */
  onedev = import ./onedev;

  /**
    Native OpenClaw gateway service.
  */
  openclaw = import ./openclaw;

  /**
    Open WebUI service.
  */
  openWebui = import ./open-webui;

  /**
    Native Paperless-ngx document service.
  */
  paperless = import ./paperless;
}
