# GNU MCU Eclipse RISC-V Embedded GCC

This is the **GNU MCU Eclipse** (formerly GNU ARM Eclipse) version of the 
**RISC-V Embedded GCC** toolchain.

## Compliance

This release closely follows the official [RISC-V distribution](https://github.com/riscv/riscv-gcc) maintained by [SiFive](https://www.sifive.com).

The current version is based on the following commits:

- the [riscv/riscv-gcc](https://github.com/riscv/riscv-gcc) project, commit [5bf0f1d](https://github.com/gnu-mcu-eclipse/riscv-none-gcc/commit/5bf0f1db0ed4dd3e0cdd9395e7b258234ac976d9) from from Jan 8th, 2018
- the [riscv/riscv-binutils-gdb](https://github.com/riscv/riscv-binutils-gdb) project, commit [5d812b7](https://github.com/gnu-mcu-eclipse/riscv-binutils-gdb/commit/5d812b72c943d8cfa08d67baed73d1a64eb943e7) from Jan 9th, 2018
- the [riscv/riscv-newlib](https://github.com/riscv/riscv-newlib) project, commit [32a3de0](https://github.com/gnu-mcu-eclipse/riscv-newlib/commit/32a3de0bba1535fc1ca0d8dfae147d1dacaf0979) from Dec 21st, 2017

## Changes

Compared to the original RISC-V version, the **same architecture and API** options are supported, and there are minimal functional changes 

* newlib-nano is supported
* `march=rv32imaf/mabi=ilp32f` was added to the list of multilibs

## newlib-nano

The only notable addition is support for **newlib-nano**, using the `--specs=nano.specs` option. For better results, this option must be added to both compile and link time (the next release of the GNU MCU Eclipse plug-ins will add support for this).

If no syscalls are needed, `--specs=nosys.specs` can be used at link time to provide empty implementations for the POSIX system calls.

The _nano_ versions of the libraries are compiled with `-Os -mcmodel=medlow`, while the regular versions are compiled with `-O2 -mcmodel=medany`.

## Documentation

Another addition compared to the SiFive distribution is the presence of the documentation, including the PDF manuals for all tools.

## More info

For more info and support, please see the GNU MCU Eclipse project pages from:

  http://gnu-mcu-eclipse.github.io


Thank you for using **GNU MCU Eclipse**,

Liviu Ionescu

