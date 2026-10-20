{ config }:

{
  main = {
    base_url = "http://127.0.0.1:${toString config.services.sonarr.settings.server.port}";
    api_key."!env" = "SONARR_API_KEY";
    custom_formats = [
      {
        trash_ids = [ "505d871304820ba7106b693be6fe4a9e" ]; # HDR
        assign_scores_to = [
          {
            name = "Ultra-HD";
            score = 500;
          }
        ];
      }
      {
        trash_ids = [ "7c3a61a9c6cb04f52f1544be6d44a026" ]; # DV Boost
        assign_scores_to = [
          {
            name = "Ultra-HD";
            score = 1000;
          }
        ];
      }
    ];
    quality_profiles = [
      {
        name = "Ultra-HD";
        upgrade = {
          allowed = true;
          until_quality = "Bluray-2160p";
          until_score = 1000;
        };
        min_format_score = 0;
        qualities = [
          { name = "Bluray-2160p"; }
          {
            name = "WEB 2160p";
            qualities = [
              "WEBDL-2160p"
              "WEBRip-2160p"
            ];
          }
          { name = "HDTV-2160p"; }
        ];
      }
    ];
    download_clients = {
      data = [
        {
          name = "Transmission";
          type = "transmission";
          enable = true;
          fields = {
            host = "localhost";
            port = config.services.transmission.settings.rpc-port;
            username = "media";
            password."!env" = "TRANSMISSION_RPC_PASSWORD";
            tv_category = "sonarr";
          };
        }
      ];
      delete_unmanaged.enabled = false;
    };
  };
}
