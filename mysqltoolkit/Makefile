dist:
	./package.pl

all: dist debian doc

debian:
	./debian-build

doc: dist
	./make-docs.pl

clean:
	rm -rf release release-debian
