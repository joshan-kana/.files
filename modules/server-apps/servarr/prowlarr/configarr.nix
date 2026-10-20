{ config }:

{
  main = {
    base_url = "http://127.0.0.1:${toString config.services.prowlarr.settings.server.port}";
    api_key."!env" = "PROWLARR_API_KEY";
    indexers = {
      data = [
        {
          name = "Knaben";
          definition = "Knaben";
          enable = true;
        }
        {
          name = "LimeTorrents";
          definition = "limetorrents";
          enable = true;
        }
        {
          name = "Nyaa.si";
          definition = "nyaasi";
          enable = true;
        }
        {
          name = "YTS";
          definition = "yts";
          enable = true;
        }
      ];
      delete_unmanaged.enabled = false;
    };
    applications = {
      data = [
        {
          name = "Sonarr";
          type = "Sonarr";
          sync_level = "fullSync";
          fields = {
            prowlarrUrl = "http://localhost:${toString config.services.prowlarr.settings.server.port}";
            baseUrl = "http://localhost:${toString config.services.sonarr.settings.server.port}";
            apiKey."!env" = "SONARR_API_KEY";
          };
        }
        {
          name = "Radarr";
          type = "Radarr";
          sync_level = "fullSync";
          fields = {
            prowlarrUrl = "http://localhost:${toString config.services.prowlarr.settings.server.port}";
            baseUrl = "http://localhost:${toString config.services.radarr.settings.server.port}";
            apiKey."!env" = "RADARR_API_KEY";
          };
        }
      ];
      delete_unmanaged.enabled = false;
      sync_indexers = false;
    };
  };
}
