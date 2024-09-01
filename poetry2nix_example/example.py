from PySide6.QtGui import QGuiApplication
from .subfolder import submodule

def main():
    print(f"\nLoaded External Module: {QGuiApplication}")
    submodule.printSubfolder()

if __name__ == "__main__":
    main()
