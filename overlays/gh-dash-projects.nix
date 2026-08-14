_:

{
  nixpkgs.overlays = [
    (_final: prev: {
      gh-dash-projects = prev.buildGoModule {
        pname = "gh-dash";
        version = "4.9.1-projects";

        src = prev.fetchFromGitHub {
          owner = "dlvhdr";
          repo = "gh-dash";
          rev = "d2223144114beeda8d982ea6126909025de3bd67";
          hash = "sha256-n0+I1URuIOKqBj+BSE6bD3wOxpaKWM9t1X3PkPhawKY=";
        };

        patches = [ ../packages/gh-dash-projects/projects-v2.patch ];
        vendorHash = "sha256-lqmz+6Cr9U5IBoJ5OeSN6HKY/nKSAmszfvifzbxG7NE=";

        ldflags = [
          "-s"
          "-w"
        ];

        meta = {
          description = "GitHub dashboard with generic Projects v2 awareness";
          homepage = "https://github.com/dlvhdr/gh-dash";
          license = prev.lib.licenses.mit;
          mainProgram = "gh-dash";
        };
      };
    })
  ];
}
