#!/bin/sh

# *** Must run from trunk/ ***
# I do vi `maatkit/list_all_scripts.sh` when I have to do mass, manual updates

DIR=`realpath $0`
cd `dirname $DIR`
cd ../
find ./ -mindepth 2 -maxdepth 2 -name mk-\* -type f -print
