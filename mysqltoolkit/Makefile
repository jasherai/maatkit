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

# define some variables
DISTFILES = COPYING \
	INSTALL \
	Makefile.PL \
	MANIFEST \
	README
DISTDIR = $(NAME)-$(VERSION)

all: 

packvers: packlist
	sed -e 's/-(\d)/

packlist:
	# Make a package list
	for dir in ../../tags/mysql-*; do ls $$dir | sort -r | head -n 1; done > packlist

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
