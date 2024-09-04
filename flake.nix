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

  outputs = { self, nixpkgs, flake-utils, poetry2nix, ... } @inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend poetry2nix.overlays.default;

        inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication mkPoetryEnv defaultPoetryOverrides;

        myApp = mkPoetryApplication {
          projectDir = self;

          exeName = "poetry2nix-example";

          python = pkgs.python312;

          preferWheels = true;

          # extend official overrides
          # https://github.com/nix-community/poetry2nix/blob/7619e43c2b48c29e24b88a415256f09df96ec276/overrides/default.nix#L2743-L2805
          overrides = defaultPoetryOverrides.extend (final: prev: {
            # working Overrides for PySide6 via nixpkgs
            # https://github.com/nix-community/poetry2nix/issues/1191#issuecomment-1707590287
            #pyside6 = final.pkgs.python312.pkgs.pyside6;
            #shiboken6 = final.pkgs.python3.pkgs.shiboken6;

            pyside6 = prev.pyside6.overridePythonAttrs (old: pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
              dontWrapQtApps = true;

              # also try PatchElf search paths for main package
              preFixup = ''
                addAutoPatchelfSearchPath $out/${final.python.sitePackages}/PySide6
                addAutoPatchelfSearchPath ${final.shiboken6}/${final.python.sitePackages}/shiboken6
              '';
              postInstall = ''
                rm -r $out/${final.python.sitePackages}/PySide6/__pycache__
              '';

              propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
                pkgs.qt6.qtmultimedia

                # dependencies from nixpkgs pyside6
                # https://github.com/NixOS/nixpkgs/blob/c40ce90d28e607d3b967963a0240c43d1210dbc5/pkgs/development/python-modules/pyside6/default.nix
                pkgs.qt6.qtbase
                # optional
                pkgs.qt6.qt3d
                pkgs.qt6.qtcharts
                pkgs.qt6.qtconnectivity
                pkgs.qt6.qtdatavis3d
                pkgs.qt6.qtdeclarative
                pkgs.qt6.qthttpserver
                pkgs.qt6.qtmultimedia
                pkgs.qt6.qtnetworkauth
                pkgs.qt6.qtquick3d
                pkgs.qt6.qtremoteobjects
                pkgs.qt6.qtscxml
                pkgs.qt6.qtsensors
                pkgs.qt6.qtspeech
                pkgs.qt6.qtsvg
                pkgs.qt6.qtwebchannel
                pkgs.qt6.qtwebsockets
                pkgs.qt6.qtpositioning
                pkgs.qt6.qtlocation
                pkgs.qt6.qtshadertools
                pkgs.qt6.qtserialport
                pkgs.qt6.qtserialbus
                pkgs.qt6.qtgraphs
                pkgs.qt6.qttools
              ];
            });

            pyside6-essentials = prev.pyside6-essentials.overridePythonAttrs (old: pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
              # prevent error: 'Error: wrapQtAppsHook is not used, and dontWrapQtApps is not set.'
              dontWrapQtApps = true;

              # added libgbm.so.1 to satsify missing library for auto-patchelf
              autoPatchelfIgnoreMissingDeps = [ "libmysqlclient.so.21" "libmimerapi.so" "libQt6*" "libgbm.so.1" ];
              preFixup = ''
                addAutoPatchelfSearchPath $out/${final.python.sitePackages}/PySide6
                addAutoPatchelfSearchPath ${final.shiboken6}/${final.python.sitePackages}/shiboken6
              '';
              postInstall = ''
                rm -r $out/${final.python.sitePackages}/PySide6/__pycache__
              '';
              propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
                # PySide6 in nixpkgs needs these for video playback
                pkgs.qt6.qtmultimedia
                pkgs.xorg.libXrandr
                # enable hardware acceleration
                pkgs.libva
                pkgs.openssl
                # satisfy some missing libraries for auto-patchelf patching PySide6-Essentials
                pkgs.qt6.qtquick3d
                pkgs.qt6.qtvirtualkeyboard
                pkgs.qt6.qtwebengine
                # other packages from default override
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
                final.shiboken6
              ];
            });

            pyside6-addons = prev.pyside6-addons.overridePythonAttrs (old: pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
              dontWrapQtApps = true;

              autoPatchelfIgnoreMissingDeps = [
                "libmysqlclient.so.21"
                "libmimerapi.so"
                "libQt6Quick3DSpatialAudio.so.6"
                "libQt6Quick3DHelpersImpl.so.6"
              ];
              preFixup = ''
                addAutoPatchelfSearchPath ${final.shiboken6}/${final.python.sitePackages}/shiboken6
                addAutoPatchelfSearchPath ${final.pyside6-essentials}/${final.python.sitePackages}/PySide6
              '';
              propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
                pkgs.nss
                pkgs.xorg.libXtst
                pkgs.alsa-lib
                pkgs.xorg.libxshmfence
                pkgs.xorg.libxkbfile
              ];
              postInstall = ''
                rm -r $out/${final.python.sitePackages}/PySide6/__pycache__
              '';
            });
          });

          pythonRelaxDeps = [ ];

          buildInputs = (with pkgs; [
            qt6.qtbase
            qt6.qtmultimedia
          ]);

          nativeBuildInputs = (with pkgs; [
            makeWrapper
            qt6.wrapQtAppsHook
          ]);

          propogatedBuildInputs = (with pkgs; [ ]);
        };
      in
      {
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

          packages = with pkgs; [
            poetry
          ];

          buildInputs = (with pkgs; [
            stdenv.cc.cc.lib
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
            # video playback
            xorg.libXrandr
          ]);

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (packages ++ buildInputs);
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
