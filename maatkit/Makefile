dist:
	./package.pl

all: dist debian

.PHONY: debian
debian: dist
	./debian-build

.PHONY: rpm
rpm: dist
	./rpm-build

clean:
	rm -rf release release-debian

.PHONY: upload
upload:
	./upload

test:
	./test.sh
