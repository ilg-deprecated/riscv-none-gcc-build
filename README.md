# GNU MCU Eclipse RISC-V Embedded GCC build

These are the additional files required by the [GNU MCU Eclipse RISC-V Embedded GCC](https://github.com/gnu-mcu-eclipse/riscv-gcc) build procedures.

This release closely follows the official [RISC-V distribution](https://github.com/riscv/riscv-gcc) maintained by [SiFive](https://www.sifive.com).

The current version is based on project [riscv/riscv-gnu-toolchain](https://github.com/riscv/riscv-gnu-toolchain).

## Changes

Compared to the original RISC-V version, there are no functional changes; the **same architecture and API options** are supported, and **the same combinations of libraries** (derived from newlib) are provided.

## newlib-nano

The only notable addition is support for **newlib-nano**, using the `--specs=nano.specs` option. For better results, this option must be added to both compile and link time (the next release of the GNU MCU Eclipse plug-ins will add support for this).

If no syscalls are needed, `--specs=nosys.specs` can be used at link time to provide empty implementations for the POSIX system calls.

The _nano_ versions of the libraries are compiled with `-Os -mcmodel=medlow`, while the regular versions are compiled with `-O2 -mcmodel=medany`.

## Documentation

Another addition compared to the SiFive distribution is the presence of the documentation, including the PDF manuals for all tools.

## How to build

The detailed steps are defined in the [How to build the RISC-V Embedded GCC binaries?](https://gnu-mcu-eclipse.github.io/toolchain/riscv/build-procedure/) page.

Warning: with 5 separate distributions, this will take many hours, even on a fast machine.

## Folders

For consistency with other projects, most files are grouped under `gnu-mcu-eclipse`.

* `gnu-mcu-eclipse/info` - informative files copied to the distributed `info` folder;
* `gnu-mcu-eclipse/nsis` - files required by [NSIS (Nullsoft Scriptable Install System)](http://nsis.sourceforge.net/Main_Page);
* `scripts/build.sh` - the build script.

## Files

* `VERSION` - the stable build version file. Its content looks like `7.1.1-2`, where `7.1.1` is the official GCC version, and `2` is the GNU MCU Eclipse RISC-V GCC release number.
* `VERSION-dev` - the development build version file.