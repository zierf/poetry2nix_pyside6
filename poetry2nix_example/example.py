from PySide6.QtCore import QPoint

from .subfolder import submodule

def main():
    print(f"\nLoaded External Module: {QPoint}")
    submodule.printSubfolder()

if __name__ == "__main__":
    main()
