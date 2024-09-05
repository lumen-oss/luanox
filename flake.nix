{
  description = "Lua modules hosting";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      # nix develop
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          bun
          nodePackages.typescript
          nodePackages.typescript-language-server
        ];
      };
    });
}
