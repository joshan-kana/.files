{ buildGoModule }:

buildGoModule {
  pname = "home-dashboard";
  version = "0.1.0";
  src = ./app;
  vendorHash = "sha256-0Qxw+MUYVgzgWB8vi3HBYtVXSq/btfh4ZfV/m1chNrA=";
  meta.mainProgram = "home-dashboard";
  ldflags = [
    "-s"
    "-w"
  ];
  preCheck = "go vet ./...";
}
