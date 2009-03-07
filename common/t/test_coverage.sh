#!/bin/sh

# Run this script in common/t

cover -delete

for base in ../*.pm; do
   base=`echo $base | sed -r s/^[\.\/]+//g | sed -r s/.pm$//g`
   module="${base}.pm"
   t="${base}.t"
   if [ -f $t ]
   then
      perl -MDevel::Cover=-ignore,.,-select,$module $t
   else
      echo "Module $module has no test file"
   fi
done
