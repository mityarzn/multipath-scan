RELEASE=4.2

VERSION=1.0
PACKAGE=multipath-scan
PKGREL=1

DESTDIR=
PREFIX=/usr
SBINDIR=${PREFIX}/sbin
DOCDIR=${PREFIX}/share/doc/${PACKAGE}

export PERLDIR=${PREFIX}/share/perl5

SOURCES=multipath-scan.sh

ARCH=all
GITVERSION:=$(shell cat .git/refs/heads/master)

DEB=${PACKAGE}_${VERSION}-${PKGREL}_${ARCH}.deb

all: ${DEB}

.PHONY: dinstall
dinstall: deb
	dpkg -i ${DEB}

.PHONY: install
install:
	install -d ${DESTDIR}${PERLDIR}/PVE/Storage/Custom
	for i in ${SOURCES}; do install -D -m 0644 $$i ${DESTDIR}${SBINDIR}/$$i; done

.PHONY: deb ${DEB}
deb ${DEB}:
	rm -rf debian
	mkdir debian
	make DESTDIR=${CURDIR}/debian install
	install -d -m 0755 debian/DEBIAN
	sed -e s/@@VERSION@@/${VERSION}/ -e s/@@PKGRELEASE@@/${PKGREL}/ -e s/@@ARCH@@/${ARCH}/ <control.in >debian/DEBIAN/control
	install -D -m 0644 copyright debian/${DOCDIR}/copyright
	install -m 0644 changelog.Debian debian/${DOCDIR}/
	gzip -9 debian/${DOCDIR}/changelog.Debian
	dpkg-deb --build debian
	mv debian.deb ${DEB}
	rm -rf debian
	lintian ${DEB}

.PHONY: clean
clean:
	rm -rf debian *.deb ${PACKAGE}-*.tar.gz dist *.1 *.tmp
	find . -name '*~' -exec rm {} ';'

.PHONY: distclean
distclean: clean
