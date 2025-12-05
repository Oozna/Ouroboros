{
  description = "Flake for dev shell.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # to easily make configs for multiple architectures
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      supportedSystems =
        [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux" ];
    in flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };

        dependencies = (with pkgs; [
          zig
          zls

          sdl3
          sdl3-ttf
          sdl3-image

          git 
        ]);

        shellFunctions = ''
          buildcmd() {
            zig build
          }
          export -f buildcmd

          testcmd() {
            zig build test
          }
          export -f testcmd

          runcmd() {
            zig build run
          }
          export -f runcmd
        '';

      in {

        devShell = pkgs.mkShell {
          buildInputs = dependencies;

          shellHook = ''
            ${shellFunctions}
            
            echo "Some convenient commands:"
            echo "${shellFunctions}" | grep -E '^\s*[a-zA-Z_][a-zA-Z0-9_]*\(\)' | sed 's/().*//' | sed 's/^[[:space:]]*/  /' | while read func; do
              body=$(echo "${shellFunctions}" | sed -n "/''${func}()/,/^[[:space:]]*}/p" | sed '1d;$d' | tr '\n' ';' | sed 's/;$//' | sed 's/[[:space:]]*$//')
              echo "  $func = $body"
            done
            echo ""
          '';
        };
      });
}
