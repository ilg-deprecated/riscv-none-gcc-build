# GNU MCU Eclipse RISC-V Embedded GCC - the build scripts

These are the scripts and additional files required to build the 
[GNU MCU Eclipse RISC-V Embedded GCC](https://github.com/gnu-mcu-eclipse/riscv-gcc).

The build scripts use the 
[xPack Build Box (XBB)](https://github.com/xpack/xpack-build-box), 
a set of elaborate build environments based on GCC 7.2 (Docker containers
for GNU/Linux and Windows or a custom HomeBrew for MacOS).

## How to build

### Prerequisites

The prerequisites are common to all binary builds. Please follow the 
instructions in the separate 
[Prerequisites for building binaries](https://gnu-mcu-eclipse.github.io/developer/build-binaries-prerequisites-xbb/) 
page and return when ready.

### Download the build scripts repo

The build script is available from GitHub and can be 
[viewed online](https://github.com/gnu-mcu-eclipse/riscv-none-gcc-build/blob/master/scripts/build.sh).

To download it, clone the 
[gnu-mcu-eclipse/riscv-none-gcc-build](https://github.com/gnu-mcu-eclipse/riscv-none-gcc-build) 
Git repo, including submodules. 

```console
$ curl -L https://github.com/gnu-mcu-eclipse/riscv-none-gcc-build/raw/master/scripts/git-clone.sh | bash
```

which issues the following two commands:

```console
$ rm -rf ~/Downloads/riscv-none-gcc-build.git
$ git clone --recurse-submodules https://github.com/gnu-mcu-eclipse/riscv-none-gcc-build.git \
  ~/Downloads/riscv-none-gcc-build.git
```

### Check the script

The script creates a temporary build `Work/riscv-none-gcc-${version}` folder 
in the user home. Although not recommended, if for any reasons you need to 
change this, you can redefine `WORK_FOLDER_PATH` variable before invoking 
the script.

### Preload the Docker images

Docker does not require to explicitly download new images, but does this 
automatically at first use.

However, since the images used for this build are relatively large, it is 
recommended to load them explicitly before starting the build:

```console
$ bash ~/Downloads/riscv-none-gcc-build.git/scripts/build.sh preload-images
```

The result should look similar to:

```console
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ilegeul/centos32    6-xbb-v1            f695dd6cb46e        2 weeks ago         2.92GB
ilegeul/centos      6-xbb-v1            294dd5ee82f3        2 weeks ago         3.09GB
hello-world         latest              f2a91732366c        2 months ago        1.85kB
```

### Update git repos

Starting with 8.2.0-2, the GNU MCU Eclipse RISC-V GCC follows
the official 
[SiFive releases](https://github.com/sifive/freedom-tools/releases), 
with as little differences as possible. Previously it followed the generic
[RISC-V releases](https://github.com/riscv/riscv-gnu-toolchain/releases).

#### Checkout remote branches

The first step is to checkout the remote branches into local branches.

Currently, the following branches are used

- `sifive-binutils-2.32`
- `sifive-gcc-8.2.0`
- `sifive-newlib-3.0.0`

For GDB, use the original [FSF repo](https://sourceware.org/git/?p=binutils-gdb.git).

#### Create local `-gme` branches

The second step is to create GNU MCU Eclipse branches;
they have similar names, but suffixed with `-gme`.

For the FSF GDB; identify the commit ID and first create a `sifive-gdb-*` 
branch, then create the `-gme` branch.

#### Update the configure files

In order to support the `riscv-none-embed` names, cherry pick or edit
the `config` files.

#### Push all branches

In all repos, push the new branches.

### Prepare the release

To prepare a new release, first determine the GCC version (like `7.2.0`) 
and update the `scripts/VERSION` file. The format is `7.2.0-3`. The 
fourth digit is the GNU MCU Eclipse release number of this version.

Add a new set of definitions in the `scripts/container-build.sh`, with the 
versions of various components.

### Pre-build using GITs

By default, the build script uses tagged commits and downloads the 
corresponding archives.

While preparing the release it is important to be able to use live Git 
versions. For this, 

* update the commit ids to the desired ones 
* commit and push
* start the build script and pass `--use-gits`

```console
$ bash ~/Downloads/riscv-none-gcc-build.git/scripts/build.sh --use-gits
```

### Tag the repos

When the result is acceptable, commit all repos and tag all with the same tag (like `v7.2.0-1`):

* the [gnu-mcu-eclipse/riscv-gcc](https://github.com/gnu-mcu-eclipse/riscv-gcc) project
* the [gnu-mcu-eclipse/riscv-binutils-gdb](https://github.com/gnu-mcu-eclipse/riscv-binutils-gdb) project
* the [gnu-mcu-eclipse/riscv-newlib](https://github.com/gnu-mcu-eclipse/riscv-newlib) project

In the binutils-gdb repo, add a separate tag for the GDB branch (`v7.2.0-1-gdb`).

### Update CHANGELOG.txt

Check `riscv-none-gcc-build.git/CHANGELOG.txt` and add the new release.

## Update the README-xxx.md

Copy from the previous version and update.

### Build

Although it is perfectly possible to build all binaries in a single step on 
a macOS system, due to Docker specifics, it is faster to build the GNU/Linux 
and Windows binaries on a GNU/Linux system and the macOS binary separately.

#### Build the GNU/Linux and Windows binaries

The current platform for GNU/Linux and Windows production builds is an 
Ubuntu 17.10 VirtualBox image running on a macMini with 16 GB of RAM and 
a fast SSD.

Before starting a multi-platform build, check if Docker is started:

```console
$ docker info
```

To build both the 32/64-bit Windows and GNU/Linux versions, use `--all`; 
to build selectively, use `--linux64 --win64` or `--linux32 --win32` 
(GNU/Linux can be built alone; Windows also requires the GNU/Linux build).

```console
$ sudo rm -rf "${HOME}/Work"/riscv-none-gcc-*
$ bash ~/Downloads/riscv-none-gcc-build.git/scripts/build.sh --all
```

Several hours later, the output of the build script is a set of 4 files 
and their SHA signatures, created in the `deploy` folder:

```console
$ ls -l deploy
total 495652
-rw-r--r-- 1 ilg ilg 126668466 May  7 13:51 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-centos32.tgz
-rw-r--r-- 1 ilg ilg       132 May  7 13:51 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-centos32.tgz.sha
-rw-r--r-- 1 ilg ilg 123374305 May  7 11:26 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-centos64.tgz
-rw-r--r-- 1 ilg ilg       132 May  7 11:26 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-centos64.tgz.sha
-rw-r--r-- 1 ilg ilg 123243494 May  7 14:27 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-win32.zip
-rw-r--r-- 1 ilg ilg       129 May  7 14:27 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-win32.zip.sha
-rw-r--r-- 1 ilg ilg 134171799 May  7 12:04 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-win64.zip
-rw-r--r-- 1 ilg ilg       129 May  7 12:04 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-win64.zip.sha
```

To copy the files from the build machine to the current development machine, 
open the `deploy` folder in a terminal and use `scp`:

```console
$ cd "${HOME}/Work/riscv-none-gcc-7.2.0-3/deploy"
$ scp * ilg@ilg-mbp.local:Downloads/gme-binaries/riscv
```

#### Build the macOS binary

The current platform for macOS production builds is a macOS 10.10.5 
VirtualBox image running on the same macMini with 16 GB of RAM and a fast SSD.

To build the latest macOS version, with the same timestamp as the previous build:

```console
$ rm -rf "${HOME}/Work"/riscv-none-gcc-*
$ caffeinate bash ~/Downloads/riscv-none-gcc-build.git/scripts/build.sh --osx --date YYYYMMDD-HHMM
```

For consistency reasons, the date should be the same as the GNU/Linux 
and Windows builds.

Several hours later, the output of the build script is a compressed 
archive and its SHA signature, created in the `deploy` folder:

```console
$ ls -l deploy
total 238824
-rw-r--r--  1 ilg  staff  122271403 May  7 01:36 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-macos.tgz
-rw-r--r--  1 ilg  staff        129 May  7 01:36 gnu-mcu-eclipse-riscv-none-gcc-7.2.0-3-20180506-1300-macos.tgz.sha
```

To copy the files from the build machine to the current development 
machine, open the `deploy` folder in a terminal and use `scp`:

```console
$ cd "${HOME}/Work/riscv-none-gcc-7.2.0-3/deploy"
$ scp * ilg@ilg-mbp.local:Downloads/gme-binaries/riscv
```

### Subsequent runs

#### Separate platform specific builds

Instead of `--all`, you can use any combination of:

```
--win32 --win64 --linux32 --linux64
```

Please note that, due to the specifics of the GCC build process, 
the Windows build requires the corresponding GNU/Linux build, so `--win32` 
alone is equivalent to `--linux32 --win32` and `--win64` alone is 
equivalent to `--linux64 --win64`.

#### clean

To remove most build files, use:

```console
$ bash ~/Downloads/riscv-none-gcc-build.git/scripts/build.sh clean
```

To also remove the repository and the output files, use:

```console
$ bash ~/Downloads/riscv-none-gcc-build.git/scripts/build.sh cleanall
```

For production builds it is recommended to completely remove the build folder.

#### --develop

For performance reasons, the actual build folders are internal to each 
Docker run, and are not persistent. This gives the best speed, but has 
the disadvantage that interrupted builds cannot be resumed.

For development builds, it is possible to define the build folders in 
the host file system, and resume an interrupted build.

#### --debug

For development builds, it is also possible to create everything with 
`-g -O0` and be able to run debug sessions.

#### Interrupted builds

The Docker scripts run with root privileges. This is generally not a 
problem, since at the end of the script the output files are reassigned 
to the actual user.

However, for an interrupted build, this step is skipped, and files in 
the install folder will remain owned by root. Thus, before removing 
the build folder, it might be necessary to run a recursive `chown`.

## Install

The procedure to install GNU MCU Eclipse RISC-V Embedded GCC is platform 
specific, but relatively straight forward (a .zip archive on Windows, 
a compressed tar archive on macOS and GNU/Linux).

A portable method is to use [`xpm`](https://www.npmjs.com/package/xpm):

```console
$ xpm install --global @gnu-mcu-eclipse/riscv-none-gcc
```

More details are available on the 
[How to install the RISC-V toolchain?](https://gnu-mcu-eclipse.github.io/toolchain/riscv/install/) 
page.

After install, the package should create a structure like this (only 
the first two depth levels are shown):

```console
$ tree -L 2 /Users/ilg/Library/xPacks/\@gnu-mcu-eclipse/riscv-none-gcc/8.2.0-2.1/.content/
/Users/ilg/Library/xPacks/@gnu-mcu-eclipse/riscv-none-gcc/8.2.0-2.1/.content/
├── README.md
├── bin
│   ├── libexpat.1.6.7.dylib
│   ├── libexpat.1.dylib -> libexpat.1.6.7.dylib
│   ├── libgcc_s.1.dylib
│   ├── libgmp.10.dylib
│   ├── libiconv.2.dylib
│   ├── liblzma.5.dylib
│   ├── libmpfr.4.dylib
│   ├── libz.1.2.8.dylib
│   ├── libz.1.dylib -> libz.1.2.8.dylib
│   ├── riscv-none-embed-addr2line
│   ├── riscv-none-embed-ar
│   ├── riscv-none-embed-as
│   ├── riscv-none-embed-c++
│   ├── riscv-none-embed-c++filt
│   ├── riscv-none-embed-cpp
│   ├── riscv-none-embed-elfedit
│   ├── riscv-none-embed-g++
│   ├── riscv-none-embed-gcc
│   ├── riscv-none-embed-gcc-8.2.0
│   ├── riscv-none-embed-gcc-ar
│   ├── riscv-none-embed-gcc-nm
│   ├── riscv-none-embed-gcc-ranlib
│   ├── riscv-none-embed-gcov
│   ├── riscv-none-embed-gcov-dump
│   ├── riscv-none-embed-gcov-tool
│   ├── riscv-none-embed-gdb
│   ├── riscv-none-embed-gdb-
│   ├── riscv-none-embed-gdb-add-index
│   ├── riscv-none-embed-gdb-add-index-py
│   ├── riscv-none-embed-gdb-py
│   ├── riscv-none-embed-gprof
│   ├── riscv-none-embed-ld
│   ├── riscv-none-embed-ld.bfd
│   ├── riscv-none-embed-nm
│   ├── riscv-none-embed-objcopy
│   ├── riscv-none-embed-objdump
│   ├── riscv-none-embed-ranlib
│   ├── riscv-none-embed-readelf
│   ├── riscv-none-embed-size
│   ├── riscv-none-embed-strings
│   └── riscv-none-embed-strip
├── gnu-mcu-eclipse
│   ├── CHANGELOG.txt
│   ├── licenses
│   ├── patches
│   └── scripts
├── include
│   └── gdb
├── lib
│   ├── bfd-plugins
│   ├── gcc
│   ├── libcc1.0.so
│   └── libcc1.so -> libcc1.0.so
├── libexec
│   └── gcc
├── riscv-none-embed
│   ├── bin
│   ├── include
│   ├── lib
│   └── share
└── share
    ├── doc
    └── gcc-riscv-none-embed

20 directories, 45 files
```

No other files are installed in any system folders or other locations.

## Uninstall

The binaries are distributed as portable archives; thus they do not need 
to run a setup and do not require an uninstall.

## Test

A simple test is performed by the script at the end, by launching the 
executable to check if all shared/dynamic libraries are correctly used.

For a true test you need to first install the package and then run the 
program from the final location. For example on macOS the output should 
look like:

```console
$ /Users/ilg/Library/xPacks/@gnu-mcu-eclipse/riscv-none-gcc/8.2.0-2.1.1/.content/bin/riscv-none-embed-gcc --version
riscv-none-embed-gcc (GNU MCU Eclipse RISC-V Embedded GCC, 64-bit) 8.2.0
```

## Support

For issues related to the procedure used to build the 
GNU MCU Eclipse RISC-V Embedded GCC binaries, please report them via 
[gnu-mcu-eclipse/riscv-none-gcc-build GitHub Issues](https://github.com/gnu-mcu-eclipse/riscv-none-gcc-build/issues).

For issues related to the xPack used to install the binaries, 
please report them via
[gnu-mcu-eclipse/riscv-none-gcc-xpack GitHub issues](https://github.com/gnu-mcu-eclipse/riscv-none-gcc-xpack/issues).

For issues related to the toolchain functionality (compiler, newlib
gdb, etc) please report them via their original RISC-V projects:

- [riscv/riscv-gcc](https://github.com/riscv/riscv-gcc/issues)
- [riscv/riscv-newlib](https://github.com/riscv/riscv-newlib/issues)
- [riscv/riscv-binutils-gdb](https://github.com/riscv/riscv-binutils-gdb/issues)

## More build details

The build process is split into several scripts. The build starts on 
the host, with `build.sh`, which runs `container-build.sh` several times, 
once for each target, in one of the two docker containers. Both scripts 
include several other helper scripts. The entire process is quite complex, 
and an attempt to explain its functionality in a few words would not be 
realistic. Thus, the authoritative source of details remains the source code.

## Publish

See the [PUBLISH.md](https://github.com/gnu-mcu-eclipse/riscv-none-gcc/blob/riscv-next/PUBLISH.md) 
in the gnu-mcu-eclipse/riscv-next branch.
