# GNU MCU Eclipse RISC-V GCC build

These are the additional files required by the **GNU MCU Eclipse RISC-V GCC build** procedures.

## Folders

For consistency with other projects, all files are grouped under `gnu-mcu-eclipse`.

* `info` - informative files copied to the distributed `info` folder;
* `nsis` - files required by [NSIS (Nullsoft Scriptable Install System)](http://nsis.sourceforge.net/Main_Page);
* `patches` - small patches to correct some problems identified in the official packages;
* `pkgconfig` - configuration files missing in some of the official packages;
* `scripts` - the build scripts and some other support scripts.

## Files

* `VERSION` - the current build version file. Its content looks like `7.1.1-1`, where `7.1.1` is the official GCC version, and `2` is the GNU MCU Eclipse RISC-V GCC release number.
