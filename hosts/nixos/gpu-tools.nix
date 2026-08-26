{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nvtopPackages.full
    intel-gpu-tools
  ];
}
