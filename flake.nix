{
  description = "Rescript React Restate developers environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rescript-compiler = {
      url = "github:rescript-lang/rescript-compiler?ref=10.1.3";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, rescript-compiler}:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        python3 = pkgs.python39;
        nodejs = pkgs.nodejs_18;
        yarn = pkgs.yarn.override { nodejs = nodejs; };
        rescript = pkgs.callPackage ./rescript.nix { 
          inherit nodejs python3 rescript-compiler;
          inherit (pkgs) stdenv ocaml-ng; 
        };
      in
        {
          packages = {
            rescript = rescript;
          };
          devShell = pkgs.mkShell {
            buildInputs = [
              python3
              nodejs
              yarn
              rescript
            ];
            shellHook = ''
              yarn install
              ln -s "${rescript}/rescript" "$PWD/node_modules/.bin/rescript"
              ln -s ${rescript} "$PWD/node_modules/rescript"
              export PATH="${rescript}:$PWD/node_modules/.bin:$PATH"
            '';
          }; 
        }
    );
}
