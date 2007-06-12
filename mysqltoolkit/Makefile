all: package debian doc

debian: package
	./debian-build

doc: package
	./make-docs.pl

package:
	./package.pl
