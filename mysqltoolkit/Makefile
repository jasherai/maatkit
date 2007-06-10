# Simple Makefile

# required programs
CHMOD = /bin/chmod
CP = /bin/cp
RM = /bin/rm
MV = /bin/mv
SED = /bin/sed
TAR = /bin/tar
SVN = /usr/bin/svn
ZIP = /usr/bin/zip
MKDIR = /bin/mkdir
SVN = /usr/local/bin/svn

include revision

# define some variables
DISTFILES = COPYING \
	INSTALL \
	Makefile.PL \
	MANIFEST \

# Package list is generated automatically from ../../tags/ latest version of
# each package.  Distribution number is generated automatically from checking
# in the package list.  I don't know the right way to do this, so I am making
# targets that will make files that can later be included.  Teach me if there
# is a better way.

all: 

packlist:
	$(CP) Revision packlist
	for dir in ../../tags/mysql-*; do ls $$dir | sort -r | head -n 1; done >> packlist
	svn ci -m "bump version" packlist

revision: packlist
	head -n 1 packlist | awk '{print "REVISION=" $$2}' > revision

versions:
	$(SED) -i -e s/@VERSION@/$(VERSION)/ $(DISTDIR)/$(NAME)
	$(SED) -i -e s/@VERSION@/$(VERSION)/ $(DISTDIR)/$(FILTER)

distdir: all
	if test -d $(DISTDIR) ; then $(RM) -rf $(DISTDIR) ; fi
	$(MKDIR) $(DISTDIR)
	$(CP) -a $(DISTFILES) $(DISTDIR)
	$(CHMOD) 755 $(DISTDIR)/$(NAME)
	$(RM) -rf `find $(DISTDIR) -type d -name .svn -print`

dist: distdir versions
	$(TAR) czf $(DISTDIR).tar.gz $(DISTDIR)
	$(ZIP) -r $(DISTDIR).zip $(DISTDIR)

distclean:
	$(RM) -f $(DISTDIR).tar.gz
	$(RM) -f $(DISTDIR).zip
	$(RM) -rf $(DISTDIR)
