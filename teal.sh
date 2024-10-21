#!/usr/bin/env bash

# Quick Teal build script while we don't have Cyan integration yet

cd $(dirname $0)/src

i=0
for tealname in $(find . -name "*.tl" -not -name "*.d.tl")
do
   luaname=$(echo $tealname | sed 's/.tl$/.lua/g')
   if [ $tealname -nt $luaname ] || [ "$1" = "--all" ]
   then
      tl gen --check -I ../types $tealname -o $luaname
      i=$[i+1]
   fi
done

# Final message:

if [ "$1" = "--all" ]
then
   what="rebuilt"
else
   what="needed rebuilding"
fi
if [ "$i" = 1 ]
then
   echo "$i file $what."
else
   echo "$i files $what."
fi
