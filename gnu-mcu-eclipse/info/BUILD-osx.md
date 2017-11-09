# GNU MCU Eclipse RISC-V Embedded GCC build

This package was build on an OS X machine, using the script provided in 
the GNU MCU Eclipse [riscv-none-gcc-build.git](https://github.com/gnu-mcu-eclipse/riscv-none-gcc-build) 
project.

## How to build?

To build the latest version of the package please use the script from:

```console
$ git clone https://github.com/gnu-mcu-eclipse/riscv-none-gcc-build.git \
~/Downloads/riscv-none-gcc-build.git
```

To run it, first be sure that the packages required in the Prerequisites 
section are installed, then download the script and execute it with bash:

```console
$ caffeinate bash
$ bash ~/Downloads/riscv-none-gcc-build.git/scripts/build.sh --osx
```

The output of the build script is a `.pkg` install and a `*.tgz` 
in the `${WORK_FOLDER}/deploy` folder.

The script was developed on OS X 10.12 with Homebrew. Running it on other 
versions is possible, but might require some adjustments.

## More info

Up-to-date build information is available in the GNU MCU Eclipse project web:

  http://gnu-mcu-eclipse.github.io/


Thank you for using **GNU MCU Eclipse**,

Liviu Ionescu
