{
  description = "Example for legacy Nix2Poetry with PySide 6.6.0";

  inputs = {
    # https://github.com/NixOS/nixpkgs/tree/HEAD@%7B2023-10-26%7D
    nixpkgs.url = "github:nixos/nixpkgs/d8bb0bda47dbe7fb569c6b4c6d46d349baae6e5d";

    flake-utils.url = "github:numtide/flake-utils";

    # https://github.com/nix-community/poetry2nix/pull/1356
    poetry2nix = {
      url = "github:nix-community/poetry2nix/2d29b1692e6f99eab700a4f786028f0b34cde1ac";
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
        pkgs = nixpkgs.legacyPackages.${system};

        myApp = pkgs.poetry2nix.mkPoetryApplication rec {
          src = self;

          pyproject = ./pyproject.toml;
          poetrylock = ./poetry.lock;

          python = pkgs.python310;

          overrides = pkgs.poetry2nix.overrides.withDefaults (
            self: super: {
              pyside6-essentials = super.pyside6-essentials.overridePythonAttrs (old: {
                autoPatchelfIgnoreMissingDeps = [ "libmysqlclient.so.21" "libmimerapi.so" "libQt6*" ];
                preFixup = ''
                  addAutoPatchelfSearchPath $out/${self.python.sitePackages}/PySide6
                  addAutoPatchelfSearchPath ${self.shiboken6}/${self.python.sitePackages}/shiboken6
                '';
                postInstall = ''
                  rm -r $out/${self.python.sitePackages}/PySide6/__pycache__
                '';
                propagatedBuildInputs = old.propagatedBuildInputs ++ [
                  pkgs.libxkbcommon
                  pkgs.gtk3
                  pkgs.speechd
                  pkgs.gst
                  pkgs.gst_all_1.gst-plugins-base
                  pkgs.gst_all_1.gstreamer
                  pkgs.postgresql.lib
                  pkgs.unixODBC
                  pkgs.pcsclite
                  pkgs.xorg.libxcb
                  pkgs.xorg.xcbutil
                  pkgs.xorg.xcbutilcursor
                  pkgs.xorg.xcbutilerrors
                  pkgs.xorg.xcbutilimage
                  pkgs.xorg.xcbutilkeysyms
                  pkgs.xorg.xcbutilrenderutil
                  pkgs.xorg.xcbutilwm
                  pkgs.libdrm
                  pkgs.pulseaudio
                  self.shiboken6
                ];
              });

              pyside6-addons = super.pyside6-addons.overridePythonAttrs (old: {
                autoPatchelfIgnoreMissingDeps = [
                  "libmysqlclient.so.21"
                  "libmimerapi.so"
                  "libQt6Quick3DSpatialAudio.so.6"
                  "libQt6Quick3DHelpersImpl.so.6"
                ];
                preFixup = ''
                  addAutoPatchelfSearchPath ${self.shiboken6}/${self.python.sitePackages}/shiboken6
                  addAutoPatchelfSearchPath ${self.pyside6-essentials}/${self.python.sitePackages}/PySide6
                '';
                propagatedBuildInputs = old.propagatedBuildInputs ++ [
                  pkgs.nss
                  pkgs.xorg.libXtst
                  pkgs.alsa-lib
                  pkgs.xorg.libxshmfence
                  pkgs.xorg.libxkbfile
                ];
                postInstall = ''
                  rm -r $out/${self.python.sitePackages}/PySide6/__pycache__
                '';
              });
            }
          );

          pythonRelaxDeps = [ ];

          dependencies = (
            with pkgs;
            [
              # stdenv.cc.cc.lib
              # dbus
              # fontconfig
              # freetype
              # glib
              # libGL
              # libkrb5
              # libpulseaudio
              # libva
              # libxkbcommon
              # openssl
              # qt6.full
              # wayland
              # xorg.libX11
              # xorg.libxcb
              # xorg.libXi
              # xorg.libXrandr
            ]
          );

          buildInputs = (with pkgs; [ qt6.qtbase ]) ++ dependencies;

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
          inputsFrom = [ self.packages.${system}.myApp ];

          packages = with pkgs; [ poetry ] ++ myApp.dependencies;

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath packages;
        };

        # Shell for poetry.
        #
        # Needed to create first lock file.
        # $> nix develop .#poetry
        # $> poetry install
        #
        # Use this shell for changes to pyproject.toml and poetry.lock.
        devShells.poetry = pkgs.mkShell { packages = [ pkgs.poetry ]; };
      }
    );
}
