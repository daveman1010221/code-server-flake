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

        codeServerDeps = builtins.fetchTarball {
          url = "https://github.com/daveman1010221/code-server-flake/archive/refs/heads/main.tar.gz";
          sha256 = "sha256-GupyDQG1yxw/3DseKJsD1skQdAJTll3489RWl6RyyzA=";
        };

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
            jq
            krb5
            makeWrapper
            moreutils
            nodejs_20
            pkg-config
            rsync
            xorg.libX11
            xorg.libxkbfile
          ];

          unpackPhase = ''
            cp -r $src/* .
            mkdir _deps
            tar -xzf ${codeServerDeps}/code-server-vendored-deps.tar.gz -C _deps
          '';

          patchPhase = ''
            rm -rf node_modules
            rm -rf package.json package-lock.json
            cp -r _deps/node_modules .
            cp _deps/package.json .
            cp _deps/package-lock.json .

            chmod -R +w ci
            patchShebangs ci/build/*
          '';

          buildPhase = ''
            export HOME=$PWD
            echo "PWD: $PWD"
            export NODE_ENV=production
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
            npm rebuild --ignore-scripts
            npm run build
            npm run release
          '';

          installPhase = ''
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
