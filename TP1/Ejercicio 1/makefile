.PHONY : clean

KERNEL_MEMORY=0x8000
KERNEL_SIZE_SECTORS=1

BOOTLOADER_DEFINES=-DKERNEL_SIZE_SECTORS=$(KERNEL_SIZE_SECTORS) -DKERNEL_MEMORY=$(KERNEL_MEMORY)

bootdisk: ej1.bin bootld.bin
	dd if=/dev/zero of=mydisk count=$(KERNEL_SIZE_SECTORS)	
	dd if=bootld.bin of=mydisk conv=notrunc
	dd if=ej1.bin of=mydisk seek=1 conv=notrunc

ej1.bin: ej1.asm
	nasm -f bin  $(BOOTLOADER_DEFINES) ej1.asm  -l ej1.lst -o $@

bootld.bin: bootld.asm
	nasm -f bin $(BOOTLOADER_DEFINES) bootld.asm -l bootld.lst -o $@

clean:
	rm -f bootld.bin ej1.bin disk *.lst
