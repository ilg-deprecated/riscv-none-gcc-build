# GNU MCU Eclipse RISC-V Embedded GCC

This is the **GNU MCU Eclipse** (formerly GNU ARM Eclipse) version of the 
**RISC-V Embedded GCC** toolchain.

## Compliance

This toolchain closely follows the official [RISC-V distribution](https://github.com/riscv/riscv-gcc) maintained by [SiFive](https://www.sifive.com).

The current version is based on project riscv/riscv-gnu-toolchain, tag v20170612 (commit [f5fae1c](https://github.com/riscv/riscv-gnu-toolchain/tree/f5fae1c27b2365da773816ddcd92f533867f28ec)) from June 12th, which depends on the following:

- the riscv/riscv-gcc project, commit 16210e6 from from May 15th, 2017
- the riscv/riscv-binutils-gdb project, commit 3f21b5c from May 5th, 2017
- the riscv/riscv-newlib project, commit ccd8a0a from May 2nd, 2017

## Changes

The changes are minimal, and mainly consist in the additional files 
required by the packing procedure used to generate the binary packages 
(for more details please see `gnu-mcu-eclipse/CHANGES.txt`).

## newlib-nano

The only notable addition is support for **newlib-nano**, using the 
`--specs=nano.specs` linker option.

## More info

For more info and support, please see the GNU MCU Eclipe project pages from:

  http://gnu-mcu-eclipse.github.io


Thank you for using **GNU MCU Eclipse**,

Liviu Ionescu

