#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is -x.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------

# Script to build the GNU MCU Eclipse RISC-V GCC distribution packages.
#
# Developed on OS X 10.12 Sierra.
# Also tested on:
#   GNU/Linux Arch (Manjaro 16.08)
#
# The Windows and GNU/Linux packages are build using Docker containers.
# The build is structured in 2 steps, one running on the host machine
# and one running inside the Docker container.
#
# At first run, Docker will download/build 3 relatively large
# images (1-2GB) from Docker Hub.
#
# Prerequisites:
#
# - Docker
# - curl, git, automake, patch, tar, unzip, zip
#
# When running on OS X, a custom Homebrew is required to provide the 
# missing libraries and TeX binaries.
#
# The GCC cross build requires several steps:
# - build the binutils & gdb
# - build a simple C compiler
# - build newlib, possibly multilib
# - build the final C/C++ compilers
#
# For the Windows target, we are in a 'canadian build' case; since
# the Windows binaries cannot be executed directly, the Debian 
# binaries are expected in the PATH.
#
# As a consequence, the Windows build is always done after the
# Debian build.
# 
# To resume a crashed build with the same timestamp, set
# DISTRIBUTION_FILE_DATE='yyyymmdd-HHMM' in the environment.
#

# Mandatory definition.
APP_NAME="RISC-V Embedded GCC"

# Used as part of file/folder paths.
APP_UC_NAME="GNU RISC-V Embedded GCC"
APP_LC_NAME="riscv-none-gcc"

branding="GNU MCU Eclipse RISC-V Embedded GCC"

gcc_target="riscv64-unknown-elf"
gcc_arch="rv64imafdc"
gcc_abi="lp64d"

jobs="--jobs=8"

# On Parallels virtual machines, prefer host Work folder.
# Second choice are Work folders on secondary disks.
# Final choice is a Work folder in HOME.
if [ -d /media/psf/Home/Work ]
then
  WORK_FOLDER_PATH=${WORK_FOLDER_PATH:-"/media/psf/Home/Work/${APP_LC_NAME}"}
elif [ -d /media/${USER}/Work ]
then
  WORK_FOLDER_PATH=${WORK_FOLDER_PATH:-"/media/${USER}/Work/${APP_LC_NAME}"}
elif [ -d /media/Work ]
then
  WORK_FOLDER_PATH=${WORK_FOLDER_PATH:-"/media/Work/${APP_LC_NAME}"}
else
  # Final choice, a Work folder in HOME.
  WORK_FOLDER_PATH=${WORK_FOLDER_PATH:-"${HOME}/Work/${APP_LC_NAME}"}
fi

BUILD_FOLDER="${WORK_FOLDER_PATH}/build"

PROJECT_GIT_FOLDER_NAME="riscv-gcc-build.git"
PROJECT_GIT_FOLDER_PATH="${WORK_FOLDER_PATH}/${PROJECT_GIT_FOLDER_NAME}"
PROEJCT_GIT_URL="https://github.com/gnu-mcu-eclipse/${PROJECT_GIT_FOLDER_NAME}"

# ----- Create Work folder. -----

echo
echo "Work folder: \"${WORK_FOLDER_PATH}\"."

mkdir -p "${WORK_FOLDER_PATH}"

# ----- Parse actions and command line options. -----

ACTION=""
DO_BUILD_WIN32=""
DO_BUILD_WIN64=""
DO_BUILD_DEB32=""
DO_BUILD_DEB64=""
DO_BUILD_OSX=""
helper_script_path=""
do_no_strip=""
multilib_flags="" # by default multili is enabled
do_no_pdf=""

while [ $# -gt 0 ]
do
  case "$1" in

    clean|cleanall|pull|checkout-dev|checkout-stable|build-images|preload-images|bootstrap)
      ACTION="$1"
      shift
      ;;

    --win32|--window32)
      DO_BUILD_WIN32="y"
      shift
      ;;
    --win64|--windows64)
      DO_BUILD_WIN64="y"
      shift
      ;;
    --deb32|--debian32)
      DO_BUILD_DEB32="y"
      shift
      ;;
    --deb64|--debian64)
      DO_BUILD_DEB64="y"
      shift
      ;;
    --osx)
      DO_BUILD_OSX="y"
      shift
      ;;

    --all)
      DO_BUILD_WIN32="y"
      DO_BUILD_WIN64="y"
      DO_BUILD_DEB32="y"
      DO_BUILD_DEB64="y"
      DO_BUILD_OSX="y"
      shift
      ;;

    --helper-script)
      helper_script_path=$2
      shift 2
      ;;

    --no-strip)
      do_no_strip="y"
      shift
      ;;

    --no-pdf)
      do_no_pdf="y"
      shift
      ;;

    --disable-multilib)
      multilib_flags="--disable-multilib"
      shift
      ;;

    --help)
      echo "Build the GNU MCU Eclipse ${APP_NAME} distributions."
      echo "Usage:"
      echo "    bash $0 helper_script [--win32] [--win64] [--deb32] [--deb64] [--osx] [--all] [clean|cleanall|pull|checkout-dev|checkout-stable|build-images] [--help]"
      echo
      exit 1
      ;;

    *)
      echo "Unknown action/option $1"
      exit 1
      ;;
  esac

done

# ----- Prepare build scripts. -----

build_script_path=$0
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path=$(pwd)/$0
fi

# Copy the current script to Work area, to later copy it into the install folder.
mkdir -p "${WORK_FOLDER_PATH}/scripts"
cp "${build_script_path}" "${WORK_FOLDER_PATH}/scripts/build-${APP_LC_NAME}.sh"

# ----- Build helper. -----

if [ -z "${helper_script_path}" ]
then
  script_folder_path="$(dirname ${build_script_path})"
  script_folder_name="$(basename ${script_folder_path})"
  if [ \( "${script_folder_name}" == "scripts" \) \
    -a \( -f "${script_folder_path}/helper/build-helper.sh" \) ]
  then
    helper_script_path="${script_folder_path}/helper/build-helper.sh"
  elif [ \( "${script_folder_name}" == "scripts" \) \
    -a \( -d "${script_folder_path}/helper" \) ]
  then
    (
      cd "$(dirname ${script_folder_path})"
      git submodule update --init --recursive --remote
    )
    helper_script_path="${script_folder_path}/helper/build-helper.sh"
  elif [ -f "${WORK_FOLDER_PATH}/scripts/build-helper.sh" ]
  then
    helper_script_path="${WORK_FOLDER_PATH}/scripts/build-helper.sh"
  fi
else
  if [[ "${helper_script_path}" != /* ]]
  then
    # Make relative path absolute.
    helper_script_path="$(pwd)/${helper_script_path}"
  fi
fi

# Copy the current helper script to Work area, to later copy it into the install folder.
mkdir -p "${WORK_FOLDER_PATH}/scripts"
if [ "${helper_script_path}" != "${WORK_FOLDER_PATH}/scripts/build-helper.sh" ]
then
  cp "${helper_script_path}" "${WORK_FOLDER_PATH}/scripts/build-helper.sh"
fi

echo "Helper script: \"${helper_script_path}\"."
source "${helper_script_path}"


# ----- Input repositories -----

# The custom RISC-V GCC branch is available from the dedicated Git repository
# which is part of the GNU MCU Eclipse project hosted on GitHub.
# Generally this branch follows the official RISC-V GCC master branch,
# with updates after every RISC-V GCC public release.

BINUTILS_FOLDER_NAME="binutils-gdb.git"
BINUTILS_GIT_URL="https://github.com/gnu-mcu-eclipse/riscv-binutils-gdb.git"
#BINUTILS_GIT_BRANCH="riscv-next"
BINUTILS_GIT_BRANCH="__archive__"
BINUTILS_GIT_COMMIT="3f21b5c9675db61ef5462442b6a068d4a3da8aaf"

GCC_FOLDER_NAME="gcc.git"
GCC_GIT_URL="https://github.com/gnu-mcu-eclipse/riscv-gcc.git"
# GCC_GIT_BRANCH="riscv-next"
GCC_GIT_BRANCH="riscv-gcc-7"
GCC_GIT_COMMIT="16210e6270e200cd4892a90ecef608906be3a130"

NEWLIB_FOLDER_NAME="newlib.git"
NEWLIB_GIT_URL="https://github.com/gnu-mcu-eclipse/riscv-newlib.git"
NEWLIB_GIT_BRANCH="riscv-newlib-2.5.0"
NEWLIB_GIT_COMMIT="ccd8a0a4ffbbc00400892334eaf64a1616302b35"


# ----- Libraries sources. -----

# For updates, please check the corresponding pages.

# http://zlib.net
# https://sourceforge.net/projects/libpng/files/zlib/

LIBZ_VERSION="1.2.11" # 2017-01-16

LIBZ_FOLDER="zlib-${LIBZ_VERSION}"
LIBZ_ARCHIVE="${LIBZ_FOLDER}.tar.gz"
LIBZ_URL="https://sourceforge.net/projects/libpng/files/zlib/${LIBZ_VERSION}/${LIBZ_ARCHIVE}"


# https://gmplib.org
# https://gmplib.org/download/gmp/gmp-6.1.0.tar.bz2

GMP_VERSION="6.1.0"

GMP_FOLDER="gmp-${GMP_VERSION}"
GMP_ARCHIVE="${GMP_FOLDER}.tar.bz2"
GMP_URL="https://gmplib.org/download/gmp/${GMP_ARCHIVE}"


# http://www.mpfr.org
# http://www.mpfr.org/mpfr-current/mpfr-3.1.4.tar.bz2

MPFR_VERSION="3.1.4"

MPFR_FOLDER="mpfr-${MPFR_VERSION}"
MPFR_ARCHIVE="${MPFR_FOLDER}.tar.bz2"
MPFR_URL="http://www.mpfr.org/mpfr-current/${MPFR_ARCHIVE}"


# http://www.multiprecision.org/index.php?prog=mpc
# ftp://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz

MPC_VERSION="1.0.3"

MPC_FOLDER="mpc-${MPC_VERSION}"
MPC_ARCHIVE="${MPC_FOLDER}.tar.gz"
MPC_URL="ftp://ftp.gnu.org/gnu/mpc/${MPC_ARCHIVE}"

# http://isl.gforge.inria.fr
# http://isl.gforge.inria.fr/isl-0.16.1.tar.bz2

ISL_VERSION="0.16.1"

ISL_FOLDER="isl-${ISL_VERSION}"
ISL_ARCHIVE="${ISL_FOLDER}.tar.bz2"
ISL_URL="http://isl.gforge.inria.fr/${ISL_ARCHIVE}"


# ----- Define build constants. -----

DOWNLOAD_FOLDER_PATH="${WORK_FOLDER_PATH}/download"
DEPLOY_FOLDER_NAME="deploy"

# ----- Process actions. -----

if [ \( "${ACTION}" == "clean" \) -o \( "${ACTION}" == "cleanall" \) ]
then
  # Remove most build and temporary folders.
  echo
  if [ "${ACTION}" == "cleanall" ]
  then
    echo "Remove all the build folders..."
  else
    echo "Remove most of the build folders (except output)..."
  fi

  rm -rf "${BUILD_FOLDER}"
  rm -rf "${WORK_FOLDER_PATH}/install"
  rm -rf "${WORK_FOLDER_PATH}/scripts"

  rm -rf "${WORK_FOLDER_PATH}/${LIBZ_FOLDER}"
  rm -rf "${WORK_FOLDER_PATH}/${GMP_FOLDER}"
  rm -rf "${WORK_FOLDER_PATH}/${MPFR_FOLDER}"
  rm -rf "${WORK_FOLDER_PATH}/${MPC_FOLDER}"
  rm -rf "${WORK_FOLDER_PATH}/${ISL_FOLDER}"

  if [ "${ACTION}" == "cleanall" ]
  then
    rm -rf "${PROJECT_GIT_FOLDER_PATH}"
    rm -rf "${WORK_FOLDER_PATH}/${BINUTILS_FOLDER_NAME}"
    rm -rf "${WORK_FOLDER_PATH}/${GCC_FOLDER_NAME}"
    rm -rf "${WORK_FOLDER_PATH}/${NEWLIB_FOLDER_NAME}"
    rm -rf "${WORK_FOLDER_PATH}/${DEPLOY_FOLDER_NAME}"
  fi

  echo
  echo "Clean completed. Proceed with a regular build."

  exit 0
fi

# ----- Start build. -----

do_host_start_timer

do_host_detect

# ----- Prepare prerequisites. -----

do_host_prepare_prerequisites

# ----- Process "preload-images" action. -----

if [ "${ACTION}" == "preload-images" ]
then
  do_host_prepare_docker

  echo
  echo "Check/Preload Docker images..."

  echo
  docker run --interactive --tty ilegeul/debian32:8-gnuarm-gcc-x11-v3 \
  lsb_release --description --short

  echo
  docker run --interactive --tty ilegeul/debian:8-gnuarm-gcc-x11-v3 \
  lsb_release --description --short

  echo
  docker run --interactive --tty ilegeul/debian:8-gnuarm-mingw \
  lsb_release --description --short

  echo
  docker images

  do_host_stop_timer

  exit 0
fi

do_host_bootstrap() {

  return

  # Prepare autotools.
  echo
  echo "bootstrap..."

  cd "${PROJECT_GIT_FOLDER_PATH}"
  rm -f aclocal.m4
  ./bootstrap

}

if [ \( "${ACTION}" == "bootstrap" \) ]
then

  do_host_bootstrap

  do_host_stop_timer

  exit 0

fi

# ----- Process "build-images" action. -----

if [ "${ACTION}" == "build-images" ]
then
  do_host_prepare_docker

  # Remove most build and temporary folders.
  echo
  echo "Build Docker images..."

  # Be sure it will not crash on errors, in case the images are already there.
  set +e

  docker build --tag "ilegeul/debian32:8-gnuarm-gcc-x11-v3" \
  https://github.com/ilg-ul/docker/raw/master/debian32/8-gnuarm-gcc-x11-v3/Dockerfile

  docker build --tag "ilegeul/debian:8-gnuarm-gcc-x11-v3" \
  https://github.com/ilg-ul/docker/raw/master/debian/8-gnuarm-gcc-x11-v3/Dockerfile

  docker build --tag "ilegeul/debian:8-gnuarm-mingw" \
  https://github.com/ilg-ul/docker/raw/master/debian/8-gnuarm-mingw/Dockerfile

  docker images

  do_host_stop_timer

  exit 0
fi

# ----- Prepare Docker, if needed. -----

if [ -n "${DO_BUILD_WIN32}${DO_BUILD_WIN64}${DO_BUILD_DEB32}${DO_BUILD_DEB64}" ]
then
  do_host_prepare_docker
fi

# ----- Check some more prerequisites. -----

if false
then

echo
echo "Checking host automake..."
automake --version 2>/dev/null | grep automake

echo
echo "Checking host patch..."
patch --version | grep patch

fi

echo
echo "Checking host tar..."
tar --version

echo
echo "Checking host unzip..."
unzip | grep UnZip

echo
echo "Checking host makeinfo..."
makeinfo --version | grep 'GNU texinfo'
makeinfo_ver=$(makeinfo --version | grep 'GNU texinfo' | sed -e 's/.*) //' -e 's/\..*//')
if [ "${makeinfo_ver}" -lt "6" ]
then
  echo "makeinfo too old, abort."
  exit 1
fi

if which libtoolize > /dev/null; then
    libtoolize="libtoolize"
elif which glibtoolize >/dev/null; then
    libtoolize="glibtoolize"
else
    echo "$0: Error: libtool is required" >&2
    exit 1
fi

# ----- Get the project git repository. -----

if [ ! -d "${PROJECT_GIT_FOLDER_PATH}" ]
then

  cd "${WORK_FOLDER_PATH}"

  echo "If asked, enter ${USER} GitHub password for git clone"
  git clone "${PROEJCT_GIT_URL}" "${PROJECT_GIT_FOLDER_PATH}"

fi

# ----- Process "pull|checkout-dev|checkout-stable" actions. -----

do_repo_action() {

  # $1 = action (pull, checkout-dev, checkout-stable)

  # Update current branch and prepare autotools.
  echo
  if [ "${ACTION}" == "pull" ]
  then
    echo "Running git pull..."
  elif [ "${ACTION}" == "checkout-dev" ]
  then
    echo "Running git checkout gnu-mcu-eclipse-dev & pull..."
  elif [ "${ACTION}" == "checkout-stable" ]
  then
    echo "Running git checkout gnu-mcu-eclipse & pull..."
  fi

  if [ -d "${PROJECT_GIT_FOLDER_PATH}" ]
  then
    echo
    if [ "${USER}" == "ilg" ]
    then
      echo "If asked, enter ${USER} GitHub password for git pull"
    fi

    cd "${PROJECT_GIT_FOLDER_PATH}"

    if [ "${ACTION}" == "checkout-dev" ]
    then
      git checkout gnu-mcu-eclipse-dev
    elif [ "${ACTION}" == "checkout-stable" ]
    then
      git checkout gnu-mcu-eclipse
    fi

    if false
    then

    git pull --recurse-submodules
    git submodule update --init --recursive --remote

    git branch

    do_host_bootstrap

    rm -rf "${BUILD_FOLDER}/${APP_LC_NAME}"

    echo
    if [ "${ACTION}" == "pull" ]
    then
      echo "Pull completed. Proceed with a regular build."
    else
      echo "Checkout completed. Proceed with a regular build."
    fi

    else

      echo "Not implemented."
      exit 1

    fi

    exit 0
  else
	echo "No git folder."
    exit 1
  fi

}

# For this to work, the following settings are required:
# git branch --set-upstream-to=origin/gnu-mcu-eclipse-dev gnu-mcu-eclipse-dev
# git branch --set-upstream-to=origin/gnu-mcu-eclipse gnu-mcu-eclipse

case "${ACTION}" in
  pull|checkout-dev|checkout-stable)
    do_repo_action "${ACTION}"
    ;;
esac

# Get the current Git branch name, to know if we are building the stable or
# the development release.
do_host_get_git_head

# ----- Get current date. -----

# Use the UTC date as version in the name of the distribution file.
do_host_get_current_date

# ----- Get BINUTILS & GDB. -----

if [ ! -d "${WORK_FOLDER_PATH}/${BINUTILS_FOLDER_NAME}" ]
then
  cd "${WORK_FOLDER_PATH}"
  echo "Cloning '${BINUTILS_GIT_URL}'..."
  git clone --branch "${BINUTILS_GIT_BRANCH}" "${BINUTILS_GIT_URL}" "${BINUTILS_FOLDER_NAME}"
  cd "${BINUTILS_FOLDER_NAME}"
  git checkout -qf "${BINUTILS_GIT_COMMIT}"
fi

# ----- Get GCC. -----

if [ ! -d "${WORK_FOLDER_PATH}/${GCC_FOLDER_NAME}" ]
then
  cd "${WORK_FOLDER_PATH}"
  echo "Cloning '${GCC_GIT_URL}'..."
  git clone --branch "${GCC_GIT_BRANCH}" "${GCC_GIT_URL}" "${GCC_FOLDER_NAME}"
  cd "${GCC_FOLDER_NAME}"
  git checkout -qf "${GCC_GIT_COMMIT}"
fi

# ----- Get NEWLIB. -----

if [ ! -d "${WORK_FOLDER_PATH}/${NEWLIB_FOLDER_NAME}" ]
then
  cd "${WORK_FOLDER_PATH}"
  echo "Cloning '${NEWLIB_GIT_URL}'..."
  git clone --branch "${NEWLIB_GIT_BRANCH}" "${NEWLIB_GIT_URL}" "${NEWLIB_FOLDER_NAME}"
  cd "${NEWLIB_FOLDER_NAME}"
  git checkout -qf "${NEWLIB_GIT_COMMIT}"
fi

# ----- Get LIBZ. -----

# Download the Z library.
if [ ! -f "${DOWNLOAD_FOLDER_PATH}/${LIBZ_ARCHIVE}" ]
then
  mkdir -p "${DOWNLOAD_FOLDER_PATH}"

  cd "${DOWNLOAD_FOLDER_PATH}"
  echo "Downloading \"${LIBZ_ARCHIVE}\"..."
  curl -L "${LIBZ_URL}" --output "${LIBZ_ARCHIVE}"
fi

# Unpacked in the build folder.
if false
then

# Unpack LIBZ.
if [ ! -d "${WORK_FOLDER_PATH}/${LIBZ_FOLDER}" ]
then
  cd "${WORK_FOLDER_PATH}"
  tar -xzvf "${DOWNLOAD_FOLDER_PATH}/${LIBZ_ARCHIVE}"
fi

fi

# ----- Get GMP. -----

# Download the GMP library.
if [ ! -f "${DOWNLOAD_FOLDER_PATH}/${GMP_ARCHIVE}" ]
then
  mkdir -p "${DOWNLOAD_FOLDER_PATH}"

  cd "${DOWNLOAD_FOLDER_PATH}"
  echo "Downloading \"${GMP_ARCHIVE}\"..."
  curl -L "${GMP_URL}" --output "${GMP_ARCHIVE}"
fi

# Unpack GMP.
if [ ! -d "${WORK_FOLDER_PATH}/${GMP_FOLDER}" ]
then
  cd "${WORK_FOLDER_PATH}"
  tar -xzvf "${DOWNLOAD_FOLDER_PATH}/${GMP_ARCHIVE}"
fi


# ----- Get MPFR. -----

# Download the MPFR library.
if [ ! -f "${DOWNLOAD_FOLDER_PATH}/${MPFR_ARCHIVE}" ]
then
  mkdir -p "${DOWNLOAD_FOLDER_PATH}"

  cd "${DOWNLOAD_FOLDER_PATH}"
  echo "Downloading \"${MPFR_ARCHIVE}\"..."
  curl -L "${MPFR_URL}" --output "${MPFR_ARCHIVE}"
fi

# Unpack MPFR.
if [ ! -d "${WORK_FOLDER_PATH}/${MPFR_FOLDER}" ]
then
  cd "${WORK_FOLDER_PATH}"
  tar -xzvf "${DOWNLOAD_FOLDER_PATH}/${MPFR_ARCHIVE}"
fi


# ----- Get MPC. -----

# Download the MPC library.
if [ ! -f "${DOWNLOAD_FOLDER_PATH}/${MPC_ARCHIVE}" ]
then
  mkdir -p "${DOWNLOAD_FOLDER_PATH}"

  cd "${DOWNLOAD_FOLDER_PATH}"
  echo "Downloading \"${MPC_ARCHIVE}\"..."
  curl -L "${MPC_URL}" --output "${MPC_ARCHIVE}"
fi

# Unpack MPC.
if [ ! -d "${WORK_FOLDER_PATH}/${MPC_FOLDER}" ]
then
  cd "${WORK_FOLDER_PATH}"
  tar -xzvf "${DOWNLOAD_FOLDER_PATH}/${MPC_ARCHIVE}"
fi


# ----- Get ISL. -----

# Download the ISL library.
if [ ! -f "${DOWNLOAD_FOLDER_PATH}/${ISL_ARCHIVE}" ]
then
  mkdir -p "${DOWNLOAD_FOLDER_PATH}"

  cd "${DOWNLOAD_FOLDER_PATH}"
  echo "Downloading \"${ISL_ARCHIVE}\"..."
  curl -L "${ISL_URL}" --output "${ISL_ARCHIVE}"
fi

# Unpack ISL.
if [ ! -d "${WORK_FOLDER_PATH}/${ISL_FOLDER}" ]
then
  cd "${WORK_FOLDER_PATH}"
  tar -xzvf "${DOWNLOAD_FOLDER_PATH}/${ISL_ARCHIVE}"
fi


# v===========================================================================v
# Create the build script (needs to be separate for Docker).

script_name="build.sh"
script_file_path="${WORK_FOLDER_PATH}/scripts/${script_name}"

rm -f "${script_file_path}"
mkdir -p "$(dirname ${script_file_path})"
touch "${script_file_path}"

# Note: EOF is quoted to prevent substitutions here.
cat <<'EOF' >> "${script_file_path}"
#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set -x # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------

EOF
# The above marker must start in the first column.

# Note: EOF is not quoted to allow local substitutions.
cat <<EOF >> "${script_file_path}"

APP_NAME="${APP_NAME}"
APP_LC_NAME="${APP_LC_NAME}"
APP_UC_NAME="${APP_UC_NAME}"
GIT_HEAD="${GIT_HEAD}"
DISTRIBUTION_FILE_DATE="${DISTRIBUTION_FILE_DATE}"
PROJECT_GIT_FOLDER_NAME="${PROJECT_GIT_FOLDER_NAME}"
BINUTILS_FOLDER_NAME="${BINUTILS_FOLDER_NAME}"
GCC_FOLDER_NAME="${GCC_FOLDER_NAME}"
NEWLIB_FOLDER_NAME="${NEWLIB_FOLDER_NAME}"

LIBZ_FOLDER="${LIBZ_FOLDER}"
LIBZ_ARCHIVE="${LIBZ_ARCHIVE}"

GMP_FOLDER="${GMP_FOLDER}"
GMP_ARCHIVE="${GMP_ARCHIVE}"

MPFR_FOLDER="${MPFR_FOLDER}"
MPFR_ARCHIVE="${MPFR_ARCHIVE}"

MPC_FOLDER="${MPC_FOLDER}"
MPC_ARCHIVE="${MPC_ARCHIVE}"

ISL_FOLDER="${ISL_FOLDER}"
ISL_ARCHIVE="${ISL_ARCHIVE}"

do_no_strip="${do_no_strip}"
do_no_pdf="${do_no_pdf}"

gcc_target="${gcc_target}"
gcc_arch="${gcc_arch}"
gcc_abi="${gcc_abi}"

multilib_flags="${multilib_flags}"
cflags_for_target="-Os -mcmodel=medlow"
jobs="${jobs}"

branding="${branding}"

EOF
# The above marker must start in the first column.

# Propagate DEBUG to guest.
set +u
if [[ ! -z ${DEBUG} ]]
then
  echo "DEBUG=${DEBUG}" "${script_file_path}"
  echo
fi
set -u

# Note: EOF is quoted to prevent substitutions here.
cat <<'EOF' >> "${script_file_path}"

PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR:-""}

# For just in case.
export LC_ALL="C"
# export CONFIG_SHELL="/bin/bash"
export CONFIG_SHELL="/bin/sh"

script_name="$(basename "$0")"
args="$@"
docker_container_name=""
extra_path=""

while [ $# -gt 0 ]
do
  case "$1" in
    --build-folder)
      build_folder_path="$2"
      shift 2
      ;;
    --docker-container-name)
      docker_container_name="$2"
      shift 2
      ;;
    --target-name)
      target_name="$2"
      shift 2
      ;;
    --target-bits)
      target_bits="$2"
      shift 2
      ;;
    --work-folder)
      work_folder_path="$2"
      shift 2
      ;;
    --output-folder)
      output_folder_path="$2"
      shift 2
      ;;
    --distribution-folder)
      distribution_folder="$2"
      shift 2
      ;;
    --install-folder)
      install_folder="$2"
      shift 2
      ;;
    --download-folder)
      download_folder="$2"
      shift 2
      ;;
    --helper-script)
      helper_script_path="$2"
      shift 2
      ;;
    --group-id)
      group_id="$2"
      shift 2
      ;;
    --user-id)
      user_id="$2"
      shift 2
      ;;
    --host-uname)
      host_uname="$2"
      shift 2
      ;;
    --extra-path)
      extra_path="$2"
      shift 2
      ;;
    *)
      echo "Unknown option $1, exit."
      exit 1
  esac
done

download_folder_path=${download_folder_path:-"${work_folder_path}/download"}
git_folder_path="${work_folder_path}/${PROJECT_GIT_FOLDER_NAME}"
distribution_file_version=$(cat "${git_folder_path}/gnu-mcu-eclipse/VERSION")-${DISTRIBUTION_FILE_DATE}

app_prefix="${install_folder}/${APP_LC_NAME}"
app_prefix_doc="${app_prefix}/share/doc"

echo
uname -a

# Run the helper script in this shell, to get the support functions.
source "${helper_script_path}"

target_folder=${target_name}${target_bits:-""}

if [ "${target_name}" == "win" ]
then

  # For Windows targets, decide which cross toolchain to use.
  if [ ${target_bits} == "32" ]
  then
    cross_compile_prefix="i686-w64-mingw32"
  elif [ ${target_bits} == "64" ]
  then
    cross_compile_prefix="x86_64-w64-mingw32"
  fi

elif [ "${target_name}" == "osx" ]
then

  target_bits="64"

fi

# The \x2C is a comma in hex; without this trick the regular expression
# that processes this string in the Makefile, silently fails and the 
# bfdver.h file remains empty.
branding="${branding}\x2C ${target_bits}-bits"

if [ -f "${extra_path}/${gcc_target}-gcc" ]
then
  PATH="${extra_path}":${PATH}
  echo ${PATH}
fi

mkdir -p "${build_folder_path}"
cd "${build_folder_path}"


# ----- Test if various tools are present -----

echo
echo "Checking automake..."
automake --version 2>/dev/null | grep automake

if [ "${target_name}" != "osx" ]
then
  echo "Checking readelf..."
  readelf --version | grep readelf
fi

if [ "${target_name}" == "win" ]
then
  echo "Checking ${cross_compile_prefix}-gcc..."
  ${cross_compile_prefix}-gcc --version 2>/dev/null | egrep -e 'gcc|clang'

  echo "Checking unix2dos..."
  unix2dos --version 2>&1 | grep unix2dos

  echo "Checking makensis..."
  echo "makensis $(makensis -VERSION)"

  apt-get --yes install zip

  echo "Checking zip..."
  zip -v | grep "This is Zip"
else
  echo "Checking gcc..."
  gcc --version 2>/dev/null | egrep -e 'gcc|clang'
fi

if [ "${target_name}" == "debian" ]
then
  echo "Checking patchelf..."
  patchelf --version
fi

echo "Checking shasum..."
shasum --version

# ----- Build and install the ZLIB library. -----

libz_stamp_file="${build_folder_path}/${LIBZ_FOLDER}/stamp-install-completed"

# if [ ! -f "${install_folder}/lib/libz.a" ]
if [ ! -f "${libz_stamp_file}" ]
then

  rm -rf "${build_folder_path}/${LIBZ_FOLDER}"
  mkdir -p "${build_folder_path}/${LIBZ_FOLDER}"

  mkdir -p "${install_folder}"

  echo
  echo "Running zlib configure..."

  cd "${build_folder_path}"
  tar -xzvf "${download_folder_path}/${LIBZ_ARCHIVE}"

  cd "${build_folder_path}/${LIBZ_FOLDER}"

  if [ "${target_name}" == "win" ]
  then

    true # No configure on windows

  elif [ "${target_name}" == "debian" ]
  then
    CFLAGS="-m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    PKG_CONFIG="${git_folder_path}/gnu-mcu-eclipse/scripts/pkg-config-dbg" \
    PKG_CONFIG_LIBDIR="${install_folder}/lib/pkgconfig" \
    \
    bash "configure" \
      --prefix="${install_folder}" \
      --static

  elif [ "${target_name}" == "osx" ]
  then
    CFLAGS="-Wno-shift-negative-value -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    PKG_CONFIG="${git_folder_path}/gnu-mcu-eclipse/scripts/pkg-config-dbg" \
    PKG_CONFIG_LIBDIR="${install_folder}/lib/pkgconfig" \
    \
    bash "configure" \
      --prefix="${install_folder}" \
      --static

  fi

  echo
  echo "Running zlib make install..."

  if [ "${target_name}" == "win" ]
  then

    sed -e 's/PREFIX =/#PREFIX =/' -e 's/STRIP = .*/STRIP = file /' -e 's/SHARED_MODE=0/SHARED_MODE=1/' win32/Makefile.gcc >win32/Makefile.gcc2

    CFLAGS="-m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    LDFLAGS="-v" \
    PREFIX="${cross_compile_prefix}-" \
    INCLUDE_PATH="${install_folder}/include" \
    LIBRARY_PATH="${install_folder}/lib" \
    BINARY_PATH="${install_folder}/bin" \
    make "${jobs}" -f win32/Makefile.gcc2 install

  else # osx & debian

    # Build.
    # make clean
    make "${jobs}"
    make "${jobs}" install
  fi

  touch "${libz_stamp_file}"
fi

# ----- Build and install the GMP library. -----

gmp_stamp_file="${build_folder_path}/${GMP_FOLDER}/stamp-install-completed"

if [ ! -f "${gmp_stamp_file}" ]
then

  rm -rf "${build_folder_path}/${GMP_FOLDER}"
  mkdir -p "${build_folder_path}/${GMP_FOLDER}"

  mkdir -p "${install_folder}"

  echo
  echo "Running gmp configure..."

  cd "${build_folder_path}/${GMP_FOLDER}"

  if [ "${target_name}" == "win" ]
  then

    CFLAGS="-Wno-unused-value -Wno-empty-translation-unit -Wno-tautological-compare -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib" \
    \
    bash "${work_folder_path}/${GMP_FOLDER}/configure" \
      --prefix="${install_folder}" \
      \
      --build="$(uname -m)-linux-gnu" \
      --host="${cross_compile_prefix}" \
      \
      --disable-shared \
      --enable-static
    
  elif [ \( "${target_name}" == "osx" \) -o \( "${target_name}" == "debian" \) ]
  then

    CFLAGS="-Wno-unused-value -Wno-empty-translation-unit -Wno-tautological-compare -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib" \
    \
    bash "${work_folder_path}/${GMP_FOLDER}/configure" \
      --prefix="${install_folder}" \
      \
      --disable-shared \
      --enable-static

  fi

  echo
  echo "Running gmp make..."

  # Build.
  # make clean
  make "${jobs}"
  make "${jobs}" install

  touch "${gmp_stamp_file}"
fi

# ----- Build and install the MPFR library. -----

mpfr_stamp_file="${build_folder_path}/${MPFR_FOLDER}/stamp-install-completed"

if [ ! -f "${mpfr_stamp_file}" ]
then

  rm -rf "${build_folder_path}/${MPFR_FOLDER}"
  mkdir -p "${build_folder_path}/${MPFR_FOLDER}"

  mkdir -p "${install_folder}"

  echo
  echo "Running mpfr configure..."

  cd "${build_folder_path}/${MPFR_FOLDER}"

  if [ "${target_name}" == "win" ]
  then

    CFLAGS="-m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib" \
    \
    bash "${work_folder_path}/${MPFR_FOLDER}/configure" \
      --prefix="${install_folder}" \
      \
      --build="$(uname -m)-linux-gnu" \
      --host="${cross_compile_prefix}" \
      \
      --disable-warnings \
      --disable-shared \
      --enable-static

  elif [ \( "${target_name}" == "osx" \) -o \( "${target_name}" == "debian" \) ]
  then

    CFLAGS="-m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib" \
    \
    bash "${work_folder_path}/${MPFR_FOLDER}/configure" \
      --prefix="${install_folder}" \
      \
      --disable-warnings \
      --disable-shared \
      --enable-static

  fi

  echo
  echo "Running mpfr make..."

  # Build.
  # make clean
  make "${jobs}"
  make "${jobs}" install

  touch "${mpfr_stamp_file}"
fi

# ----- Build and install the MPC library. -----

mpc_stamp_file="${build_folder_path}/${MPC_FOLDER}/stamp-install-completed"

if [ ! -f "${mpc_stamp_file}" ]
then

  rm -rf "${build_folder_path}/${MPC_FOLDER}"
  mkdir -p "${build_folder_path}/${MPC_FOLDER}"

  mkdir -p "${install_folder}"

  echo
  echo "Running mpc configure..."

  cd "${build_folder_path}/${MPC_FOLDER}"

  if [ "${target_name}" == "win" ]
  then

    CFLAGS="-m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib" \
    \
    bash "${work_folder_path}/${MPC_FOLDER}/configure" \
      --prefix="${install_folder}" \
      \
      --build="$(uname -m)-linux-gnu" \
      --host="${cross_compile_prefix}" \
      \
      --disable-shared \
      --enable-static

  elif [ \( "${target_name}" == "osx" \) -o \( "${target_name}" == "debian" \) ]
  then

    CFLAGS="-m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib" \
    \
    bash "${work_folder_path}/${MPC_FOLDER}/configure" \
      --prefix="${install_folder}" \
      \
      --disable-shared \
      --enable-static

  fi

  echo
  echo "Running mpc make..."

  # Build.
  # make clean
  make "${jobs}"
  make "${jobs}" install

  touch "${mpc_stamp_file}"
fi

# ----- Build and install the ISL library. -----

isl_stamp_file="${build_folder_path}/${ISL_FOLDER}/stamp-install-completed"

if [ ! -f "${isl_stamp_file}" ]
then

  rm -rf "${build_folder_path}/${ISL_FOLDER}"
  mkdir -p "${build_folder_path}/${ISL_FOLDER}"

  mkdir -p "${install_folder}"

  echo
  echo "Running isl configure..."

  cd "${build_folder_path}/${ISL_FOLDER}"

  if [ "${target_name}" == "win" ]
  then

    CFLAGS="-Wno-dangling-else -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib" \
    \
    bash "${work_folder_path}/${ISL_FOLDER}/configure" \
      --prefix="${install_folder}" \
      \
      --build="$(uname -m)-linux-gnu" \
      --host="${cross_compile_prefix}" \
      \
      --disable-shared \
      --enable-static

  elif [ \( "${target_name}" == "osx" \) -o \( "${target_name}" == "debian" \) ]
  then

    CFLAGS="-Wno-dangling-else -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib" \
    \
    bash "${work_folder_path}/${ISL_FOLDER}/configure" \
      --prefix="${install_folder}" \
      \
      --disable-shared \
      --enable-static

  fi

  echo
  echo "Running isl make..."

  # Build.
  # make clean
  make "${jobs}"
  make "${jobs}" install

  touch "${isl_stamp_file}"
fi


# ----- Build BINUTILS. -----

binutils_folder="binutils-gdb"
binutils_stamp_file="${build_folder_path}/${binutils_folder}/stamp-install-completed"

if [ ! -f "${binutils_stamp_file}" ]
then

  rm -rfv "${build_folder_path}/${binutils_folder}"
  mkdir -p "${build_folder_path}/${binutils_folder}"

  echo
  echo "Running binutils configure..."

  cd "${build_folder_path}/${binutils_folder}"

  mkdir -p "${app_prefix}"

  if [ "${target_name}" == "win" ]
  then
    
    CFLAGS="-Wno-unknown-warning-option -Wno-extended-offsetof -Wno-deprecated-declarations -Wno-incompatible-pointer-types-discards-qualifiers -Wno-implicit-function-declaration -Wno-parentheses -Wno-format-nonliteral -Wno-shift-count-overflow -Wno-constant-logical-operand -Wno-shift-negative-value -Wno-format -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CXXFLAGS="-Wno-format-nonliteral -Wno-format-security -Wno-deprecated -Wno-unknown-warning-option -Wno-c++11-narrowing -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib -Wl,--gc-sections" \
    \
    bash "${work_folder_path}/${BINUTILS_FOLDER_NAME}/configure" \
      --prefix="${app_prefix}" \
      --infodir="${app_prefix_doc}/info" \
      --mandir="${app_prefix_doc}/man" \
      --htmldir="${app_prefix_doc}/html" \
      --pdfdir="${app_prefix_doc}/pdf" \
      \
      --build="$(uname -m)-linux-gnu" \
      --host="${cross_compile_prefix}" \
      --target="${gcc_target}" \
      \
      --with-pkgversion="${branding}" \
      \
      --with-mpc="${install_folder}" \
      --with-mpfr="${install_folder}" \
      --with-gmp="${install_folder}" \
      --with-isl="${install_folder}" \
      \
      --disable-werror \
      --disable-build-warnings \
      --disable-gdb-build-warnings \
      --disable-nls \
      --enable-plugins \
      --without-system-zlib \
      --with-sysroot="${app_prefix}" \
    | tee "configure-output.txt"

  elif [ "${target_name}" == "osx" ]
  then

    # --with-system-zlib assume libz is available on osx & debian

    CFLAGS="-Wno-unknown-warning-option -Wno-extended-offsetof -Wno-deprecated-declarations -Wno-incompatible-pointer-types-discards-qualifiers -Wno-implicit-function-declaration -Wno-parentheses -Wno-format-nonliteral -Wno-shift-count-overflow -Wno-constant-logical-operand -Wno-shift-negative-value -Wno-format -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CXXFLAGS="-Wno-format-nonliteral -Wno-format-security -Wno-deprecated -Wno-unknown-warning-option -Wno-c++11-narrowing -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib" \
    \
    bash "${work_folder_path}/${BINUTILS_FOLDER_NAME}/configure" \
      --prefix="${app_prefix}" \
      --infodir="${app_prefix_doc}/info" \
      --mandir="${app_prefix_doc}/man" \
      --htmldir="${app_prefix_doc}/html" \
      --pdfdir="${app_prefix_doc}/pdf" \
      \
      --target="${gcc_target}" \
      \
      --with-pkgversion="${branding}" \
      \
      --with-mpc="${install_folder}" \
      --with-mpfr="${install_folder}" \
      --with-gmp="${install_folder}" \
      --with-isl="${install_folder}" \
      \
      --disable-werror \
      --disable-build-warnings \
      --disable-gdb-build-warnings \
      --disable-nls \
      --enable-plugins \
      --with-system-zlib \
      --with-sysroot="${app_prefix}" \
    | tee "configure-output.txt"

  elif [ "${target_name}" == "debian" ]
  then

    # --with-system-zlib assume libz is available on osx & debian

    CFLAGS="-Wno-unknown-warning-option -Wno-extended-offsetof -Wno-deprecated-declarations -Wno-incompatible-pointer-types-discards-qualifiers -Wno-implicit-function-declaration -Wno-parentheses -Wno-format-nonliteral -Wno-shift-count-overflow -Wno-constant-logical-operand -Wno-shift-negative-value -Wno-format -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CXXFLAGS="-Wno-format-nonliteral -Wno-format-security -Wno-deprecated -Wno-unknown-warning-option -Wno-c++11-narrowing -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
    CPPFLAGS="-I${install_folder}/include" \
    LDFLAGS="-L${install_folder}/lib -Wl,--gc-sections" \
    \
    bash "${work_folder_path}/${BINUTILS_FOLDER_NAME}/configure" \
      --prefix="${app_prefix}" \
      --infodir="${app_prefix_doc}/info" \
      --mandir="${app_prefix_doc}/man" \
      --htmldir="${app_prefix_doc}/html" \
      --pdfdir="${app_prefix_doc}/pdf" \
      \
      --target="${gcc_target}" \
      \
      --with-pkgversion="${branding}" \
      \
      --with-mpc="${install_folder}" \
      --with-mpfr="${install_folder}" \
      --with-gmp="${install_folder}" \
      --with-isl="${install_folder}" \
      \
      --disable-werror \
      --disable-build-warnings \
      --disable-gdb-build-warnings \
      --disable-nls \
      --enable-plugins \
      --with-system-zlib \
      --with-sysroot="${app_prefix}" \
    | tee "configure-output.txt"

  fi
 
  echo
  echo "Running binutils make..."
  
  (
    # make clean
    make "${jobs}" all
    make "${jobs}" install
    if [ -z "${do_no_pdf}" ]
    then
      make "${jobs}" pdf
      make "${jobs}" install-pdf
    fi
  ) | tee "make-newlib-all-output.txt"

  # The binutils were successfuly created.
  touch "${binutils_stamp_file}"

fi


# ----- Save PATH and set it to include the new binaries -----

saved_path=${PATH}
PATH="${app_prefix}/bin":${PATH}

# ----- Build GCC, first stage. -----

# The first stage creates a compiler without libraries, that is required
# to compile newlib.

gcc_folder="gcc"
gcc_stage1_folder="gcc-first"
gcc_stage1_stamp_file="${build_folder_path}/${gcc_stage1_folder}/stamp-install-completed"
# mkdir -p "${build_folder_path}/${gcc_stage1_folder}"

if [ ! -f "${gcc_stage1_stamp_file}" ]
then

  mkdir -p "${build_folder_path}/${gcc_stage1_folder}"
  cd "${build_folder_path}/${gcc_stage1_folder}"

  if [ ! -f "config.status" ]
  then 

    echo
    echo "Running first stage configure..."

    # https://gcc.gnu.org/install/configure.html
    # --enable-shared[=package[,…]] build shared versions of libraries
    # --enable-tls specify that the target supports TLS (Thread Local Storage). 
    # --enable-nls enables Native Language Support (NLS)
    # --enable-checking=list the compiler is built to perform internal consistency checks of the requested complexity. ‘yes’ (most common checks)
    # --with-headers=dir specify that target headers are available when building a cross compiler
    # --with-newlib Specifies that ‘newlib’ is being used as the target C library. This causes `__eprintf`` to be omitted from `libgcc.a`` on the assumption that it will be provided by newlib.
    # --enable-languages=c newlib does not use C++, so C should be enough
    
    if [ "${target_name}" == "win" ]
    then

      # --with-system-zlib libz is available in the development environment

      # All variables below are passed on the command line before 'configure'.
      # Be sure all these lines end in '\' to ensure lines are concatenated.
      CFLAGS="-Wno-tautological-compare -Wno-deprecated-declarations -Wno-unknown-warning-option -Wno-unused-value -Wno-extended-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CXXFLAGS="-Wno-format-security -Wno-char-subscripts -Wno-deprecated -Wno-array-bounds -Wno-invalid-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CPPFLAGS="-I${install_folder}/include" \
      LDFLAGS="-L${install_folder}/lib -Wl,--gc-sections" \
      \
      bash "${work_folder_path}/${GCC_FOLDER_NAME}/configure" \
        --prefix="${app_prefix}"  \
        --infodir="${app_prefix_doc}/info" \
        --mandir="${app_prefix_doc}/man" \
        --htmldir="${app_prefix_doc}/html" \
        --pdfdir="${app_prefix_doc}/pdf" \
        \
        --build="$(uname -m)-linux-gnu" \
        --host="${cross_compile_prefix}" \
        --target="${gcc_target}" \
        \
        --with-pkgversion="${branding}" \
        \
        --with-mpc="${install_folder}" \
        --with-mpfr="${install_folder}" \
        --with-gmp="${install_folder}" \
        --with-isl="${install_folder}" \
        \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --enable-languages=c \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --enable-checking=no \
        "${multilib_flags}" \
        --with-system-zlib \
        --with-newlib \
        --without-headers \
        --with-gnu-as \
        --with-gnu-ld \
        --with-abi="${gcc_abi}" \
        --with-arch="${gcc_arch}" \
        --with-sysroot="${app_prefix}" \
        CFLAGS_FOR_TARGET="${cflags_for_target}" \
        | tee "configure-output.txt"

    elif [ \( "${target_name}" == "osx" \) -o \( "${target_name}" == "debian" \) ]
    then

      # --with-system-zlib libz is available in the development environment

      # All variables below are passed on the command line before 'configure'.
      # Be sure all these lines end in '\' to ensure lines are concatenated.
      CFLAGS="-Wno-tautological-compare -Wno-deprecated-declarations -Wno-unknown-warning-option -Wno-unused-value -Wno-extended-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CXXFLAGS="-Wno-keyword-macro -Wno-unused-private-field -Wno-format-security -Wno-char-subscripts -Wno-deprecated -Wno-gnu-zero-variadic-macro-arguments -Wno-mismatched-tags -Wno-c99-extensions -Wno-array-bounds -Wno-extended-offsetof -Wno-invalid-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CPPFLAGS="-I${install_folder}/include" \
      LDFLAGS="-L${install_folder}/lib" \
      \
      bash "${work_folder_path}/${GCC_FOLDER_NAME}/configure" \
        --prefix="${app_prefix}"  \
        --infodir="${app_prefix_doc}/info" \
        --mandir="${app_prefix_doc}/man" \
        --htmldir="${app_prefix_doc}/html" \
        --pdfdir="${app_prefix_doc}/pdf" \
        \
        --target="${gcc_target}" \
        \
        --with-pkgversion="${branding}" \
        \
        --with-mpc="${install_folder}" \
        --with-mpfr="${install_folder}" \
        --with-gmp="${install_folder}" \
        --with-isl="${install_folder}" \
        \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --enable-languages=c \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --enable-checking=no \
        "${multilib_flags}" \
        --with-system-zlib \
        --with-newlib \
        --without-headers \
        --with-gnu-as \
        --with-gnu-ld \
        --with-abi="${gcc_abi}" \
        --with-arch="${gcc_arch}" \
        --with-sysroot="${app_prefix}" \
        CFLAGS_FOR_TARGET="${cflags_for_target}" \
        | tee "configure-output.txt"

    fi

  fi

  # ----- Partial build, without documentation. -----
  echo
  echo "Running first stage make..."

  cd "${build_folder_path}/${gcc_stage1_folder}"

  (
    # No need to make 'all', 'all-gcc' is enough to compile the libraries.
    make "${jobs}" all-gcc
    make "${jobs}" install-gcc
  ) | tee "make-all-output.txt"
  touch "${gcc_stage1_stamp_file}"

fi

# ----- Build newlib. -----

newlib_folder="newlib"
newlib_stamp_file="${build_folder_path}/${newlib_folder}/stamp-install-completed"
# mkdir -p "${build_folder_path}/${newlib_folder}"

if [ ! -f "${newlib_stamp_file}" ]
then

  mkdir -p "${build_folder_path}/${newlib_folder}"
  cd "${build_folder_path}/${newlib_folder}"

  if [ ! -f "config.status" ]
  then 

    echo
    echo "Running newlib configure..."

    if [ "${target_name}" == "win" ]
    then

      # All variables below are passed on the command line before 'configure'.
      # Be sure all these lines end in '\' to ensure lines are concatenated.
      CFLAGS="-m${target_bits} -pipe" \
      CXXFLAGS="-m${target_bits} -pipe" \
      \
      bash "${work_folder_path}/${NEWLIB_FOLDER_NAME}/configure" \
        --prefix="${app_prefix}"  \
        --infodir="${app_prefix_doc}/info" \
        --mandir="${app_prefix_doc}/man" \
        --htmldir="${app_prefix_doc}/html" \
        --pdfdir="${app_prefix_doc}/pdf" \
        \
        --build="$(uname -m)-linux-gnu" \
        --host="${cross_compile_prefix}" \
        --target="${gcc_target}" \
        \
        --enable-newlib-io-long-double \
        --enable-newlib-io-long-long \
        --enable-newlib-io-c99-formats \
        --enable-newlib-register-fini \
        --enable-newlib-retargetable-locking \
        --disable-newlib-supplied-syscalls \
        --disable-nls \
        CFLAGS_FOR_TARGET="-Os -mcmodel=medlow -ffunction-sections -fdata-sections" \
        CXXFLAGS_FOR_TARGET="-Os -mcmodel=medlow -ffunction-sections -fdata-sections" \
        | tee "configure-output.txt"

    elif [ \( "${target_name}" == "osx" \) -o \( "${target_name}" == "debian" \) ]
    then

      # All variables below are passed on the command line before 'configure'.
      # Be sure all these lines end in '\' to ensure lines are concatenated.
      CFLAGS="-m${target_bits} -pipe" \
      CXXFLAGS="-m${target_bits} -pipe" \
      \
      bash "${work_folder_path}/${NEWLIB_FOLDER_NAME}/configure" \
        --prefix="${app_prefix}"  \
        --infodir="${app_prefix_doc}/info" \
        --mandir="${app_prefix_doc}/man" \
        --htmldir="${app_prefix_doc}/html" \
        --pdfdir="${app_prefix_doc}/pdf" \
        \
        --target="${gcc_target}" \
        \
        --enable-newlib-io-long-double \
        --enable-newlib-io-long-long \
        --enable-newlib-io-c99-formats \
        --enable-newlib-register-fini \
        --enable-newlib-retargetable-locking \
        --disable-newlib-supplied-syscalls \
        --disable-nls \
        CFLAGS_FOR_TARGET="-Os -mcmodel=medlow -ffunction-sections -fdata-sections" \
        CXXFLAGS_FOR_TARGET="-Os -mcmodel=medlow -ffunction-sections -fdata-sections" \
        | tee "configure-output.txt"

    fi
  
  fi

  echo
  echo "Running newlib make..."
  cd "${build_folder_path}/${newlib_folder}"
  (
    # make clean
    make "${jobs}" all 
    make "${jobs}" install 

    if [ -z "${do_no_pdf}" ]
    then

      # Apparently parallel build not reliable on Debian.
      make "${jobs}" pdf

      /usr/bin/install -v -c -m 644 \
        "${gcc_target}/libgloss/doc/porting.pdf" "${app_prefix_doc}/pdf"
      /usr/bin/install -v -c -m 644 \
        "${gcc_target}/newlib/libc/libc.pdf" "${app_prefix_doc}/pdf"
      /usr/bin/install -v -c -m 644 \
        "${gcc_target}/newlib/libm/libm.pdf" "${app_prefix_doc}/pdf"

      # Fails on Debian
      # make html
      # TODO: install html to "${app_prefix_doc}/html"
    
    fi

  ) | tee "make-newlib-all-output.txt"

  touch "${newlib_stamp_file}"
fi

gcc_stage2_folder="gcc-second"
gcc_stage2_stamp_file="${build_folder_path}/${gcc_stage2_folder}/stamp-install-completed"
# mkdir -p "${build_folder_path}/${gcc_stage2_folder}"

if [ ! -f "${gcc_stage2_stamp_file}" ]
then

  mkdir -p "${build_folder_path}/${gcc_stage2_folder}"
  cd "${build_folder_path}/${gcc_stage2_folder}"

  if [ ! -f "config.status" ]
  then

    # https://gcc.gnu.org/install/configure.html
    echo
    echo "Running second stage configure RISC-V GCC ..."

    if [ "${target_name}" == "win" ]
    then

      # --without-system-zlib assume libz is not available

      # All variables below are passed on the command line before 'configure'.
      # Be sure all these lines end in '\' to ensure lines are concatenated.
      CFLAGS="-Wno-tautological-compare -Wno-deprecated-declarations -Wno-unknown-warning-option -Wno-unused-value -Wno-extended-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CXXFLAGS="-Wno-format-security -Wno-char-subscripts -Wno-deprecated -Wno-array-bounds -Wno-invalid-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CPPFLAGS="-I${install_folder}/include" \
      LDFLAGS="-L${install_folder}/lib -Wl,--gc-sections" \
      \
      bash "${work_folder_path}/${GCC_FOLDER_NAME}/configure" \
        --prefix="${app_prefix}"  \
        --infodir="${app_prefix_doc}/info" \
        --mandir="${app_prefix_doc}/man" \
        --htmldir="${app_prefix_doc}/html" \
        --pdfdir="${app_prefix_doc}/pdf" \
        \
        --build="$(uname -m)-linux-gnu" \
        --host="${cross_compile_prefix}" \
        --target="${gcc_target}" \
        \
        --with-pkgversion="${branding}" \
        \
        --with-mpc="${install_folder}" \
        --with-mpfr="${install_folder}" \
        --with-gmp="${install_folder}" \
        --with-isl="${install_folder}" \
        \
        --disable-shared \
        --disable-threads \
        --enable-plugins \
        --enable-tls \
        --enable-languages=c,c++ \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --enable-checking=yes \
        "${multilib_flags}" \
        --without-system-zlib \
        --with-newlib \
        --with-headers="${install_folder}/${gcc_target}/include" \
        --with-gnu-as \
        --with-gnu-ld \
        --with-abi="${gcc_abi}" \
        --with-arch="${gcc_arch}" \
        --with-sysroot="${app_prefix}" \
        CFLAGS_FOR_TARGET="${cflags_for_target}" \
        | tee "configure-output.txt"

    elif [ "${target_name}" == "osx" ]
    then

      # --with-system-zlib assume libz is available

      # All variables below are passed on the command line before 'configure'.
      # Be sure all these lines end in '\' to ensure lines are concatenated.
      CFLAGS="-Wno-tautological-compare -Wno-deprecated-declarations -Wno-unknown-warning-option -Wno-unused-value -Wno-extended-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CXXFLAGS="-Wno-keyword-macro -Wno-unused-private-field -Wno-format-security -Wno-char-subscripts -Wno-deprecated -Wno-gnu-zero-variadic-macro-arguments -Wno-mismatched-tags -Wno-c99-extensions -Wno-array-bounds -Wno-extended-offsetof -Wno-invalid-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CPPFLAGS="-I${install_folder}/include" \
      LDFLAGS="-L${install_folder}/lib" \
      \
      bash "${work_folder_path}/${GCC_FOLDER_NAME}/configure" \
        --prefix="${app_prefix}"  \
        --infodir="${app_prefix_doc}/info" \
        --mandir="${app_prefix_doc}/man" \
        --htmldir="${app_prefix_doc}/html" \
        --pdfdir="${app_prefix_doc}/pdf" \
        \
        --target="${gcc_target}" \
        \
        --with-pkgversion="${branding}" \
        \
        --with-mpc="${install_folder}" \
        --with-mpfr="${install_folder}" \
        --with-gmp="${install_folder}" \
        --with-isl="${install_folder}" \
        \
        --disable-shared \
        --disable-threads \
        --enable-plugins \
        --enable-tls \
        --enable-languages=c,c++ \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --enable-checking=yes \
        "${multilib_flags}" \
        --with-system-zlib \
        --with-newlib \
        --with-headers="${install_folder}/${gcc_target}/include" \
        --with-gnu-as \
        --with-gnu-ld \
        --with-abi="${gcc_abi}" \
        --with-arch="${gcc_arch}" \
        --with-sysroot="${app_prefix}" \
        CFLAGS_FOR_TARGET="${cflags_for_target}" \
        | tee "configure-output.txt"
  
    elif [ "${target_name}" == "debian" ]
    then

      # --with-system-zlib assume libz is available

      # All variables below are passed on the command line before 'configure'.
      # Be sure all these lines end in '\' to ensure lines are concatenated.
      CFLAGS="-Wno-tautological-compare -Wno-deprecated-declarations -Wno-unknown-warning-option -Wno-unused-value -Wno-extended-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CXXFLAGS="-Wno-keyword-macro -Wno-unused-private-field -Wno-format-security -Wno-char-subscripts -Wno-deprecated -Wno-gnu-zero-variadic-macro-arguments -Wno-mismatched-tags -Wno-c99-extensions -Wno-array-bounds -Wno-extended-offsetof -Wno-invalid-offsetof -m${target_bits} -pipe -ffunction-sections -fdata-sections" \
      CPPFLAGS="-I${install_folder}/include" \
      LDFLAGS="-L${install_folder}/lib -Wl,--gc-sections" \
      \
      bash "${work_folder_path}/${GCC_FOLDER_NAME}/configure" \
        --prefix="${app_prefix}"  \
        --infodir="${app_prefix_doc}/info" \
        --mandir="${app_prefix_doc}/man" \
        --htmldir="${app_prefix_doc}/html" \
        --pdfdir="${app_prefix_doc}/pdf" \
        \
        --target="${gcc_target}" \
        \
        --with-pkgversion="${branding}" \
        \
        --with-mpc="${install_folder}" \
        --with-mpfr="${install_folder}" \
        --with-gmp="${install_folder}" \
        --with-isl="${install_folder}" \
        \
        --disable-shared \
        --disable-threads \
        --enable-plugins \
        --enable-tls \
        --enable-languages=c,c++ \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --enable-checking=yes \
        "${multilib_flags}" \
        --with-system-zlib \
        --with-newlib \
        --with-headers="${install_folder}/${gcc_target}/include" \
        --with-gnu-as \
        --with-gnu-ld \
        --with-abi="${gcc_abi}" \
        --with-arch="${gcc_arch}" \
        --with-sysroot="${app_prefix}" \
        CFLAGS_FOR_TARGET="${cflags_for_target}" \
        | tee "configure-output.txt"
  
    fi

  fi

  # ----- Full build, with documentation. -----
  echo
  echo "Running second stage make..."

  cd "${build_folder_path}/${gcc_stage2_folder}"

  (
    make "${jobs}" all
    make "${jobs}" install
    if [ -z "${do_no_pdf}" ]
    then

      # set +e
      make "${jobs}" install-pdf install-html
      # set -e

    fi
  ) | tee "make-all-output.txt"

  touch "${gcc_stage2_stamp_file}"
fi

# -------------------------------------------------------------

# Restore PATH
PATH="${saved_path}"

# ----- Copy dynamic libraries to the install bin folder. -----

checking_stamp_file="${build_folder_path}/stamp_check_completed"

if [ ! -f "${checking_stamp_file}" ]
then

  if [ "${target_name}" == "win" ]
  then

    if [ -z "${do_no_strip}" ]
    then
      echo
      echo "Striping executables..."

      ${cross_compile_prefix}-strip \
        "${app_prefix}/bin"/*.exe
    fi

    echo
    echo "Copying DLLs..."

    # Identify the current cross gcc version, to locate the specific dll folder.
    CROSS_GCC_VERSION=$(${cross_compile_prefix}-gcc --version | grep 'gcc' | sed -e 's/.*\s\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\).*/\1.\2.\3/')
    CROSS_GCC_VERSION_SHORT=$(echo $CROSS_GCC_VERSION | sed -e 's/\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\).*/\1.\2/')
    SUBLOCATION="-win32"

    echo "${CROSS_GCC_VERSION}" "${CROSS_GCC_VERSION_SHORT}" "${SUBLOCATION}"

    if [ "${target_bits}" == "32" ]
    then
      do_container_win_copy_gcc_dll "libgcc_s_sjlj-1.dll"
    elif [ "${target_bits}" == "64" ]
    then
      do_container_win_copy_gcc_dll "libgcc_s_seh-1.dll"
    fi

    # do_container_win_copy_libwinpthread_dll

    if [ -z "${do_no_strip}" ]
    then
      echo
      echo "Striping DLLs..."

      ${cross_compile_prefix}-strip "${app_prefix}/bin/"*.dll
    fi

    (
      cd "${app_prefix}/bin"
      for f in *
      do
        if [ -x "${f}" ]
        then
          do_container_win_check_libs "${f}"
        fi
      done
    )

  elif [ "${target_name}" == "debian" ]
  then

    if [ -z "${do_no_strip}" ]
    then
      echo
      echo "Striping executables..."

      strip "${app_prefix}/bin"/*
    fi

    # Generally this is a very important detail: 'patchelf' sets "runpath"
    # in the ELF file to $ORIGIN, telling the loader to search
    # for the libraries first in LD_LIBRARY_PATH (if set) and, if not found there,
    # to look in the same folder where the executable is located -- where
    # this build script installs the required libraries. 
    # Note: LD_LIBRARY_PATH can be set by a developer when testing alternate 
    # versions of the openocd libraries without removing or overwriting 
    # the installed library files -- not done by the typical user. 
    # Note: patchelf changes the original "rpath" in the executable (a path 
    # in the docker container) to "runpath" with the value "$ORIGIN". rpath 
    # instead or runpath could be set to $ORIGIN but rpath is searched before
    # LD_LIBRARY_PATH which requires an installed library be deleted or
    # overwritten to test or use an alternate version. In addition, the usage of
    # rpath is deprecated. See man ld.so for more info.  
    # Also, runpath is added to the installed library files using patchelf, with 
    # value $ORIGIN, in the same way. See patchelf usage in build-helper.sh.
    #
    # In particular for GCC there should be no shared libraries.

    find "${app_prefix}/bin" -type f -executable \
        -exec patchelf --debug --set-rpath '$ORIGIN' "{}" \;

    if false # ?????
    then

      echo
      echo "Copying shared libs..."

      if [ "${target_bits}" == "64" ]
      then
        distro_machine="x86_64"
      elif [ "${target_bits}" == "32" ]
      then
        distro_machine="i386"
      fi

      do_container_linux_copy_librt_so

    fi

    (
      cd "${app_prefix}/bin"
      for f in *
      do
        if [ -x "${f}" ]
        then
          do_container_linux_check_libs "${f}"
        fi
      done
    )

  elif [ "${target_name}" == "osx" ]
  then

    if [ -z "${do_no_strip}" ]
    then
      echo
      echo "Striping executables..."

      strip "${app_prefix}/bin"/*
    fi

    (
      cd "${app_prefix}/bin"
      for f in *
      do
        if [ -x "${f}" ]
        then
          do_container_mac_check_libs "${f}"
        fi
      done
    )

  fi

  touch "${checking_stamp_file}"
fi

# ----- Copy the license files. -----

license_stamp_file="${build_folder_path}/stamp_license_completed"

if [ ! -f "${license_stamp_file}" ]
then

  echo
  echo "Copying license files..."

  do_container_copy_license \
    "${work_folder_path}/${BINUTILS_FOLDER_NAME}" "${binutils_folder}"
  do_container_copy_license \
    "${work_folder_path}/${GCC_FOLDER_NAME}" "${gcc_folder}"
  do_container_copy_license \
    "${work_folder_path}/${NEWLIB_FOLDER_NAME}" "${newlib_folder}"

  do_container_copy_license \
    "${work_folder_path}/${LIBZ_FOLDER}" "${LIBZ_FOLDER}"
  do_container_copy_license \
    "${work_folder_path}/${GMP_FOLDER}" "${GMP_FOLDER}"
  do_container_copy_license \
    "${work_folder_path}/${MPFR_FOLDER}" "${MPFR_FOLDER}"
  do_container_copy_license \
    "${work_folder_path}/${MPC_FOLDER}" "${MPC_FOLDER}"
  do_container_copy_license \
    "${work_folder_path}/${ISL_FOLDER}" "${ISL_FOLDER}"

  if [ "${target_name}" == "win" ]
  then
    # For Windows, process cr lf
    find "${app_prefix}/license" -type f \
      -exec unix2dos {} \;
  fi

  touch "${license_stamp_file}"
fi

# ----- Copy the GNU MCU Eclipse info files. -----

info_stamp_file="${build_folder_path}/stamp_info_completed"

if [ ! -f "${info_stamp_file}" ]
then

  do_container_copy_info

  /usr/bin/install -cv -m 644 \
    "${build_folder_path}/${binutils_folder}/configure-output.txt" \
    "${app_prefix}/gnu-mcu-eclipse/binutils-configure-output.txt"
  do_unix2dos "${app_prefix}/gnu-mcu-eclipse/binutils-configure-output.txt"

  /usr/bin/install -cv -m 644 \
    "${build_folder_path}/${newlib_folder}/configure-output.txt" \
    "${app_prefix}/gnu-mcu-eclipse/newlib-configure-output.txt"
  do_unix2dos "${app_prefix}/gnu-mcu-eclipse/newlib-configure-output.txt"

  /usr/bin/install -cv -m 644 \
    "${build_folder_path}/${gcc_stage2_folder}/configure-output.txt" \
    "${app_prefix}/gnu-mcu-eclipse/gcc-configure-output.txt"
  do_unix2dos "${app_prefix}/gnu-mcu-eclipse/gcc-configure-output.txt"

  touch "${info_stamp_file}"
fi

# ----- Create the distribution package. -----

do_container_create_distribution

do_check_application "${gcc_target}-gdb" --version
do_check_application "${gcc_target}-g++" --version

# Requires ${distribution_file} and ${result}
do_container_completed

exit 0

EOF
# The above marker must start in the first column.
# ^===========================================================================^


# ----- Build the OS X distribution. -----

if [ "${HOST_UNAME}" == "Darwin" ]
then
  if [ "${DO_BUILD_OSX}" == "y" ]
  then
    do_host_build_target "Creating OS X package..." \
      --target-name osx
  fi
fi

# ----- Build the Debian 64-bits distribution. -----

if [ "${DO_BUILD_DEB64}" == "y" ]
then
  do_host_build_target "Creating Debian 64-bits archive..." \
    --target-name debian \
    --target-bits 64 \
    --docker-image "ilegeul/debian:8-gnuarm-gcc-x11-v4"
fi

# ----- Build the Windows 64-bits distribution. -----

if [ "${DO_BUILD_WIN64}" == "y" ]
then
  if [ ! -f "${WORK_FOLDER_PATH}/install/debian64/${APP_LC_NAME}/bin/${gcc_target}-gcc" ]
  then
    do_host_build_target "Creating Debian 64-bits archive..." \
      --target-name debian \
      --target-bits 64 \
      --docker-image "ilegeul/debian:8-gnuarm-gcc-x11-v4"
  fi

  do_host_build_target "Creating Windows 64-bits setup..." \
    --target-name win \
    --target-bits 64 \
    --docker-image "ilegeul/debian:8-gnuarm-mingw-v2" \
    --build-binaries-path "install/debian64/${APP_LC_NAME}/bin"
fi

# ----- Build the Debian 32-bits distribution. -----

if [ "${DO_BUILD_DEB32}" == "y" ]
then
  do_host_build_target "Creating Debian 32-bits archive..." \
    --target-name debian \
    --target-bits 32 \
    --docker-image "ilegeul/debian32:8-gnuarm-gcc-x11-v4"
fi

# ----- Build the Windows 32-bits distribution. -----

if [ "${DO_BUILD_WIN32}" == "y" ]
then
  if [ ! -f "${WORK_FOLDER_PATH}/install/debian32/${APP_LC_NAME}/bin/${gcc_target}-gcc" ]
  then
    do_host_build_target "Creating Debian 32-bits archive..." \
      --target-name debian \
      --target-bits 32 \
      --docker-image "ilegeul/debian32:8-gnuarm-gcc-x11-v4"
  fi

  do_host_build_target "Creating Windows 32-bits setup..." \
    --target-name win \
    --target-bits 32 \
    --docker-image "ilegeul/debian:8-gnuarm-mingw-v2"
fi

do_host_show_sha

do_host_stop_timer

# ----- Done. -----
exit 0
