inherit kernel
require recipes-kernel/linux/linux-yocto.inc

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

# Override SRC_URI in a copy of this recipe to point at a different source
# tree if you do not want to build from Linus' tree.
#SRC_URI = "git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git;protocol=git;nocheckout=1;name=machine \
#
#SRC_URI = "git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git;protocol=git;nocheckout=1;name=machine \
#
SRC_URI = "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.14.79.tar.xz \
    file://defconfig \
    file://10-xen.scc \
    file://20-qemu.scc \
    file://30-boot-img.scc \
    file://u2mfn-built-in.patch \
    file://u2mfn.c \
    file://Makefile \
    file://pci_op-cleanup.patch \
    file://xsa155-linux-0008-xen-Add-RING_COPY_RESPONSE.patch \
    file://xsa155-linux44-0009-xen-netfront-copy-response-out-of-shared-buffer-befo.patch \
    file://xsa155-linux44-0010-xen-netfront-do-not-use-data-already-exposed-to-back.patch \
    file://xsa155-linux-0011-xen-netfront-add-range-check-for-Tx-response-id.patch \
    file://xsa155-linux312-0012-xen-blkfront-make-local-copy-of-response-before-usin.patch \
    file://xsa155-linux44-0013-xen-blkfront-prepare-request-locally-only-then-put-i.patch \
"

DEPENDS += "binutils-native"

LINUX_VERSION ?= "4.14.79"
LINUX_VERSION_EXTENSION_append = "-stubdom-qubes"

# Modify SRCREV to a different commit hash in a copy of this recipe to
# build a different release of the Linux kernel.
# tag: v4.2 64291f7db5bd8150a74ad2036f1037e6a0428df2
#SRCREV_machine="64291f7db5bd8150a74ad2036f1037e6a0428df2"
#SRCREV_machine="50961e4888a1d53544ac4ea6f185fc27ee4fee4f"
SRC_URI[md5sum] = "51a564681840bbd07021f9e9381d45bc"
SRC_URI[sha256sum] = "5619071eceb27f903d2fce1784223796bfbe25528f9690273cdfe82fdd9b933a"

PV = "${LINUX_VERSION}"

S = "${WORKDIR}/linux-${PV}"

# Override COMPATIBLE_MACHINE to include your machine in a copy of this recipe
# file. Leaving it empty here ensures an early explicit build failure.
COMPATIBLE_MACHINE = "(xen-stubdom)"

# Setup u2mfn inside the source dir
# Copied from https://github.com/QubesOS/qubes-linux-utils/blob/master/kernel-modules/u2mfn/u2mfn.c
do_patch_append(){
    U2MFN_PATH=drivers/u2mfn
    mkdir -p ${S}/$U2MFN_PATH
    cp ${WORKDIR}/u2mfn.c $U2MFN_PATH/
    cp ${WORKDIR}/Makefile $U2MFN_PATH/
}
