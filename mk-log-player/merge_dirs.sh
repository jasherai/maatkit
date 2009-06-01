#!/bin/sh

if [ -z "$1" ]; then
   echo "Usage: merge-dirs.sh basedir startnum endnum";
   echo "Example: merge-dirs.sh splits/ 1 50";
   exit 1;
fi

if [ ! -d $1 ]; then
   echo "Invalid basedir: $1 is not a directory";
   exit 1;
fi

if [ $2 -gt $3  ]; then
   echo "Starting dir number is greater than ending dir number";
   exit 1;
fi

if [ ! -f "mk-merge-sessions" ]; then
   "mk-merge-sessions is not in the current working directory";
   exit 1;
fi

if [ ! -d "$1/$2" ]; then
   "Invalid starting directory: $1/$2 does not exist";
   exit 1;
fi

if [ ! -d "$1/$3" ]; then
   "Invalid ending directory: $1/$3 does not exist";
   exit 1;
fi

for ((  n = $2 ;  n <= $3;  n++  ))
do
   ./mk-merge-sessions $1/sessions_$n ./$1/$n/*
done
