AC			= nasm
AFLAGS		= -felf32
LD			= ld
LFLAGS		= -z max-page-size=0x01000 --oformat=binary -m elf_i386 -Map TP.map
LDSCRIPT	= rom.lds
ODFLAGS		= -CprsSx --prefix-addresses

ROM_NAME	= mi_bios
OBJS		= init32.o main.o
ROM_LOCATION	= 0x000F0000

all: $(ROM_NAME).bin $(ROM_NAME).elf	
	@echo	''
	@echo	'-----> Generando listados de hexadecimales y ELFs'
	hexdump -C $(ROM_NAME).bin > $(ROM_NAME)_hexdump.txt
	objdump $(ODFLAGS) $(ROM_NAME).elf > $(ROM_NAME)_objdump.txt
	readelf -a $(ROM_NAME).elf > $(ROM_NAME)_readelf.txt
	@echo	''
	
$(ROM_NAME).bin: $(OBJS)
	@echo	''
	@echo	'-----> Linkeando objetos en formato binario'
	$(LD) $(LFLAGS) -o $@ $(OBJS) -T $(LDSCRIPT) -e Entry 
	
$(ROM_NAME).elf: $(OBJS)
	@echo	''
	@echo	'---> Linkeando objetos en formato ELF'
	$(LD) -z max-page-size=0x01000 -m elf_i386 -T $(LDSCRIPT) -e Entry $(OBJS) -o $@
	
main.o: main.asm
	@echo	''
	@echo	'---> Compilando main.asm'
	$(AC) $(AFLAGS) $< -o $@ -l main.lst

init16.bin: init16.asm
	@echo	''
	@echo	'---> Compilando init16.asm'
	$(AC) -f bin $< -o $@ -l init16.lst -DROM_LOCATION=$(ROM_LOCATION)

init32.o: init32.asm init16.bin
	@echo	''
	@echo	'---> Compilando init32.asm'
	$(AC) $(AFLAGS) $< -o $@ -l init32.lst

.PHONY : help
help:
	@echo	''
	@echo	'Uso:'
	@echo	'  make all:      Compila y patchea Checksum'
	@echo	'  make dump:     Muestra archivo binario de imagen'
	@echo	'  make edit:     Muestra todos los archivos para edicion'
	@echo	'  make bochs:    Ejecuta bochs con el archivo de configuracion de la version 2.5.1'
	@echo	'  make clean:    Elimina archivos auxiliares'
	@echo	''

.PHONY : dump
dump: 
	hexdump $(ROM_NAME).img

.PHONY : edit
edit:
	kate *.asm *.c bochsrc Makefile rom.lds *.txt *.lst &
	
.PHONY : bochs
bochs: 
	bochs -f bochsrc -q

.PHONY : clean
clean:
	@echo	''
	@echo	'---> Limpieza de archivos'
	rm -f *.*~ *~ *.o *.lst *.bin *.rom *.txt *.elf *.img *.dis *.s *.map CheckSumGen
