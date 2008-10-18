dist:
	./package.pl

all: dist debian

.PHONY: debian
debian: dist
	./debian-build

clean:
	rm -rf release release-debian

.PHONY: upload
upload:
	./upload

test:
	./test.sh
