{
  description = "A nix flake for the zfsbud script";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      supportedSystems = builtins.filter (system: lib.hasSuffix "-linux" system) lib.systems.flakeExposed;
      forAllSystems = lib.genAttrs supportedSystems;
      version = self.shortRev or self.dirtyShortRev or "dirty";
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          zfsbud = pkgs.stdenvNoCC.mkDerivation {
            pname = "zfsbud";
            inherit version;
            src = self;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            dontBuild = true;

            installPhase = ''
              install -Dm755 zfsbud.sh $out/libexec/zfsbud
              install -Dm644 default.zfsbud.conf $out/libexec/default.zfsbud.conf

              makeWrapper $out/libexec/zfsbud $out/bin/zfsbud \
                --prefix PATH : ${lib.makeBinPath [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.gnused
                  pkgs.openssh
                  pkgs.util-linux
                ]}
            '';

            meta = with lib; {
              description = "ZFS snapshotting, replication, and retention helper script";
              homepage = "https://gbyte.dev/project/zfsbud";
              license = licenses.mit;
              mainProgram = "zfsbud";
              platforms = platforms.linux;
            };
          };
        in {
          inherit zfsbud;
          default = zfsbud;
        });

      apps = forAllSystems (system:
        let
          package = self.packages.${system}.zfsbud;
        in {
          default = {
            type = "app";
            program = "${package}/bin/zfsbud";
            meta = package.meta;
          };
          zfsbud = self.apps.${system}.default;
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = [
              pkgs.bashInteractive
              pkgs.shellcheck
              pkgs.shfmt
            ];
          };
        });
    };
} 
