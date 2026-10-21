{ buildGoModule }:

buildGoModule {
  pname = "home-dashboard";
  version = "0.1.0";
  src = ./app;
  vendorHash = null;
  meta.mainProgram = "home-dashboard";
  ldflags = [
    "-s"
    "-w"
  ];
  preCheck = "go vet ./...";
}
