dist:
	./package.pl

all: dist debian individual

.PHONY: debian
debian:
	./debian-build

clean:
	rm -rf release release-debian

individual: dist
	./make-individual.pl

doc-upload:
	scp html/*.html bps7j@shell.sourceforge.net:mysqltoolkit/htdocs/doc
