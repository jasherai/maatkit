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

NAME = mysql-find
VERSION = 0.9.2
DISTFILES = COPYING \
	INSTALL \
	Makefile.PL \
	$(NAME) \
	MANIFEST \
	README
DISTDIR = $(NAME)-$(VERSION)

all: $(DISTFILES)

versions:
	$(SED) -i -e s/@VERSION@/$(VERSION)/ $(DISTDIR)/$(NAME)

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
