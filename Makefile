buildroot_srcdir := $(CURDIR)/buildroot
linux_srcdir     := $(CURDIR)/linux
opensbi_srcdir   := $(CURDIR)/opensbi

#buildroot_defconfig := $(CURDIR)/defconfig/buildroot_initramfs_config
#linux_defconfig     := $(CURDIR)/defconfig/linux_defconfig
#initramfs_txt       := $(CURDIR)/defconfig/initramfs.txt
buildroot_defconfig := $(CURDIR)/automan_config/buildroot_initramfs_config
linux_defconfig     := $(CURDIR)/automan_config/linux_defconfig
initramfs_txt       := $(CURDIR)/automan_config/initramfs.txt

buildroot_rootfs    := $(buildroot_srcdir)/output/images/rootfs.tar
buildroot_sysroot   := $(buildroot_srcdir)/output/images/buildroot_initramfs_sysroot
tar_flag            := --exclude ./dev --exclude ./usr/share/locale

image               := $(CURDIR)/linux/arch/riscv/boot/Image
payload             := $(CURDIR)/opensbi/build/platform/generic/firmware/fw_payload.elf

all:
	@echo "Hello"

stamp-buildroot: $(buildroot_srcdir)
	cp $(buildroot_defconfig) $</.config
	cd $<; make olddefconfig
	cd $<; make
	touch $@

stamp-sysroot: stamp-buildroot
	rm -rf $(buildroot_sysroot)
	mkdir $(buildroot_sysroot)
	tar -xpf $(buildroot_rootfs) -C $(buildroot_sysroot) $(tar_flag)
	touch $@
	
stamp-linux: $(linux_srcdir) stamp-sysroot
	cp $(linux_defconfig) $</.config
	cd $<; make olddefconfig ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu-
	cd $<; make all ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- \
		CONFIG_INITRAMFS_SOURCE="$(initramfs_txt) $(buildroot_sysroot)" \
		CONFIG_INITRAMFS_ROOT_UID=1000 \
		CONFIG_INITRAMFS_ROOT_GID=1000 \
		-j$$(nproc)
	touch $@

stamp-dtb: $(CURDIR)/automan_config/automan.dts
	dtc -O dtb -b 0 -o $(CURDIR)/automan.dtb $(CURDIR)/automan_config/automan.dts
	touch $@

stamp-opensbi: $(opensbi_srcdir) stamp-linux stamp-dtb
	cd $<; make clean
	cd $<; make CROSS_COMPILE=riscv64-unknown-linux-gnu- \
		PLATFORM=generic \
		PLATFORM_RISCV_ISA=rv64ima \
		PLATFORM_RISCV_ABI=lp64 \
		FW_PAYLOAD_PATH=$(image)
	touch $@

sim: stamp-opensbi
	spike --dtb=/home/yexicong/work/linux-sdk/automan.dtb --isa=rv64ima $(payload) 

clean:
	rm -f stamp-* *.dtb

#objclean:
#	make -C $(buildroot_srcdir) clean
#	make -C $(linux_srcdir) clean
#	make -C $(opensbi_srcdir) clean

#distclean:
#	rm -f stamp-* *.dtb
#	make -C $(buildroot_srcdir) distclean
#	make -C $(linux_srcdir) distclean
#	make -C $(opensbi_srcdir) distclean

