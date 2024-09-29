{
  description = "Minimal Example for Nix2Poetry";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      poetry2nix,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend poetry2nix.overlays.default;

        inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; })
          mkPoetryApplication
          mkPoetryEnv
          #defaultPoetryOverrides
          ;

        myApp = mkPoetryApplication rec {
          projectDir = self;

          exeName = "poetry2nix-example";

          python = pkgs.python312;

          preferWheels = true;

          # extend official overrides
          # https://github.com/nix-community/poetry2nix/blob/aea314e63c34d690b582f8d2b1717e2abe743b51/overrides/default.nix#L2776-L2844
          # overrides = defaultPoetryOverrides.extend (final: prev: { });

          pythonRelaxDeps = [ ];

          dependencies = (
            with pkgs;
            [
              dbus
              fontconfig
              freetype
              glib
              libGL
              libkrb5
              libpulseaudio
              libva
              libxkbcommon
              openssl
              qt6.full
              stdenv.cc.cc.lib
              wayland
              xorg.libX11
              xorg.libxcb
              xorg.libXi
              xorg.libXrandr
            ]
          );

          buildInputs =
            (with pkgs; [
              qt6.qtbase
            ])
            ++ dependencies;

          nativeBuildInputs =
            (with pkgs; [
              makeWrapper
              qt6.wrapQtAppsHook
            ])
            ++ dependencies;

          propogatedBuildInputs = (with pkgs; [ ]) ++ dependencies;
        };
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        # $> nix run
        # apps = {
        #   default = {
        #     type = "app";
        #     # name in [tool.poetry.scripts] section of pyproject.toml
        #     program = "${myApp}/bin/${myApp.exeName}";
        #   };
        # };

        # $> nix run
        packages = {
          myApp = myApp;
          default = myApp;
        };

        # Development Shell including `poetry`.
        # $> nix develop
        #
        # Use this shell for developing the application and
        # making changes to `pyproject.toml` and `poetry.lock` files.
        #
        # $> poetry install                       => install packages stated by petry.lock file
        # $> poetry lock                          => update lock file after changing dependencies
        # $> python -m poetry2nix_example.example => launch application as Python module
        # $> poetry run poetry2nix-example        => execute the application via Poetry
        devShells.default = pkgs.mkShell rec {
          #inputsFrom = [ self.apps.${system}.default ];
          inputsFrom = [ self.packages.${system}.myApp ];

          packages =
            with pkgs;
            [
              poetry
            ]
            ++ myApp.dependencies;

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath packages;
        };

        # Shell for poetry.
        #
        # Needed to create first lock file.
        # $> nix develop .#poetry
        # $> poetry install
        #
        # Use this shell for changes to pyproject.toml and poetry.lock.
        devShells.poetry = pkgs.mkShell {
          packages = [ pkgs.poetry ];
        };
      }
    );
}
