{
  description = "Dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = { pkgs, lib, ... }: {
        devShells.default = lib.mkForce (pkgs.mkShell {
          packages = with pkgs; [
            saxon-he
            emacs
          ];

          shellHook = ''
          '';
        });
      };
    };
}
