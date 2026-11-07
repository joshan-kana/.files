_: {
  nixpkgs.overlays = [
    (final: _prev: {
      hypr-persist = final.rustPlatform.buildRustPackage rec {
        pname = "hypr-persist";
        version = "0.1.2";

        src = final.fetchFromGitHub {
          owner = "ngamber";
          repo = "hypr-persist";
          rev = "31836057e09b46d8d32645dbb75035f31164dd5f";
          hash = "sha256-Nh2+JpQQW6qi2ULUGjJyqhN8/3AKRHjlpHOXiVeD6h0=";
        };

        cargoHash = "sha256-OYJNkWU9Tfx/ZDlO0kfy9sqE0i1YsB9Dy5GR29IAtMI=";
        patches = [
          ../../patches/hypr-persist/reconnect-ipc.patch
          ../../patches/hypr-persist/settle-floating-geometry.patch
        ];
        passthru.autoUpdate = false;
        meta = {
          description = "Persist and restore Hyprland windows and layouts";
          homepage = "https://github.com/ngamber/hypr-persist";
          license = final.lib.licenses.bsd3;
          platforms = final.lib.platforms.linux;
        };
      };
    })
  ];
}
