LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = "file://${WORKDIR}/git/vchan/io.c;beginline=7;endline=19;md5=e12e01ead6ae005a8549f9693eed75a7"
SRC_URI = "git://github.com/QubesOS/qubes-core-vchan-xen"
SRCREV = "master"

DEPENDS = "xen"

S = "${WORKDIR}/git/vchan"

EXTRA_OEMAKE_append = " 'LDFLAGS=${LDFLAGS}'"

do_compile_prepend() {
	cat > Makefile << EOF
all: libvchan-xen.so vchan-xen.pc

CFLAGS+=-fPIC
libvchan-xen.so : init.o io.o
	\$(CC) -shared -Wl,-soname,libvchan-xen.so.1 -o libvchan-xen.so \$^ -lxenvchan -lxenctrl

clean:
	rm -f *.o *so *~ client server node node-select

vchan-xen.pc: vchan-xen.pc.in
	sed -e "s/@VERSION@/`cat ../version`/" \$< > \$@
EOF
}

do_install() {
	install -d ${D}${includedir}
	install -m 0644 libvchan.h ${D}${includedir}
	install -d ${D}${libdir}
	install -m 0755 libvchan-xen.so ${D}${libdir}/libvchan-xen.so.1.0
	ln -s libvchan-xen.so.1.0 ${D}${libdir}/libvchan-xen.so.1
	ln -s libvchan-xen.so.1.0 ${D}${libdir}/libvchan-xen.so
	install -d ${D}${datadir}/pkgconfig
	install -m 0644 vchan-xen.pc ${D}${datadir}/pkgconfig
}
