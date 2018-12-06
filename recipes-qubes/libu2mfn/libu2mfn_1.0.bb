LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = "file://${WORKDIR}/git/u2mfn/u2mfnlib.c;beginline=6;endline=18;md5=e12e01ead6ae005a8549f9693eed75a7"
SRC_URI = "git://github.com/QubesOS/qubes-core-vchan-xen \
           file://libu2mfn-elf-soname.patch;striplevel=2 \
"
SRCREV = "master"

S = "${WORKDIR}/git/u2mfn"

do_install() {
	install -d ${D}${includedir}
	install -m 0644 u2mfnlib.h ${D}${includedir}
	install -d ${D}${libdir}
	install -m 0755 libu2mfn.so ${D}${libdir}/libu2mfn.so.1.0
	ln -s libu2mfn.so.1.0 ${D}${libdir}/libu2mfn.so.1
	ln -s libu2mfn.so.1.0 ${D}${libdir}/libu2mfn.so
}
