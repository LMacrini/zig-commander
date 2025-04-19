{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    zig-overlay.url = "github:bandithedoge/zig-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    zig-overlay,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      zig = zig-overlay.packages.${system};
    in {
      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        name = "zig commander";
        packages = [
          pkgs.git
          zig.default
        ];
      };
    });
}
