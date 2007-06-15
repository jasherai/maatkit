dist:
	./package.pl

all: dist debian doc

debian: dist
	./debian-build

doc: dist
	./make-docs.pl
