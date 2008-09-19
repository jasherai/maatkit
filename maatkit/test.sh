#!/bin/sh

if [ -n "$NO_TESTS" ]; then
   exit 0
fi

set -u
set -e
set -x

for tdir in ../mk-*/t
do
   cd $tdir
   prove
   cd -
done
