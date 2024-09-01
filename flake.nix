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

          overrides = defaultPoetryOverrides.extend (final: prev: {
            pyside6-essentials = prev.pyside6-essentials.overridePythonAttrs (old: {
              # prevent error: 'Error: wrapQtAppsHook is not used, and dontWrapQtApps is not set.'
              dontWrapQtApps = true;

              # satisfy some missing libraries for auto-patchelf patching PySide6-Essentials
              buildInputs = ((old.buildInputs or [ ]) ++ (with pkgs; [
                qt6.qtquick3d
                qt6.qtvirtualkeyboard
                qt6.qtwebengine
              ]))
              ++ [
                #prev.setuptools
              ];
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

          propogatedBuildInputs = with pkgs; [ ] ++ dependencies;

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
