_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        # Temporary until nixpkgs carries MCP Python SDK v2.
        chatgpt-shell-mcp-python =
          final.callPackage
            (
              { python }:
              let
                ps = python.pkgs;

                wheel =
                  {
                    pname,
                    version,
                    hash,
                    dependencies ? [ ],
                    pypiName ? pname,
                  }:
                  ps.buildPythonPackage {
                    inherit pname version dependencies;
                    format = "wheel";
                    src = ps.fetchPypi {
                      pname = pypiName;
                      inherit version hash;
                      format = "wheel";
                      dist = "py3";
                      python = "py3";
                    };
                    doCheck = false;
                  };

                truststore = wheel {
                  pname = "truststore";
                  version = "0.10.4";
                  hash = "sha256-ra6uzxy7X03jsZWbQtQfb6tXsrFmattZ6JywtTNh2YE=";
                };

                idna = wheel {
                  pname = "idna";
                  version = "3.18";
                  hash = "sha256-f5UsvnILaIBV4/h94U9cPl/aqLw5KJhcQHfKaJ3oSaI=";
                };

                anyio = wheel {
                  pname = "anyio";
                  version = "4.13.0";
                  hash = "sha256-CLMQ+eJKlZQYb9dbT3P0pBUgaeOFPx7Yv79YNp9K1wg=";
                  dependencies = [ idna ];
                };

                starlette = wheel {
                  pname = "starlette";
                  version = "1.3.1";
                  hash = "sha256-xzcqrhHDw/JqQt971ibOwvR9A0g9Jh02lRamFaU3FMY=";
                  dependencies = [ anyio ];
                };
              in
              python.withPackages (_: [
                (wheel {
                  pname = "mcp";
                  version = "2.0.0";
                  hash = "sha256-HLTHXS0se4wddWNV5dgqOfKCLMfxPiKiBR18o1kjSdY=";
                  dependencies = [
                    anyio
                    ps.cryptography
                    (wheel {
                      pname = "httpx2";
                      version = "2.5.0";
                      hash = "sha256-PS1NnPS2HxofRqlZR8/bR+gMtWovkcYlasj1jkiR30E=";
                      dependencies = [
                        anyio
                        (wheel {
                          pname = "httpcore2";
                          version = "2.5.0";
                          hash = "sha256-XONRiN5GHTHo0AC/uO+L8ixsFlh6IR5Vcd6qXpvfhCo=";
                          dependencies = [
                            ps.h11
                            truststore
                          ];
                        })
                        idna
                        truststore
                      ];
                    })
                    ps.jsonschema
                    (wheel {
                      pname = "mcp-types";
                      pypiName = "mcp_types";
                      version = "2.0.0";
                      hash = "sha256-ay3nl8onl/Vot5Up4bJZSONN5RG8wL2C/vEDmm0bjrA=";
                      dependencies = [
                        ps.pydantic
                        ps.typing-extensions
                      ];
                    })
                    ps.opentelemetry-api
                    ps.pydantic
                    ps.pyjwt
                    ps.python-multipart
                    (wheel {
                      pname = "sse-starlette";
                      pypiName = "sse_starlette";
                      version = "3.2.0";
                      hash = "sha256-WHaVS9UZIPws1Ruu5HoIDriKN7W3hOYVq7Cyg/gBzb8=";
                      dependencies = [
                        anyio
                        starlette
                      ];
                    })
                    starlette
                    ps.typing-extensions
                    ps.typing-inspection
                    ps.uvicorn
                  ];
                })
              ])
            )
            {
              python = final.python3;
            };
      }
    )
  ];
}
