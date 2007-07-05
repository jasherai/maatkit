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
