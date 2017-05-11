;################################################################################
;#	Título: Ejemplo basico de inicio desde BIOS									#
;#																				#
;#	Versión:		2.0							Fecha: 	22/08/2015				#
;#	Autor: 			D. Garcia					Tab: 	4						#
;#	Compilación:	Usar Makefile												#
;#	Uso: 			-															#
;#	------------------------------------------------------------------------	#
;#	Descripción:																#
;#		Inicializacion de un sistema basico desde BIOS							#
;#		Genera una BIOS ROM de 64kB para inicializacion y codigo principal		#
;#	------------------------------------------------------------------------	#
;#	Revisiones:																	#
;#		2.0 | 22/08/2015 | D.GARCIA | Inicio desde BIOS. Cambio de VMA			#
;#		1.0 | 04/03/2013 | D.GARCIA | Inicial									#
;#	------------------------------------------------------------------------	#
;#	TODO:																		#
;#		-																		#
;################################################################################

;********************************************************************************
; Definicion de la base y el largo de la pila
;********************************************************************************
%define STACK_ADDRESS 0x00140000     
%define STACK_SIZE 1023


;Definiciones para configurar el PIC 8259
%define PIC1		0x20		 
%define PIC2		0xA0	 
%define PIC1_COMMAND	PIC1
%define PIC1_DATA	(PIC1+1)
%define PIC2_COMMAND	PIC2
%define PIC2_DATA	(PIC2+1)

%define ICW1_PIC1 00010001b 
;bits 7:5='000' siempre en x86
;bit 4='1' bit de inicializacion
;bit 3='0' si es '0' dispara por flanco, si es '1' dispara por nivel
;bit 2='0' se ignora en x86 y por defecto es '0'
;bit 1='0' si es '1' indica que hay un solo PIC, si es '0' indica que se colocara el pic en casacada con otro.
;bit 0='1' si es '1' indica que le mandaremos la ICW4, lo cual en este caso queremos hacer
%define ICW1_PIC2 ICW1_PIC1
;Misma ICW1

%define ICW2_PIC1 0x20
;La ICW2 contiene la base donde comenzara a buscar los handlers es decir Para IRQ0 -> IDT[0x20], para IRQ1->IDT[0x21], etc
%define ICW2_PIC2 0x28
;Lo mismo que el anterior, coloco las 8 Interrupciones del segundo pic contiguas en el vector a a las anteriores

%define ICW3_PIC1 00000100b
;Cada bit hace referencia a un pin de interupcion. Debo encender el bit que represente la linea de interrupcion a la que esta conectada el PIC2  esclavo, en este caso como esta conectado a la IRQ2, enciendoel bit 2.

%define ICW3_PIC2 00000010b
;En el caso del PIC2 los bits 7:3 van en 0, y los bits 2:0 indican en codigo binario a que linea del maestro se encuentra conectado el esclavo (En este caso IRQ2)

%define ICW4_PIC1 00000001b
;Lo unico que usamos de aqui es el bit 0, que debe estar en '1' para el caso de uPs 80x86

%define ICW4_PIC2 ICW4_PIC1

%define IMR_PIC1 PIC1_DATA
%define IMR_PIC2 PIC2_DATA
;Interrupt mask register para cada PIC

%define EOI_COMMAND 0x20
;Comando para indcar que finaliza la interrupcion

%define MASK_PIC1 0xFC
;Habilito las interrupciones 0 y 1!!
%define MASK_PIC2 0xFF
;Enmascaro todas las interrupciones


%define COM1 0x3F8 
;Direccion del puerto serie COM1

%define LENGTH_VECT_HANDLERS_EXCEP 32*4
%define LENGTH_VECT_HANDLERS_INTERR 16*4


;********************************************************************************
; Simbolos externos y globales
;********************************************************************************
GLOBAL 		Entry

GLOBAL          IDT32

GLOBAL          PAGE_DIR

EXTERN		start32

EXTERN          vect_handlers

EXTERN          __sys_tables_LMA
EXTERN          __sys_tables_start
EXTERN          __sys_tables_end
EXTERN          __sys_tables_size
EXTERN          __sys_tables_phy_addr

EXTERN          __main_LMA
EXTERN          __main_start
EXTERN          __main_end
EXTERN          __main_size
EXTERN          __main_phy_addr

EXTERN          __mdata_LMA
EXTERN          __mdata_start
EXTERN          __mdata_end
EXTERN          __mdata_size
EXTERN          __mdata_phy_addr

EXTERN          __pag_tables_LMA
EXTERN          __pag_tables_start
EXTERN          __pag_tables_end
EXTERN          __pag_tables_size


EXTERN          __func_LMA
EXTERN          __func_start
EXTERN          __func_end
EXTERN          __func_size
EXTERN          __func_phy_addr

EXTERN          __stack_LMA
EXTERN          __stack_start
EXTERN          __stack_end
EXTERN          __stack_size
EXTERN          __stack_phy_addr

EXTERN          __bss_start
EXTERN          __bss_end
EXTERN          __bss_size
EXTERN          __bss_phy_addr



;********************************************************************************
; Seccion de codigo de inicializacion
;********************************************************************************
USE16
SECTION 	.reset_vector					; Reset vector del procesador

Entry:										; Punto de entrada definido en el linker
	jmp 	dword start						; Punto de entrada de mi BIOS
	times   16-($-Entry) db 0				; Relleno hasta el final de la ROM

;********************************************************************************
; Seccion de codigo de inicializacion
;********************************************************************************
USE32
SECTION 	.init

;--------------------------------------------------------------------------------
; Punto de entrada
;--------------------------------------------------------------------------------
start:									; Punto de entrada
	INCBIN "init16.bin"					; Binario de 16 bits

;Saltar a Init32
 
 
;;CODIGO AGREGADO POR GONZALO
    
;Movimiento del codigo correspondiente a las tablas de sistema usando los datos del linker script, lo debo hacer sin llamadas ya que no puedo usar el stack pointer hasta tanto no inicialice las estructuras!   

    mov esi, __sys_tables_LMA
    mov edi, __sys_tables_phy_addr ;Muevo las tablas a su DIRECCION FISICA FINAL!!!!
    mov ecx, __sys_tables_size
    rep movsb 
 
    
;Cargo la GDT DE MANERA PROVISORIA, ya que la tengo en memoria fisica, la tengo que cargar con la direccion de base de memoria fisica hasta habilitar la paginacion
    mov eax,my_gdtr; muevo la parte del "Tamaño" a bx.
    sub eax,__sys_tables_start ; le resto la direccion LINEAL de inicio (conozco su ofset dentro de la seccion)
    add eax,__sys_tables_phy_addr; le sumo la direccion FISICA a la cual copie la ENTRADA DEL REGISTRO DE TABLA. De esta forma conozco la direccion final en ram.
    ;En eax ya tengo la direccion donde esta ubicada my_gdtr en RAM, el problema es que la parte del gdtr copiado tiene aún la direccion base LINEAL original (erronea). Debo entonces modificar esa direccion base y cambiarla por la FISICA, para poder cargar el GDTR
    lea ebx,[eax+2]; cargo la direccion en la que se encuentra el campo de base.
    mov dword[ebx],__sys_tables_phy_addr; cargo en esa posicion la DIRECCION FISICA.
    lgdt [eax]

    xchg bx,bx    
;Inicializacion de la pila para poder llamar funciones!!
    mov ax,SEL_DATOS
    mov ss,ax
    mov eax,__stack_phy_addr
    add eax,__stack_size
    mov esp,eax ;(direccion fisica de la pila + tamaño, ojo no pisar otras secciones!!)    
    
;Movimiento del resto del codigo a los lugares que corresponda! los parametros los pasa el Linker Script       
    push __main_size
    push __main_LMA
    push __main_phy_addr
    call my_memcpy
    add esp,3*4
    
    push __func_size
    push __func_LMA
    push __func_phy_addr
    call my_memcpy
    add esp,3*4
    
    push __mdata_size
    push __mdata_LMA
    push __mdata_phy_addr
    call my_memcpy
    add esp,3*4
    
;Inicializo en cero las zonas de memoria dinamica    
    xor eax,eax ;limpio el registro eax para que quede en cero
    mov edi, __bss_phy_addr
    mov ecx, __bss_size
    rep stosb ;lleno toda la region de memoria correspondiente a variables no inicializadas con ceros
    

    ;Inicializo las tablas de PAGINACION!!
    call InitTabPAG
    
    mov eax,CR0; cargo CR0 en eax
    or eax, 0x80000000; enciendo el bit 31, habilito paginacion!
    mov CR0,eax
    
;Una vez habilitada la paginacion, el procesador va a buscar my_gdtr y la va a traducir de memoria lineal a fisica... pero como en fisica tengo cargado
;El valor de gdtr fisico, y debo en realidad guardar el lineal en el registro... entonces lo debo editar!.
    mov dword[my_gdtr+2],__sys_tables_start; cargo la base con la direccion lineal!!
    lgdt[my_gdtr]; cargo el registro GDTR
    
;Tambien debo recargar la pila!! ahora ya con las direcciones LINEALES
    mov ax,SEL_DATOS
    mov ss,ax
    mov esp,__stack_end
    
;Carga de la IDT. LA DEBO CARGAR DESPUES DE LAS TABLAS DE PAGINAS YA QUE DISPONGO DE LAS DIRECCIONES LINEALES DE LOS HANDLERS por el linker script.
    call InitIDT
;Carga de las tablas de sistema
    lidt [my_idtr] 
    
;Inicializacion de los PICs
    call InitPIC; llamada a la rutina de inicializacion de los PICS

;Inicializacion del PIT
    call InitPIT

;Inicializacion del puerto serie
    call InitCOM1
    
;Habilitacion de las interrupciones    
    sti

;Salto al main
    mov eax,start32 ;coloco en eax el offset del start
    push dword SEL_CODIGO ; Pusheo primero el selector de codigo
    push eax ;luego el offset
    retf ;si hago un return far saltare a SEL_CODIGO:start32 que es en el archivo "main"


;;CODIGO AGREGADO POR GONZALO
    
;--------------------------------------------------------------------------------
; Inicializacion de la idt
;--------------------------------------------------------------------------------
InitIDT:
    mov ecx,0
    mov ebx, LENGTH_VECT_HANDLERS_EXCEP ; cargo del vector de handlers de excepciones en ebx
    shr ebx,2 ;desplazo 2 bits hacia la derecha, es decir divido por 4, ya que cada handler es de 4 bytes, con esto tendre el numero de handlers
    
    cmp ecx, ebx; si ebx es cero, es porque no hay descriptores, no necesito cargar handlers
    je fin_carga_idt

    
;carga de la parte de excepciones de la IDT
ciclo_carga_idt_excep:
    mov eax, [vect_handlers+4*ecx] ;cada handler es una etiqueta, estan espaciadas 4bytes en el vector
    mov [IDT32+8*ecx], ax
    mov word[IDT32+8*ecx+2], SEL_CODIGO
    mov byte[IDT32+8*ecx+4],0x00
    mov byte[IDT32+8*ecx+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*ecx+6],ax
    inc ecx
    cmp ecx,ebx ;carga hasta el descriptor CANT_HANDLERS-1!
    jne ciclo_carga_idt_excep

    mov edx, LENGTH_VECT_HANDLERS_INTERR; cargo la cantidad de handlers de interrupciones en edx
    shr edx,2; la divido por 4, ya que cada handler tiene 4 bytes, con esto tendre el numero de handlers de interrupciones
    add ebx,edx; le sumo a ebx, edx. Con esto tendre el total de handlers de interrupciones y excepciones y se hasta donde tengo que llenar la IDT 
ciclo_carga_idt_interr:
     mov eax, [vect_handlers+4*ecx] ;cada handler es una etiqueta, estan espaciadas 4bytes en el vector
     mov [IDT32+8*ecx], ax
     mov word[IDT32+8*ecx+2], SEL_CODIGO
     mov byte[IDT32+8*ecx+4],0x00
     mov byte[IDT32+8*ecx+5],0x8E;
     shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
     mov[IDT32+8*ecx+6],ax
     inc ecx
     cmp ecx,ebx ;carga hasta el descriptor CANT_HANDLERS-1!
     jne ciclo_carga_idt_interr    

fin_carga_idt:
    ret

;--------------------------------------------------------------------------------
; Inicializacion de las tablas de paginacion!
;--------------------------------------------------------------------------------
InitTabPAG:
 ;Busco hacer identity mapping, direcciones lineales se corresponden con las fisicas, ahora uso paginas de 4k
 ;Debo mapear las paginas de la rom y el Vector de reset es decir desde 0xFFFF0000 a 0xFFFF FFFF (es decir los ultimos 64k = 16 paginas) de la ultima entrada del directorio!.
 
 ;La base de la tabla correspondiente a esta entrada del directorio es PAGE_TABLE1024, por lo tanto, los bits 31 a 12, deberan contener los primeros 20 bits de esta etiqueta.
 mov eax, PAGE_TABLE1024; como es una entrada de tabla de paginas, se suponen que los primeros 12 bits estan en cero!
 or eax, 0x03; para que sea pagina presente y de lectura ecareyscritura
 mov dword[PAGE_DIR+1023*4],eax 
 
 
;Tambien debo mapear la memoria de video 0x000B 8000 y  de 0x0010 0000 a 0x0015 0000 todo esto corresponde a la primera entrada del directorio! que si hago identity mapping    ;abarcaria desde la direccion 0x0000 0000 hasta la direccion 0x0040 0000
mov eax, PAGE_TABLE1
or eax,0x03
mov dword[PAGE_DIR],eax ;  bit 0= 1 (presente), bit 1='1' (R/W) bit 7='1' (paginas grandes!!). Los bits 31 a 22 van en 0, ya que voy a mapear con identity mapping los primeros 4mb!!!


;Inicializacion de las tablas de paginas.

;Paginas page table 1: 0x0000 0000 a 0x0000 1000 (fisicas) entrada 1, no presente
;                      0x0000 1000 a 0x000B 8000 (fisicas) entradas 2 a 184 inclusive, no presentes
;                      0x0000 B800 a 0x000B 9000 (fisicas) entrada 185, presente! memoria de video.
;                      0x0000 B900 a 0x0010 0000 (fisicas) entrada 186 a 256 no presentes!
;                      0x0010 0000 a 0x0015 0000 (fisicas) entradas 257 a 336 presentes para el codigo.
;                      0x0015 0000 a 0x0040 0000 (fisicas) entradas entradas 337 a 1024 no presentes
mov eax, 0xB8000; cargo eax con la direccion de video.
shr eax, 12; shifteo 12 bits, que es lo mismo que dividir por 4096, esto me da 0xB8=184!
mov dword[PAGE_TABLE1+eax*4],0x000B8003; apunta la direccion fisica B8000!! la base de la pagina!!


mov eax, 0x00000 ; a partir de cuando necesito paginas.
or eax, 0x03; prendo los ultimos 3 bits que van a quedar siempre encendidos por la configuracion de la pagina

ciclo_InitPAG1_IM: ; en esta parte cargo las primeras 0x100000 direcciones que van con identity mapping para las tablas de paginas, memoria de video, etc
    mov ebx,eax;
    shr ebx, 12; shifteo 12 bits, es decir divido por 0x1000 = 4096
    mov dword[PAGE_TABLE1+ebx*4],eax; cargo la entrada
    add eax, 0x1000; le sumo a eax 0x1000 es decir, empezara en 0x100003 luego 0x101003 y asi... hasta la ultima pagina que terminara en 0x150000 
    cmp eax, 0x100000; hasta esta direccion hago identity mapping
    jb ciclo_InitPAG1_IM; me voy si ya cargue todas las paginas!.
    
ciclo_InitPAG1_NIM: ;en esta parte cargo lo que NO ES identy mapping. Es decir desde la 0x100000 hasta la 0x400000 (todo el resto de la primera pagina)
    mov ebx,eax;
    mov edx,eax;
    add edx,0x100000; le sumo 0x100000 que es la diferencia entre las direcciones LINEALES y las FISICAS (Fisicas = Lineales + 0x100000 en este caso, por enunciado)
    shr ebx, 12; shifteo 12 bits, es decir divido por 0x1000 = 4096
    mov dword[PAGE_TABLE1+ebx*4],edx; cargo la entrada
    add eax, 0x1000; le sumo a eax 0x1000 es decir, empezara en 0x100003 luego 0x101003 y asi... hasta la ultima pagina que terminara en 0x150000 
    cmp eax, 0x400000; hasta esta direccion hago identity mapping
    jb ciclo_InitPAG1_NIM; me voy si ya cargue todas las paginas!.
    

mov eax, 0xFFFF0000; a partir de esta direccion y hasta 0xFFFF FFFF quiero paginar, es decir 64k= 16 paginas     
or eax, 0x03

ciclo_InitPAG1024:
    mov ebx,eax;
    sub ebx, 1024*1023*4096; como es identity mapping la ultima entrada del directorio direccionara desde 1024*1023*4096 hasta 1024*1024*4096 o lo que es lo mismo decir, desde 0xFFC0 0000 a 0xFFFF FFFF. Le resto entonces 0xFFC0 0000 a 0xFFFF 0000
    shr ebx, 12; shifteo 12 bits, es decir divido por 0x1000 = 4096 para conocer finalmente el indice dentro de la tabla!
    mov dword[PAGE_TABLE1024+ebx*4],eax; cargo la entrada
    add eax, 0x1000; le sumo a eax 0x1000 es decir, empezara en 0x100003 luego 0x101003 y asi... hasta la ultima pagina que terminara en 0x150000 
    cmp eax, 0xFFFFF003;
    jne ciclo_InitPAG1024; me voy si ya cargue todas las paginas!.

    
fin_InitPAG:
mov eax, PAGE_DIR; cargo en eax la base del directorio de paginas
mov CR3, eax; cargo CR3 con la base del directorio de paginas!!

ret




;--------------------------------------------------------------------------------
;Rutina de copiado de codigo

;void* my_memcpy(void * destination, void* source, uint size);
; EIP de regreso: EBP+4
; destination: EBP+8
; source: EBP+12
; size: EBP+16
;--------------------------------------------------------------------------------
my_memcpy:
  
  push ebp
  mov ebp,esp
  
  mov esi, [ebp+12]
  mov edi, [ebp+8]
  mov ecx, [ebp+16]
  rep movsb
  
  pop ebp

ret


;--------------------------------------------------------------------------------
; Inicializacion del controlador de interrupciones
; Corre la base de los tipos de interrupción de ambos PICs 8259A de la PC a los 8 tipos consecutivos a 
; partir de los valores base que recibe en BH para el PIC Nº1 y BL para el PIC Nº2.
; A su retorno las Interrupciones de ambos PICs están deshabilitadas.
;--------------------------------------------------------------------------------
InitPIC:
        ;COMIENZO DE INICIALIZACION: envío la ICW1 a los dos PICs por el puerto de comandos
        mov al,ICW1_PIC1
	out PIC1_COMMAND,al									
	
	mov al, ICW1_PIC2
	out PIC2_COMMAND,al
	
	;MAPEO DE LAS IRQ: la ICW2 va por el port de data no por el de comandos!
	mov al,ICW2_PIC1
	out PIC1_DATA,al
	
	mov al,ICW2_PIC2
	out PIC2_DATA,al
	
	;SELECCION DE IRQ QUE UNE MAESTRO Y ESCLAVO: envio la ICW3 a los dos PICs, va por data
        mov al,ICW3_PIC1
	out PIC1_DATA,al									
	
	mov al, ICW3_PIC2
	out PIC2_DATA,al
	
	;SETEO MODO x86: envio la ICW4 a los dos PICs, va por data
	mov al,ICW4_PIC1
	out PIC1_DATA,al									
	
	mov al, ICW4_PIC2
	out PIC2_DATA,al
	
	;En el PIC 1 habilito la IRQ1 (teclado)
	mov al,MASK_PIC1
	out IMR_PIC1, al
	mov al,MASK_PIC2
	out IMR_PIC2, al
	
	ret
	
;--------------------------------------------------------------------------------
; Inicializacion del controlador del PIT
;--------------------------------------------------------------------------------
InitPIT:
    
	mov al,00110110b
	out 0x43, al 
	;0x43 Puerto del registro de control del 8253.
	;Byte de control 
	;  7:6='00', uso el counter/canal 0
	;  5:4= '11' esta opcion indica que primero se Lee o carga el LSB y luego el MSB
        ;  3:1='011' Estos 3 bits indican el modo, en este caso: Modo 3= Square Wave generator. Busco generar una señal cuadrada de 10ms de periodo = 100Hz de frecuencia. El modo 3 hace que la salida este en estado ALTO durante la mitad las cuentas y en bajo durante la otra mitad!
        ;0 ='0' Indica que es un contador binario (si estuviera en '1' seria BCD)
        
        
        mov ax, 1193181 / 100; La frecuencia de clock del contador es 1.193.181Hz / 100 Hz (que es la frecuencia que quiero) me da las cuentas necesarias para lograr una cuadrada de periodo 10ms
 
        ;Ahora debo cargar el canal 0 (0x40) con la cuenta indicada. Para ello, y dado lo especificado en la palabra de control, primero debo cargar el LSB y luego el MSB
	out	0x40, al	;LSB
	xchg	ah, al
	out	0x40, al	;MSB

ret

;--------------------------------------------------------------------------------
; Inicializacion del controlador de puerto serie
;--------------------------------------------------------------------------------
InitCOM1:
    mov al, 0x00
    mov dx,COM1+1
    out dx, al; deshabilito todas las interrupciones
    
    mov al, 0x80 
    mov dx,COM1+3
    out dx, al; habilito el bit "DLAB"='1' setear el divisor de baud rate.
    
    ;como quiero baud rate=9600bauds => 115200/12 = 9600, ek divisor debe ser 12!
    ;el LSB del divisor va en COM1+0 y el MSB va en COM1+1, MSB=0x00 y LSB=0x0C
    mov al, 0x0C
    mov dx, COM1+0
    out dx,al
    mov al, 0x00
    mov dx,COM1+1
    out dx,al
    
    mov al, 00000011b
    mov dx,COM1+3
    out dx,al; saco el DLAB='0', break='0', sin paridad = '000', un bit de stop='0', palabra de 8 bits= '11'
    
    mov al, 0x00
    mov dx,COM1+2
    out dx, al; DESHABILITO LA PILA!, compatibilidad con 8250
    
    mov al, 0x00; no habilito ninguna
    mov dx,COM1+1
    out dx,al; Habilito las interrupciones de recepcion y de transmision! (0 y 1 respectivamente)
    
    ret


;********************************************************************************
; Tablas de sistema
;********************************************************************************
SECTION		.sys_tables 	progbits
ALIGN 4

;--------------------------------------------------------------------------------
; GDT
;--------------------------------------------------------------------------------
GDT32:

SEL_NULO equ $-GDT32
    times 8 db 0
    
SEL_CODIGO equ $-GDT32
    db 0xFF; 
    db 0xFF
    db 0x00
    db 0x00
    db 0x00
    db 10011000b;
    db 11001111b;
    db 0x00
    
SEL_DATOS equ $-GDT32
    db 0xFF
    db 0xFF
    db 0x00
    db 0x00
    db 0x00
    db 10010010b;
    db 11001111b;
    db 0x00
LENGTH_GDT equ $-GDT32

my_gdtr: dw LENGTH_GDT-1
         dd GDT32

my_idtr: dw LENGTH_IDT-1
         dd IDT32
         
;--------------------------------------------------------------------------------
; IDT
;--------------------------------------------------------------------------------
SECTION .sys_idt nobits

IDT32:
resq LENGTH_VECT_HANDLERS_EXCEP
resq LENGTH_VECT_HANDLERS_INTERR
LENGTH_IDT equ $-IDT32




SECTION     .stack nobits

resd STACK_SIZE

SECTION		.pag_tables nobits ; VA NO BITS PARA LOS DATOS NO INICIALIZADOS!!!!

PAGE_DIR:
    resd 1024; defino las 1024 entradas del directorio de paginas
;LENGTH_PAGE_DIR equ $-PAGE_DIR

PAGE_TABLE1:
    resd 1024; defino las 1024 entradas de la tabla de paginas!
;LENGHT_PAGE_TABLE1 equ $-PAGE_TABLE1

PAGE_TABLE1024:
    resd 1024; defino las 1024 entradas de la tabla de paginas!
;LENGHT_PAGE_TABLE1024 equ $-PAGE_TABLE1024





;********************************************************************************
; 						-  -- --- Fin de archivo --- --  -
; D. Garcia 																c2013
;********************************************************************************

