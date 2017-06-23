# GNU MCU Eclipse RISC-V Embedded GCC build

These are the additional files required by the [GNU MCU Eclipse RISC-V Embedded GCC](https://github.com/gnu-mcu-eclipse/riscv-gcc) build procedures.

## How to build

```bash
$ git clone https://github.com/gnu-mcu-eclipse/riscv-gcc-build.git ~/Downloads/riscv-gcc-build.git
$ bash ~/Downloads/riscv-gcc-build.git/scripts/build.sh --all
```

Warning: with 5 separate distributions, this will take many hours, even on a fast machine.

## Folders

For consistency with other projects, all files are grouped under `gnu-mcu-eclipse`.

* `info` - informative files copied to the distributed `info` folder;
* `nsis` - files required by [NSIS (Nullsoft Scriptable Install System)](http://nsis.sourceforge.net/Main_Page);
* `patches` - small patches to correct some problems identified in the official packages;
* `pkgconfig` - configuration files missing in some of the official packages;
* `scripts` - the build support scripts.

## Files

* `VERSION` - the stable build version file. Its content looks like `7.1.1-1`, where `7.1.1` is the official GCC version, and `2` is the GNU MCU Eclipse RISC-V GCC release number.
* `VERSION-dev` - the development build version file.