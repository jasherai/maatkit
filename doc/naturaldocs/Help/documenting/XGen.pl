#!C:\Perl\bin\perl

###############################################################################
#
#   Script: XGen.pl
#
###############################################################################
#
#   Dynamically generates static pages for this directory.
#
###############################################################################

use English '-no_match_vars';

use lib 'F:/Projects/Natural Docs Web Site/Modules';
use lib 'F:/Projects/XGen/modules';

use strict;
use integer;

use NaturalDocs::PageRegistry;


XGen::StaticPageRegistry->Run();

1;
