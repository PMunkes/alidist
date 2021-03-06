package: FairRoot
version: dev
source: https://github.com/FairRootGroup/FairRoot
tag: dev
requires:
  - generators
  - simulation
  - ROOT
  - ZeroMQ
  - nanomsg
  - boost
  - protobuf
  - DDS
  - "GCC-Toolchain:(?!osx)"
build_requires:
  - googletest
env:
  VMCWORKDIR: "$FAIRROOT_ROOT/share/fairbase/examples"
  GEOMPATH:   "$FAIRROOT_ROOT/share/fairbase/examples/common/geometry"
  CONFIG_DIR: "$FAIRROOT_ROOT/share/fairbase/examples/common/gconfig"
  FAIRROOTPATH: "$FAIRROOT_ROOT"
prepend_path:
  ROOT_INCLUDE_PATH: "$FAIRROOT_ROOT/include"
---
#!/bin/sh

# Making sure people do not have SIMPATH set when they build fairroot.
# Unfortunately SIMPATH seems to be hardcoded in a bunch of places in
# fairroot, so this really should be cleaned up in FairRoot itself for
# maximum safety.
unset SIMPATH

case $ARCHITECTURE in
  osx*)
    # If we preferred system tools, we need to make sure we can pick them up.
    [[ ! $BOOST_ROOT ]] && BOOST_ROOT=`brew --prefix boost`
    [[ ! $ZEROMQ_ROOT ]] && ZEROMQ_ROOT=`brew --prefix zeromq`
    [[ ! $PROTOBUF_ROOT ]] && PROTOBUF_ROOT=`brew --prefix protobuf`
    [[ ! $NANOMSG_ROOT ]] && NANOMSG_ROOT=`brew --prefix nanomsg`
    [[ ! $GSL_ROOT ]] && GSL_ROOT=`brew --prefix gsl`
    SONAME=dylib
  ;;
  *) SONAME=so ;;
esac


cmake $SOURCEDIR                                                 \
      -DMACOSX_RPATH=OFF                                         \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS"                              \
      -DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE                       \
      -DUSE_PATH_INFO=ON                                         \
      -DROOTSYS=$ROOTSYS                                         \
      -DROOT_CONFIG_SEARCHPATH=$ROOT_ROOT/bin                    \
      ${NANOMSG_ROOT:+-DUSE_NANOMSG=true}                        \
      ${NANOMSG_ROOT:+-DNANOMSG_DIR=$NANOMSG_ROOT}               \
      -DPythia6_LIBRARY_DIR=$PYTHIA6_ROOT/lib                    \
      -DGeant3_DIR=$GEANT3_ROOT                                  \
      -DDISABLE_GO=ON                                            \
      -DBUILD_EXAMPLES=ON                                        \
      ${GEANT4_ROOT:+-DGeant4_DIR=$GEANT4_ROOT}                  \
      -DFAIRROOT_MODULAR_BUILD=ON                                \
      ${CMAKE_VERBOSE_MAKEFILE:+-DCMAKE_VERBOSE_MAKEFILE=ON}     \
      ${DDS_ROOT:+-DDDS_PATH=$DDS_ROOT}                          \
      ${ZEROMQ_ROOT:+-DZEROMQ_ROOT=$ZEROMQ_ROOT}                 \
      ${ZEROMQ_ROOT:+-DZMQ_DIR=$ZEROMQ_ROOT}                     \
      ${BOOST_ROOT:+-DBoost_NO_SYSTEM_PATHS=TRUE}                \
      ${BOOST_ROOT:+-DBOOST_ROOT=$BOOST_ROOT}                    \
      ${BOOST_ROOT:+-DBOOST_INCLUDEDIR=$BOOST_ROOT/include}      \
      ${BOOST_ROOT:+-DBOOST_LIBRARYDIR=$BOOST_ROOT/lib}          \
      ${GSL_ROOT:+-DGSL_DIR=$GSL_ROOT}                           \
      ${MESSAGEPACK_ROOT:+-DMSGPACK_ROOT=${MESSAGEPACK_ROOT}}    \
      -DGTEST_DIR=$GOOGLETEST_ROOT                               \
      -DGTEST_ROOT=$GOOGLETEST_ROOT                              \
      -DPROTOBUF_INCLUDE_DIR=$PROTOBUF_ROOT/include              \
      -DPROTOBUF_PROTOC_EXECUTABLE=$PROTOBUF_ROOT/bin/protoc     \
      -DPROTOBUF_LIBRARY=$PROTOBUF_ROOT/lib/libprotobuf.$SONAME  \
      -DCMAKE_INSTALL_PREFIX=$INSTALLROOT

# Limit the number of build processes to avoid exahusting memory when building
# on smaller machines.
[[ $JOBS -gt 1 ]] || JOBS=2
JOBS=$((${JOBS:-1}*2/4))
make -j$JOBS
#On Fedora (and Centos 7) some tests hang after completion due to wait() not returning.
#make test
make install

#Get current git hash, needed by FairShip
cd $SOURCEDIR
FAIRROOT_HASH=$(git rev-parse HEAD)
cd $BUILDDIR

# Modulefile
MODULEDIR="$INSTALLROOT/etc/modulefiles"
MODULEFILE="$MODULEDIR/$PKGNAME"
mkdir -p "$MODULEDIR"
cat > "$MODULEFILE" <<EoF
#%Module1.0
proc ModulesHelp { } {
  global version
  puts stderr "ALICE Modulefile for $PKGNAME $PKGVERSION-@@PKGREVISION@$PKGHASH@@"
}
set version $PKGVERSION-@@PKGREVISION@$PKGHASH@@
module-whatis "ALICE Modulefile for $PKGNAME $PKGVERSION-@@PKGREVISION@$PKGHASH@@"
# Dependencies
module load BASE/1.0                                                                            \\
            ${GEANT3_VERSION:+GEANT3/$GEANT3_VERSION-$GEANT3_REVISION}                          \\
            ${GEANT4_VMC_VERSION:+GEANT4_VMC/$GEANT4_VMC_VERSION-$GEANT4_VMC_REVISION}          \\
            ${PROTOBUF_VERSION:+protobuf/$PROTOBUF_VERSION-$PROTOBUF_REVISION}                  \\
            ${PYTHIA6_VERSION:+pythia6/$PYTHIA6_VERSION-$PYTHIA6_REVISION}                      \\
            ${PYTHIA_VERSION:+pythia/$PYTHIA_VERSION-$PYTHIA_REVISION}                          \\
            ${VGM_VERSION:+vgm/$VGM_VERSION-$VGM_REVISION}                                      \\
            ${BOOST_VERSION:+boost/$BOOST_VERSION-$BOOST_REVISION}                              \\
            ROOT/$ROOT_VERSION-$ROOT_REVISION                                                   \\
            ${ZEROMQ_VERSION:+ZeroMQ/$ZEROMQ_VERSION-$ZEROMQ_REVISION}                          \\
            ${NANOMSG_VERSION:+nanomsg/$NANOMSG_VERSION-$NANOMSG_REVISION}                      \\
            ${DDS_ROOT:+DDS/$DDS_VERSION-$DDS_REVISION}                                         \\
            ${GCC_TOOLCHAIN_ROOT:+GCC-Toolchain/$GCC_TOOLCHAIN_VERSION-$GCC_TOOLCHAIN_REVISION}
# Our environment
setenv FAIRROOT_ROOT \$::env(BASEDIR)/$PKGNAME/\$version
setenv FAIRROOT_HASH $FAIRROOT_HASH
setenv VMCWORKDIR \$::env(FAIRROOT_ROOT)/share/fairbase/examples
setenv GEOMPATH \$::env(VMCWORKDIR)/common/geometry
setenv CONFIG_DIR \$::env(VMCWORKDIR)/common/gconfig
prepend-path PATH \$::env(FAIRROOT_ROOT)/bin
prepend-path LD_LIBRARY_PATH \$::env(FAIRROOT_ROOT)/lib
prepend-path ROOT_INCLUDE_PATH \$::env(FAIRROOT_ROOT)/include
$([[ ${ARCHITECTURE:0:3} == osx ]] && echo "prepend-path DYLD_LIBRARY_PATH \$::env(FAIRROOT_ROOT)/lib")
EoF
