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

EXTERN		start32

EXTERN          vect_handlers

EXTERN          __sys_tables_LMA
EXTERN          __sys_tables_start
EXTERN          __sys_tables_end
EXTERN          __main_LMA
EXTERN          __main_start
EXTERN          __main_end
EXTERN          __mdata_LMA
EXTERN          __mdata_start
EXTERN          __mdata_end
EXTERN          __pag_tables_LMA
EXTERN          __pag_tables_start
EXTERN          __pag_tables_end
EXTERN          __func_LMA
EXTERN          __func_start
EXTERN          __func_end

EXTERN          __stack_LMA
EXTERN          __stack_start
EXTERN          __stack_end

EXTERN          __bss_start
EXTERN          __bss_end



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
    
;Movimiento del codigo a los lugares que corresponda! los parametros los pasa el Linker Script
    
    
    mov esi, __sys_tables_LMA
    mov edi, __sys_tables_start
    mov ecx, __sys_tables_end
    sub ecx,__sys_tables_start ;calculo la longitud en memoria
    rep movsb 

    mov esi, __main_LMA
    mov edi, __main_start
    mov ecx, __main_end
    sub ecx, __main_start ;calculo la longitud en memoria
    rep movsb
    
    mov esi, __mdata_LMA
    mov edi, __mdata_start
    mov ecx, __mdata_end
    sub ecx, __mdata_start ;calculo la longitud en memoria
    rep movsb 
    
    mov esi, __func_LMA
    mov edi, __func_start
    mov ecx, __func_end
    sub ecx, __func_start ;calculo la longitud en memoria
    rep movsb 
    
    mov edi, __stack_start
    mov ecx, __stack_end
    sub ecx, __stack_start
    rep stosb ;lleno toda la region de memoria correspondiente a variables no inicializadas con ceros
    
    xor eax,eax ;limpio el registro eax para que quede en cero
    mov edi, __bss_start
    mov ecx, __bss_end
    sub ecx, __bss_start
    rep stosb ;lleno toda la region de memoria correspondiente a variables no inicializadas con ceros
    
;Inicializacion de la pila. ANTES QUE NADA DEBO INICIALIZAR LA PILA PARA LUEGO PODER LLAMAR FUNCIONES!!!!!!!!
    mov ax,SEL_DATOS
    mov ss,ax
    mov esp,__stack_end ;(direccion fisica de la pila + tamaño, ojo no pisar otras secciones!!)
    
    
;Carga de la IDT
    call InitIDT

;Carga de las tablas de sistema
    lgdt [my_gdtr]
    lidt [my_idtr] 

    
;Inicializo las tablas de PAGINACION!!
    call InitTabPAG
    
    xchg bx,bx
    mov eax,CR0; cargo CR0 en eax
    or eax, 0x80000000; enciendo el bit 31, habilito paginacion!
    mov CR0,eax
    
    xchg bx,bx
    mov ax,ax
    
;Inicializacion de los PICs
    call InitPIC; llamada a la rutina de inicializacion de los PICS

;Inicializacion del PIT
    call InitPIT

;Inicializacion del puerto serie
    call InitCOM1
    
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

;********************************************************************************
; Inicializacion de las tablas de paginacion!
;*********************************************************************************
InitTabPAG:
 ;Busco hacer identity mapping, direcciones lineales se corresponden con las fisicas, ahora uso paginas de 4k
 ;Debo mapear las paginas de la rom y el Vector de reset es decir desde 0xFFFF0000 a 0xFFFF FFFF (es decir los ultimos 64k = 16 paginas) de la ultima entrada del directorio!.
 ;Para ello lo primero que debo hacer es cargar 

 
xchg bx,bx
; CARGA DEL LA TABLA DE PUNTEROS A DIRECTORIOS DE PAGINAS
;Cargo la entrada del puntero a directorio de paginas 0. Para direccionar de 0x00000000 a 0x00200000
 mov eax,PAGE_DIR0
 or eax, 0x01 ;entrada del directorio presente. NO VA W/R!!!. 
 mov dword[PAGE_DIR_POINTER_TABLE+0*8],eax
 mov dword[PAGE_DIR_POINTER_TABLE+0*8+4],0x00;
 
;Cargo la entrada del puntero a directorio de paginas 4. Para direccionar de 0xFFFF0000 a 0xFFFFFFFF
 mov eax,PAGE_DIR3
 or eax,0x01 ;entrada del directorio presente. NO VA W/R!!!. 
 mov dword[PAGE_DIR_POINTER_TABLE+3*8],eax
 mov dword[PAGE_DIR_POINTER_TABLE+3*8+4],0x00;
 

;CARGA DE LOS DIRECTORIOS DE PAGINAS

;Cargo la entrada 511 del directorio 3, para direccionar de 0xFFFF0000 a 0xFFFFFFFF
 mov eax, PAGE_TABLE3_511
 or eax, 0x03
 mov dword[PAGE_DIR3+511*8],eax;
 mov dword[PAGE_DIR3+511*8+4],0x00
 
;Cargo la entrada 0 del directorio 0, para direccionar de 0x00000000 a 0x00200000
 mov eax, PAGE_TABLE0_0
 or eax, 0x03
 mov dword[PAGE_DIR0+0*8],eax;
 mov dword[PAGE_DIR0+0*8+4],0x00


;CARGA DE LAS TABLAS DE PAGINAS

;Cargo todas las entradas de la tabla 0 del directorio 0 para hacer identity mapping de las direcciones 0x00000000 a 0x00200000
mov eax, 0x00000000; a partir de aqui necesito paginas
or eax, 0x03; prendo lo ultimos 3 bits que van a quedar siempre encendidos por la configuracion de la pagina

ciclo_InitPAG0_0:
    mov ebx,eax;
    shr ebx, 12 ; shifteo 12 bits, es decir divido por 0x1000 = 4096
    mov dword[PAGE_TABLE0_0+ebx*8],eax; cargo la entrada
    mov dword[PAGE_TABLE0_0+ebx*8+4],0x00;
    add eax, 0x1000; le sumo a eax 0x1000 es decir, empezara en 0x100003 luego 0x101003 y asi... hasta la ultima pagina que terminara en 0x00200000 
    cmp eax, 0x00200000;
jb ciclo_InitPAG0_0; me voy si ya cargue todas las paginas!.
 
 
;Cargo las entradas de la tabla 511 del directorio 3 NECESARIAS para hacer identity mapping de las direcciones 0xFFFF0000 a 0xFFFFFFFF
mov eax, 0xFFFF0000; a partir de esta direccion y hasta 0xFFFF FFFF quiero paginar, es decir 64k= 16 paginas     
or eax, 0x03

ciclo_InitPAG3_511:
    mov ebx,eax;
    sub ebx,0xFFFFFFFF-0x00200000 ;como es identity mapping la ultima entrada del directorio direccionara desde (0xFFFFFFFF-0x002000000)=0xFFDFFFFF hasta 0xFFFFFFFF
    shr ebx, 12; shifteo 12 bits, es decir divido por 0x1000 = 4096 para conocer finalmente el indice dentro de la tabla!
    mov dword[PAGE_TABLE3_511+ebx*8],eax; cargo la entrada
    mov dword[PAGE_TABLE3_511+ebx*8+4],0x00
    add eax, 0x1000; le sumo a eax 0x1000 es decir, empezara en 0x100003 luego 0x101003 y asi... hasta la ultima pagina que terminara en 0x150000 
    cmp eax, 0xFFFFF003;
jne ciclo_InitPAG3_511; me voy si ya cargue todas las paginas!.

    
fin_InitPAG:

mov eax, CR4
or eax, (0x01<<0x05); enciendo el BIT 5 de CR4 (para habilitar PAE)
mov CR4,eax

mov eax, PAGE_DIR_POINTER_TABLE; cargo en eax la base del directorio de paginas
mov CR3, eax; cargo CR3 con la base del directorio de paginas!!

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

PAGE_DIR0:
    resd 1024 ;defino las 1024 entradas del directorio de paginas

PAGE_DIR3:
    resd 1024

PAGE_TABLE0_0:
    resd 1024; defino las 1024 entradas de la tabla de paginas!
;LENGHT_PAGE_TABLE1 equ $-PAGE_TABLE1

PAGE_TABLE3_511:
    resd 1024; defino las 1024 entradas de la tabla de paginas!
;LENGHT_PAGE_TABLE1024 equ $-PAGE_TABLE1024

PAGE_DIR_POINTER_TABLE:
    resd 8; defino las 4 entradas del puntero a directorios de paginas, PARA PAE





;********************************************************************************
; 						-  -- --- Fin de archivo --- --  -
; D. Garcia 																c2013
;********************************************************************************

