dist:
	./package.pl

all: dist debian rpm

.PHONY: debian
debian: dist
	./debian-build

.PHONY: rpm
rpm: dist
	./rpm-build

clean:
	rm -rf release release-debian release-rpm

.PHONY: upload
upload:
	./upload

test:
	./test.sh
