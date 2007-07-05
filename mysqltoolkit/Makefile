dist:
	./package.pl

all: dist debian doc

.PHONY: debian
debian:
	./debian-build

doc: dist
	./make-docs.pl

clean:
	rm -rf release release-debian
