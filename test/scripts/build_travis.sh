#!/bin/bash -x
set -e
set -o pipefail

# Note this script assumes that the current working directory
# is the root of the repository
if [ ! -f ./.travis.yml ]; then
  echo "This script must be run from the root of the repository"
  exit 1
fi

: ${LLVM_VERSION:?"LLVM_VERSION must be specified"}
: ${BUILD_SYSTEM:?"BUILD_SYSTEM must be specified"}
: ${CXX:?"CXX must be specified"}

if [ ${BUILD_SYSTEM} = 'CMAKE' ]; then
  : ${BUILD_SHARED_LIBS:?"BUILD_SHARED_LIBS must be set"}
  mkdir -p build/ && cd build/
  /usr/bin/cmake -DLLVM_DIR="/usr/local/llvm/lib/cmake/llvm/" \
                 -DClang_DIR="/usr/local/llvm/lib/cmake/clang/" \
                 -DBUILD_SHARED_LIBS="${BUILD_SHARED_LIBS}" \
                 -DWITH_APPS=OFF \
                 -DWITH_TESTS=ON \
                 -DWITH_TEST_AUTO_SCHEDULE=OFF \
                 -DWITH_TEST_PERFORMANCE=OFF \
                 -DWITH_TEST_OPENGL=OFF \
                 -DWITH_TEST_WARNING=OFF \
                 -DWITH_TUTORIALS=OFF \
                 -DWITH_DOCS=ON \
                 -DWITH_PYTHON_BINDINGS=OFF \
                 -DCMAKE_BUILD_TYPE=Release \
                 -G Ninja \
                 ../

  /usr/bin/cmake --build . -j 4
  /usr/bin/ctest -L internal --output-on-failure

  if [ ${BUILD_SHARED_LIBS} = 'ON' ]; then
    # Building with static library is slower, and can run
    # over the time limit; since we just want a reality
    # check, do the full test suite only for shared.
    /usr/bin/ctest -L travis --output-on-failure
    /usr/bin/cmake --build . --target doc
  fi

elif [ ${BUILD_SYSTEM} = 'MAKE' ]; then
  export LLVM_CONFIG=/usr/local/llvm/bin/llvm-config
  ${LLVM_CONFIG} --cxxflags --libdir --bindir

  # Build and run internal tests
  make ${MAKEFLAGS} distrib
  make ${MAKEFLAGS} test_internal

  # Build the docs and run the tests
  make doc
  make ${MAKEFLAGS} test_correctness
  make ${MAKEFLAGS} test_generator

else
  echo "Unexpected BUILD_SYSTEM: \"${BUILD_SYSTEM}\""
  exit 1
fi

