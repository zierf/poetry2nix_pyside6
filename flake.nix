{
  description = "Minimal Example for Nix2Poetry";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    poetry2nix.url = "github:nix-community/poetry2nix";
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix, ... } @inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend poetry2nix.overlays.default;

        inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication mkPoetryEnv defaultPoetryOverrides;

        myApp = mkPoetryApplication rec {
          projectDir = self;

          exeName = "poetry2nix-example";

          python = pkgs.python312;

          preferWheels = true;

          # use official overrides as template
          # https://github.com/nix-community/poetry2nix/blob/7619e43c2b48c29e24b88a415256f09df96ec276/overrides/default.nix#L2743-L2805
          overrides = defaultPoetryOverrides.extend (final: prev: {
            pyside6 = prev.pyside6.overridePythonAttrs (old: pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
              dontWrapQtApps = true;
              preferWheel = true;

              propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
                pkgs.qt6.full
              ];
            });

            pyside6-essentials = prev.pyside6-essentials.overridePythonAttrs (old: pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
              # prevent error: 'Error: wrapQtAppsHook is not used, and dontWrapQtApps is not set.'
              dontWrapQtApps = true;
              preferWheel = true;

              autoPatchelfIgnoreMissingDeps = [ "libmysqlclient.so.21" "libmimerapi.so" "libQt6*" "libgbm.so.1" ];
              preFixup = ''
                addAutoPatchelfSearchPath $out/${final.python.sitePackages}/PySide6
                addAutoPatchelfSearchPath ${final.shiboken6}/${final.python.sitePackages}/shiboken6
              '';
              postInstall = ''
                rm -r $out/${final.python.sitePackages}/PySide6/__pycache__
              '';
              propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
                pkgs.qt6.full
                # satisfy some missing libraries for auto-patchelf patching PySide6-Essentials
                pkgs.qt6.qtquick3d
                pkgs.qt6.qtvirtualkeyboard
                pkgs.qt6.qtwebengine

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
              preferWheel = true;

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

          dependencies = (with pkgs; [
            # By including this Nix package, `nix run` can execute the application successfully.
            # But versions have to stay in Sync and it doesn't work after system installation.
            #python312.pkgs.pyside6

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
          ]);

          buildInputs = (with pkgs; [
            qt6.qtbase
          ]) ++ dependencies;

          nativeBuildInputs = (with pkgs; [
            makeWrapper
            qt6.wrapQtAppsHook
          ])
          ++ dependencies;

          propogatedBuildInputs = (with pkgs; [ ]) ++ dependencies;

          libraryPath = pkgs.lib.makeLibraryPath (with pkgs; [
            "$out"
          ] ++ dependencies);

          binaryPath = pkgs.lib.makeBinPath (with pkgs; [
            "$out"
          ] ++ dependencies);

          #LD_LIBRARY_PATH = libraryPath;
          #PATH = binaryPath;

          # qtWrapperArgs = [
          #   ''--prefix LD_LIBRARY_PATH : ${libraryPath}''
          #   ''--prefix PATH : ${binaryPath}''
          # ];

          # preFixup = ''
          #   wrapQtApp "$out/bin/${exeName}" \
          #     --prefix LD_LIBRARY_PATH : libraryPath \
          #     --prefix PATH : binaryPath
          # '';
        };
      in
      {
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
        # $> poetry install                         => install packages stated by petry.lock file
        # $> poetry lock                            => update lock file after changing dependencies
        # $> python ./poetry2nix_example/example.py => launch application via Python
        # $> poetry run myApp                       => execute the application with Poetry
        devShells.default = pkgs.mkShell rec {
          #inputsFrom = [ self.apps.${system}.default ];
          inputsFrom = [ self.packages.${system}.myApp ];

          packages = with pkgs; [
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
