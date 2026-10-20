{ config }:

{
  main = {
    base_url = "http://127.0.0.1:${toString config.services.radarr.settings.server.port}";
    api_key."!env" = "RADARR_API_KEY";
    custom_formats = [
      {
        trash_ids = [ "493b6d1dbec3c3364c59d7607f7e3405" ]; # HDR
        assign_scores_to = [
          {
            name = "Ultra-HD";
            score = 500;
          }
        ];
      }
      {
        trash_ids = [ "b337d6812e06c200ec9a2d3cfa9d20a7" ]; # DV Boost
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
        language = "Original";
        upgrade = {
          allowed = true;
          until_quality = "Remux-2160p";
          until_score = 1000;
        };
        min_format_score = 0;
        qualities = [
          { name = "Remux-2160p"; }
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
            movie_category = "radarr";
          };
        }
      ];
      delete_unmanaged.enabled = false;
    };
  };
}
