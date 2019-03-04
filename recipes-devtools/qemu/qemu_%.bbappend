FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append_class-target_stubdom += " \
	git://github.com/QubesOS/qubes-gui-agent-xen-hvm-stubdom;branch=master;name=gui-agent;destsuffix=${PN}-${PV}/gui-agent \
	file://qemu-ifup \
	file://qemu-ifdown \
	file://qemu-configure.patch \
	file://qemu-xen-h.patch \
	file://qemu-xen-hvm.patch \
	file://qubes-gui-agent.patch \
	file://disable-msix-caps.patch \
	file://fw_cfg-init.patch \
	file://round-pci-region-sizes.patch \
	file://disable-nic-option-rom.patch \
	file://stubdom-pci-addr-fix.patch \
	file://pci-fix-emu-mask.patch \
	file://6f2231e-seccomp-use-SIGSYS-signal-instead-of-killing-the-thread.patch \
	file://bda08a5-seccomp-prefer-SCMP_ACT_KILL_PROCESS-if-available.patch \
	file://70dfabe-seccomp-set-the-seccomp-filter-to-all-threads.patch \
	file://additional-seccomp-filters.patch \
	file://qubes-gui-protocol.h \
"
SRCREV_gui-agent_pn-qemu = "007a47e59dd2d09d93c0cde111b749a2eabe1dd2"

DEPENDS_class-target_stubdom += "libu2mfn xen libvchan-xen"
# I don't know why qemu.inc adds bash to class-target...
RDEPENDS_${PN}_class-target_stubdom_remove = "bash"

RDEPENDS_${PN}_class-target_stubdom_append = "vgabios"

PACKAGECONFIG_class-target_stubdom = "xen seccomp"
PACKAGECONFIG_class-native = "fdt kvm"

PACKAGECONFIG[seccomp] = "--enable-seccomp,--disable-seccomp,libseccomp,"

EXTRA_OECONF_class-target_stubdom = " \
    --prefix=${prefix} \
    --bindir=${bindir} \
    --includedir=${includedir} \
    --libdir=${libdir} \
    --mandir=${mandir} \
    --datadir=${datadir} \
    --docdir=${docdir}/${BPN} \
    --sysconfdir=${sysconfdir} \
    --libexecdir=${libexecdir} \
    --localstatedir=${localstatedir} \
    --with-confsuffix=/${BPN} \
    --disable-strip \
    --target-list=i386-softmmu \
    --enable-xen \
    --enable-xen-pci-passthrough \
    --disable-werror \
    --disable-sdl \
    --disable-kvm \
    --disable-gtk \
    --disable-fdt \
    --disable-bluez \
    --disable-libusb \
    --disable-slirp \
    --enable-pie \
    --disable-docs \
    --disable-vhost-net \
    --disable-spice \
    --disable-guest-agent \
    --audio-drv-list= \
    --disable-smartcard \
    --disable-vnc \
    --disable-spice \
    --enable-trace-backends=log \
    --disable-gnutls \
    --disable-nettle \
    --disable-gcrypt \
    --disable-vte \
    --disable-curses \
    --disable-cocoa \
    --disable-virtfs \
    --disable-brlapi \
    --disable-curl \
    --disable-rdma \
    --disable-vde \
    --disable-netmap \
    --disable-linux-aio \
    --disable-cap-ng \
    --disable-attr \
    --disable-rbd \
    --disable-libiscsi \
    --disable-libnfs \
    --disable-usb-redir \
    --disable-lzo \
    --disable-snappy \
    --disable-bzip2 \
    --enable-seccomp \
    --disable-coroutine-pool \
    --disable-glusterfs \
    --disable-tpm \
    --disable-libssh2 \
    --disable-numa \
    --disable-tcmalloc \
    --disable-jemalloc \
    --disable-vhost-scsi \
    --disable-qom-cast-debug \
    --disable-virglrenderer \
    --enable-stubdom \
    --disable-tools \
    --disable-replication \
    --disable-vhost-vsock \
    --disable-hax \
    --disable-vhost-vsock \
    --disable-opengl \
    --disable-virglrenderer \
    --disable-xfsctl \
    --disable-blobs \
    --disable-tcg \
    --disable-crypto-afalg \
    --disable-live-block-migration \
    --disable-vxhs \
    --disable-vhost-user \
    --disable-vhost-crypto \
    --cxx=/non-existent \
    --extra-cflags="${CFLAGS} -DXEN_PT_LOGGING_ENABLED=1" \
    --extra-ldflags="-Wl,-z,nodlopen -Wl,-z,nodump -Wl,-z,noexecstack" \
    "

do_configure_prepend_class-target_stubdom() {
    cp ${WORKDIR}/qubes-gui-protocol.h ${S}/gui-agent/include/
}

FILES_${PN}_append_class-target_stubdom += " \
    ${datadir}/qemu-firmware \
"

do_install_append_class-target_stubdom() {
    install -d ${D}${sysconfdir}
    install -m 0755 ${WORKDIR}/qemu-ifup ${D}${sysconfdir}/
    install -m 0755 ${WORKDIR}/qemu-ifdown ${D}${sysconfdir}/

    #Install compatibility symlinks to vgabios filenames
    install -d ${D}${datadir}/qemu-firmware
    ln -s ../firmware/vgabios-0.7a.bin ${D}${datadir}/qemu-firmware/vgabios-stdvga.bin
    ln -s ../firmware/vgabios-0.7a.cirrus.bin ${D}${datadir}/qemu-firmware/vgabios-cirrus.bin
}
