dist: test
	./package.pl

all: dist debian

.PHONY: debian
debian: dist
	./debian-build

clean:
	rm -rf release release-debian

doc-upload:
	scp html/*.html bps7j@shell.sourceforge.net:maatkit/htdocs/doc

.PHONY: upload
upload:
	./upload

test:
	./test.sh
