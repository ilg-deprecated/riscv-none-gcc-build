# GNU MCU Eclipse RISC-V Embedded GCC build

These are the additional files required by the [GNU MCU Eclipse RISC-V Embedded GCC](https://github.com/gnu-mcu-eclipse/riscv-gcc) build procedures.

## Compliance

This toolchain closely follows the official [RISC-V distribution](https://github.com/riscv/riscv-gcc) maintained by [SiFive](https://www.sifive.com).

The current version is based on project riscv/riscv-gnu-toolchain, tag v20170612 (commit [f5fae1c](https://github.com/riscv/riscv-gnu-toolchain/tree/f5fae1c27b2365da773816ddcd92f533867f28ec)) from June 12th:

- the riscv/riscv-gcc project, commit 16210e6 from from May 15th, 2017
- the riscv/riscv-binutils-gdb project, commit 3f21b5c from May 5th, 2017
- the riscv/riscv-newlib project, commit ccd8a0a from May 2nd, 2017

## newlib-nano

The only notable addition is support for **newlib-nano**, using the `--specs=nano.specs` linker option.

## How to build

```bash
$ git clone https://github.com/gnu-mcu-eclipse/riscv-gcc-build.git ~/Downloads/riscv-gcc-build.git
$ bash ~/Downloads/riscv-gcc-build.git/scripts/build.sh --all
```

Warning: with 5 separate distributions, this will take many hours, even on a fast machine.

## Folders

For consistency with other projects, all files are grouped under `gnu-mcu-eclipse`.

* `gnu-mcu-eclipse/info` - informative files copied to the distributed `info` folder;
* `gnu-mcu-eclipse/nsis` - files required by [NSIS (Nullsoft Scriptable Install System)](http://nsis.sourceforge.net/Main_Page);
* `scripts/build.sh` - the build script.

## Files

* `VERSION` - the stable build version file. Its content looks like `7.1.1-1`, where `7.1.1` is the official GCC version, and `2` is the GNU MCU Eclipse RISC-V GCC release number.
* `VERSION-dev` - the development build version file.