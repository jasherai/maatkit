#!/bin/sh

set -u
set -e
set -x

for tdir in ../mk-*/t
do
   cd $tdir
   prove
   cd -
done
