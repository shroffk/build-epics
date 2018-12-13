#!/bin/sh
set -e -x
# Build epics-base and common support modules
#
# Required Debian packages to build
#  build-essential
#  libreadline6-dev libncurses5-dev perl
#  libpcre3-dev
#  python-dev python-nose python-numpy
#  python3-dev python3-nose python3-numpy
#
# Required RHEL/CentOS
#  gcc-c++ glibc-devel make readline-devel ncurses-devel
#  perl-devel
#  pkg-config pcre-devel
#  python-devel numpy python-nose
# From EPEL
#  re2c

BASEDIR="$PWD"
PREFIX=epics-`uname -m`-`date +%Y%m%d`
TAR=$PREFIX.tar

PMAKE="$@"

die() {
    echo "$1" >&1
    exit 1
}

perl --version || die "Missing perl"
g++ --version || die "Missing gcc/g++"
type re2c || die "Need re2c for sncseq"
pkg-config --exists libpcre || die "Need libpcre headers for stream"

# git_fetch <name> <rev> <url>
git_repo() {
    [ -d "$1" ] || git clone --recursive --branch "$2" "$3" "$1"
    echo "=== $1" > $1.version
    echo "URL: $3" >> $1.version
    (cd "$1" && git describe --always --tags --abbrev=8 HEAD && git log -n1) >> $1.version
}

do_make() {
    make LINKER_USE_RPATH=ORIGIN LINKER_ORIGIN_ROOT="$BASEDIR" $PMAKE "$@"
}

do_module() {
    name="$1"
    shift
    (cd "$name" && do_make "$@")
    tar --exclude 'O.*' --exclude-vcs -rf $TAR $PREFIX/"$name"
}

git_repo epics-base rpath-origin https://github.com/mdavidsaver/epics-base.git
git_repo recsync    master       https://github.com/ChannelFinder/recsync.git
git_repo autosave   R5-9         https://github.com/epics-modules/autosave.git
git_repo calc       R3-7         https://github.com/epics-modules/calc.git
git_repo busy       R1-7         https://github.com/epics-modules/busy.git
git_repo asyn       R4-34        https://github.com/epics-modules/asyn.git
git_repo motor      R6-11        https://github.com/epics-modules/motor.git
git_repo stream     R2-7-7b      https://github.com/epics-modules/stream.git
git_repo seq        R2-2-6       http://www-csr.bessy.de/control/SoftDist/sequencer/repo/branch-2-2.git
git_repo sscan      R2-11-1      https://github.com/epics-modules/sscan.git
#git_repo etherip
#git_repo modbus

export EPICS_HOST_ARCH=`./epics-base/startup/EpicsHostArch`

cat <<EOF >epics-base/configure/CONFIG_SITE.local
CROSS_COMPILER_TARGET_ARCHS += \$(EPICS_HOST_ARCH)-debug
EOF

cat <<EOF >autosave/configure/RELEASE
EPICS_BASE=$BASEDIR/epics-base
EOF

cat <<EOF >recsync/client/configure/RELEASE
EPICS_BASE=$BASEDIR/epics-base
EOF

cat <<EOF >seq/configure/RELEASE
EPICS_BASE=$BASEDIR/epics-base
EOF

cat <<EOF >asyn/configure/RELEASE
EPICS_BASE=$BASEDIR/epics-base
EOF

cat <<EOF >busy/configure/RELEASE
ASYN=$BASEDIR/asyn
EPICS_BASE=$BASEDIR/epics-base
EOF

cat <<EOF >sscan/configure/RELEASE
SNCSEQ=$BASEDIR/seq
EPICS_BASE=$BASEDIR/epics-base
EOF

cat <<EOF >calc/configure/RELEASE
SSCAN=$BASEDIR/sscan
SNCSEQ=$BASEDIR/seq
EPICS_BASE=$BASEDIR/epics-base
EOF

cat <<EOF >stream/configure/RELEASE
SSCAN=$BASEDIR/sscan
CALC=$BASEDIR/calc
ASYN=$BASEDIR/asyn
EPICS_BASE=$BASEDIR/epics-base
EOF

cat <<EOF >motor/configure/RELEASE
ASYN=$BASEDIR/asyn
BUSY=$BASEDIR/busy
SNCSEQ=$BASEDIR/seq
EPICS_BASE=$BASEDIR/epics-base
EOF

trap 'rm -f $PREFIX $TAR' TERM KILL HUP EXIT

rm -f $PREFIX
ln -s . $PREFIX

git remote show origin -n > build-info
git describe --always --tags --abbrev=8 HEAD && git log -n1 >> build-info

tar -cf $TAR $PREFIX/build-info

do_module epics-base
do_module autosave
do_module recsync/client
do_module seq
do_module asyn
do_module busy
do_module sscan
do_module calc
do_module stream BUILD_PCRE=NO
do_module motor

tar -rf $TAR $PREFIX/*.version

gzip -f $TAR
ls -lh $TAR
