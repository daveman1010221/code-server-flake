##############################
# flake.nix for code-server #
##############################

{
  description = "Standalone flake to build latest code-server with vendored deps";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        codeServerDeps = ./code-server-vendored-deps.tar.gz;

        code-server = pkgs.stdenv.mkDerivation {
          pname = "code-server";
          version = "4.100.0";

          src = pkgs.fetchFromGitHub {
            owner = "coder";
            repo = "code-server";
            rev = "v4.100.0";
            hash = "sha256-HQBz/YxVhBReASjW/Pl0W7ySNp9Im/El0BJjSlqwE1Y=";
            fetchSubmodules = true;
          };

          nativeBuildInputs = with pkgs; [
            nodejs_20
            makeWrapper
            jq
            moreutils
            rsync
            pkg-config
          ];

          unpackPhase = ''
            cp -r $src/* .
            tar -xzf ${codeServerDeps}
          '';

          buildPhase = ''
            set -x
            export HOME=$PWD
            export NODE_ENV=production
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
            npm rebuild --ignore-scripts
            npm run build
            npm run release
          '';

          installPhase = ''
            set -x
            mkdir -p $out/libexec/code-server $out/bin
            cp -r release/* $out/libexec/code-server/
            makeWrapper ${pkgs.nodejs_20}/bin/node $out/bin/code-server \
              --add-flags "$out/libexec/code-server/out/node/entry.js"
          '';

          meta = with pkgs.lib; {
            description = "Run VS Code on a remote server";
            homepage = "https://github.com/coder/code-server";
            license = licenses.mit;
            maintainers = [ maintainers.daveman1010221 ];
            platforms = platforms.linux;
            mainProgram = "code-server";
          };
        };

      in {
        packages.code-server = code-server;
        defaultPackage = code-server;
      }
    );
}
