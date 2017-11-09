# GNU MCU Eclipse RISC-V Embedded GCC

This is the **GNU MCU Eclipse** (formerly GNU ARM Eclipse) version of the 
**RISC-V Embedded GCC** toolchain.

## Compliance

This release closely follows the official [RISC-V distribution](https://github.com/riscv/riscv-gcc) maintained by [SiFive](https://www.sifive.com).

The current version is based on project [riscv/riscv-gnu-toolchain](https://github.com/riscv/riscv-gnu-toolchain), tag v20171107 (commit [f5fae1c](https://github.com/riscv/riscv-gnu-toolchain/tree/v20171107)) from Nov 7th, which depends on the following:

- the [riscv/riscv-gcc](https://github.com/riscv/riscv-gcc) project, commit [b731149](https://github.com/riscv/riscv-gcc/commit/b731149757b93ddc80e6e4b5483a6931d5f9ad60) from from Nov 7th, 2017
- the [riscv/riscv-binutils-gdb](https://github.com/riscv/riscv-binutils-gdb) project, commit [d0176cb](https://github.com/riscv/riscv-binutils-gdb/commit/d0176cb1653b2dd3849861453ee90a52caefa95a) from Nov 8th, 2017

A newer commit was used for newlib:

- the [riscv/riscv-newlib](https://github.com/riscv/riscv-newlib) project, commit [ccd8a0a](https://github.com/riscv/riscv-newlib/commit/f2ab66c9c1c90f74959ff47394b74dfaacdb125f) from Nov 5th, 2017

## Changes

Compared to the original RISC-V version, the **same architecture and API** options are supported, and there are minimal functional changes 

* newlib-nano is supported
* `march=rv32imaf/mabi=ilp32f` was added to the list of multilibs
* GDB was patched to no longer show all CSRs as regular registers

## newlib-nano

The only notable addition is support for **newlib-nano**, using the `--specs=nano.specs` option. For better results, this option must be added to both compile and link time (the next release of the GNU MCU Eclipse plug-ins will add support for this).

If no syscalls are needed, `--specs=nosys.specs` can be used at link time to provide empty implementations for the POSIX system calls.

The _nano_ versions of the libraries are compiled with `-Os -mcmodel=medlow`, while the regular versions are compiled with `-O2 -mcmodel=medany`.

## GDB

To avoid the Eclipse bug that hangs with a large number of registers, the list of registers returned by `data-list-register-names` no longer includes the 4096 CSRs.

## Documentation

Another addition compared to the SiFive distribution is the presence of the documentation, including the PDF manuals for all tools.

## More info

For more info and support, please see the GNU MCU Eclipse project pages from:

  http://gnu-mcu-eclipse.github.io


Thank you for using **GNU MCU Eclipse**,

Liviu Ionescu

