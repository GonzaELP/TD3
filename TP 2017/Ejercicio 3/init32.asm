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
%define STACK_SIZE 32*1024

;********************************************************************************
; Simbolos externos y globales
;********************************************************************************
GLOBAL 		Entry
EXTERN		start32
EXTERN          vect_handlers
;Handlers de excepciones
;EXTERN          handler_excep0
;EXTERN          handler_excep1
;EXTERN          handler_excep2
;EXTERN          handler_excep3
;EXTERN          handler_excep4
;EXTERN          handler_excep5
;EXTERN          handler_excep6
;EXTERN          handler_excep7
;EXTERN          handler_excep8
;EXTERN          handler_excep9
;EXTERN          handler_excep10
;EXTERN          handler_excep11
;EXTERN          handler_excep12
;EXTERN          handler_excep13
;EXTERN          handler_excep14
;Se saltea la 15, es reservada
;EXTERN          handler_excep16
;EXTERN          handler_excep17
;EXTERN          handler_excep18
;EXTERN          handler_excep19
;EXTERN          handler_excep20
;Se saltea 21-29, son reservadas
;EXTERN          handler_excep30
;Se saltea la 31, es reservada

;Handlers de interrupciones
;EXTERN          handler_interr0
;EXTERN          handler_interr1
;EXTERN          handler_interr2
;EXTERN          handler_interr3
;EXTERN          handler_interr4
;EXTERN          handler_interr5
;EXTERN          handler_interr6
;EXTERN          handler_interr7
;EXTERN          handler_interr8
;EXTERN          handler_interr9
;EXTERN          handler_interr10
;EXTERN          handler_interr11
;EXTERN          handler_interr12
;EXTERN          handler_interr13
;EXTERN          handler_interr14
;EXTERN          handler_interr15


EXTERN          __sys_tables_LMA
EXTERN          __sys_tables_start
EXTERN          __sys_tables_end
EXTERN          __main_LMA
EXTERN          __main_start
EXTERN          __main_end
EXTERN          __mdata_LMA
EXTERN          __mdata_start
EXTERN          __mdata_end
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
    sub ecx,__main_start ;calculo la longitud en memoria
    rep movsb 
    
    mov esi, __mdata_LMA
    mov edi, __mdata_start
    mov ecx, __mdata_end
    sub ecx,__mdata_start ;calculo la longitud en memoria
    rep movsb 
    
    xor eax,eax ;limpio el registro eax para que quede en cero
    mov edi, __bss_start
    mov ecx, __bss_end
    sub ecx, __bss_start
    rep stosb ;lleno toda la region de memoria correspondiente a variables no inicializadas con ceros

;Carga de las tablas de sistema
    lgdt [my_gdtr]
    lidt [my_idtr]
    
;Carga de la IDT
    call InitIDT


;Inicializacion de la pila.
    mov ax,SEL_DATOS
    mov ss,ax
    mov esp,STACK_ADDRESS+STACK_SIZE ;(direccion fisica de la pila + tamaño, ojo no pisar otras secciones!!)

;Inicializacion de los PICs
    mov bx, 0x2028 ; Base de los pics, similar a un paso de parametros por registro.
    call InitPIC; llamada a la rutina de inicializacion de los PICS

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


;Excepcion 0 (division por cero)
    ;mov eax, handler_excep0
    mov eax, [vect_handlers+0*4]
    mov [IDT32+8*0], ax
    mov word[IDT32+8*0+2], SEL_CODIGO
    mov byte[IDT32+8*0+4],0x00
    mov byte[IDT32+8*0+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*0+6],ax
    
;Excepcion 1
    ;mov eax, handler_excep1
    mov eax, [vect_handlers+1*4]
    mov [IDT32+8*1], ax
    mov word[IDT32+8*1+2], SEL_CODIGO
    mov byte[IDT32+8*1+4],0x00
    mov byte[IDT32+8*1+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*1+6],ax

;Excepcion 2
    ;mov eax, handler_excep2
    mov eax, [vect_handlers+2*4]
    mov [IDT32+8*2], ax
    mov word[IDT32+8*2+2], SEL_CODIGO
    mov byte[IDT32+8*2+4],0x00
    mov byte[IDT32+8*2+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*2+6],ax

;Excepcion 3
    ;mov eax, handler_excep3
    mov eax, [vect_handlers+3*4]
    mov [IDT32+8*3], ax
    mov word[IDT32+8*3+2], SEL_CODIGO
    mov byte[IDT32+8*3+4],0x00
    mov byte[IDT32+8*3+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*3+6],ax

;Excepcion 4
    ;mov eax, handler_excep4
    mov eax, [vect_handlers+4*4]
    mov [IDT32+8*4], ax
    mov word[IDT32+8*4+2], SEL_CODIGO
    mov byte[IDT32+8*4+4],0x00
    mov byte[IDT32+8*4+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*4+6],ax

;Excepcion 5
    ;mov eax, handler_excep5
    mov eax, [vect_handlers+5*4]
    mov [IDT32+8*5], ax
    mov word[IDT32+8*5+2], SEL_CODIGO
    mov byte[IDT32+8*5+4],0x00
    mov byte[IDT32+8*5+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*5+6],ax

;Excepcion 6 (Invalid opcode)
    ;mov eax, handler_excep6;
    mov eax, [vect_handlers+6*4]
    mov [IDT32+8*6], ax
    mov word[IDT32+8*6+2], SEL_CODIGO
    mov byte[IDT32+8*6+4],0x00
    mov byte[IDT32+8*6+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*6+6],ax

;Excepcion 7
    ;mov eax, handler_excep7
    mov eax, [vect_handlers+7*4]
    mov [IDT32+8*7], ax
    mov word[IDT32+8*7+2], SEL_CODIGO
    mov byte[IDT32+8*7+4],0x00
    mov byte[IDT32+8*7+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*7+6],ax

;Excepcion 8
    ;mov eax, handler_excep8
    mov eax, [vect_handlers+8*4]
    mov [IDT32+8*8], ax
    mov word[IDT32+8*8+2], SEL_CODIGO
    mov byte[IDT32+8*8+4],0x00
    mov byte[IDT32+8*8+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*8+6],ax

;Excepcion 9
    ;mov eax, handler_excep9
    mov eax, [vect_handlers+9*4]
    mov [IDT32+8*9], ax
    mov word[IDT32+8*9+2], SEL_CODIGO
    mov byte[IDT32+8*9+4],0x00
    mov byte[IDT32+8*9+5],0x8E;
    shr eax, 16 ; debo borrar los primeros 16 bits, asi me quedo con la parte alta
    mov[IDT32+8*9+6],ax
    
    ret

    
;--------------------------------------------------------------------------------
; Inicializacion del controlador de interrupciones
; Corre la base de los tipos de interrupción de ambos PICs 8259A de la PC a los 8 tipos consecutivos a 
; partir de los valores base que recibe en BH para el PIC Nº1 y BL para el PIC Nº2.
; A su retorno las Interrupciones de ambos PICs están deshabilitadas.
;--------------------------------------------------------------------------------
InitPIC:
										; Inicialización PIC Nº1
										; ICW1
	mov		al, 11h         			; IRQs activas x flanco, cascada, y ICW4
	out     20h, al  
										; ICW2
	mov     al, bh          			; El PIC Nº1 arranca en INT tipo (BH)
	out     21h, al
										; ICW3
	mov     al, 04h         			; PIC1 Master, Slave ingresa Int.x IRQ2
	out     21h, al
										; ICW4
	mov     al, 01h         			; Modo 8086
	out     21h, al
										; Antes de inicializar el PIC Nº2, deshabilitamos 
										; las Interrupciones del PIC1
	mov     al, 0FFh
	out     21h, al
										; Ahora inicializamos el PIC Nº2
										; ICW1
	mov     al, 11h        			  	; IRQs activas x flanco,cascada, y ICW4
	out     0A0h, al  
										; ICW2
	mov    	al, bl          			; El PIC Nº2 arranca en INT tipo (BL)
	out     0A1h, al
										; ICW3
	mov     al, 02h         			; PIC2 Slave, ingresa Int x IRQ2
	out     0A1h, al
										; ICW4
	mov     al, 01h         			; Modo 8086
	out     0A1h, al
										; Enmascaramos el resto de las Interrupciones 
										; (las del PIC Nº2)
	mov     al, 0FFh
	out     0A1h, al
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


;--------------------------------------------------------------------------------
; IDT
;--------------------------------------------------------------------------------

IDT32:
;Excepciones del procesador
DESC_EXCEP0 equ $-IDT32 ;Divide-by-zero error. [Fault/#DE/CE=No]
    dq 0x0
DESC_EXCEP1 equ $-IDT32 ;Debug. [Fault or Trap/#DB/CE=No]
    dq 0x0
DESC_EXCEP2 equ $-IDT32 ;Non-maskable interrupt. [Interrupt/-/CE=No]
    dq 0x0
DESC_EXCEP3 equ $-IDT32 ;Breakpoint. [Trap/#BP/CE=No]
    dq 0x0
DESC_EXCEP4 equ $-IDT32 ;Overflow. [Trap/#OF/CE=No]
    dq 0x0
DESC_EXCEP5 equ $-IDT32 ;Bound range exceeded . [Fault/#BR/CE=No]
    dq 0x0
DESC_EXCEP6 equ $-IDT32 ;Invalid opcode. [Fault/#UD/CE=No]
    dq 0x0 
DESC_EXCEP7 equ $-IDT32 ;Device not available. [Fault/#NM/CE=No]
    dq 0x0
DESC_EXCEP8 equ $-IDT32 ;Double fault. [Abort/#DF/CE=Si(Cero)]
    dq 0x0 
DESC_EXCEP9 equ $-IDT32 ;Coprocessor segment overrun. [Fault/-/CE=No]
    dq 0x0 
DESC_EXCEP10 equ $-IDT32 ;Invalid TSS. [Fault/#TS/CE=Yes)]
    dq 0x0 
DESC_EXCEP11 equ $-IDT32 ;Segment not Present. [Fault/#TS/CE=Yes)]
    dq 0x0 
DESC_EXCEP12 equ $-IDT32 ;Stack segment fault. [Fault/#SS/CE=Yes)]
    dq 0x0 
DESC_EXCEP13 equ $-IDT32 ;General protection fault. [Fault/#GP/CE=Yes)]
    dq 0x0 
DESC_EXCEP14 equ $-IDT32 ;Page fault. [Fault/#PF/CE=Yes)]
    dq 0x0 
DESC_EXCEP15 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0 
DESC_EXCEP16 equ $-IDT32 ;x87 floating-point exception. [Fault/#MF/CE=No)]
    dq 0x0 
DESC_EXCEP17 equ $-IDT32 ;Alignment check. [Fault/#AC/CE=Yes)]
    dq 0x0  
DESC_EXCEP18 equ $-IDT32 ;Machine check. [Abort/#MC/CE=No)]
    dq 0x0 
DESC_EXCEP19 equ $-IDT32 ;SIMD floating-point exception. [Fault/#XM o #XF/CE=No)]
    dq 0x0 
DESC_EXCEP20 equ $-IDT32 ;Virtualization exception. [Fault/#VE/CE=No)]
    dq 0x0 
DESC_EXCEP21 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0 
DESC_EXCEP22 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0
DESC_EXCEP23 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0
DESC_EXCEP24 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0
DESC_EXCEP25 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0
DESC_EXCEP26 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0
DESC_EXCEP27 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0
DESC_EXCEP28 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0
DESC_EXCEP29 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0
DESC_EXCEP30 equ $-IDT32 ;Security exception. [-/#SX/CE=Yes)]
    dq 0x0
DESC_EXCEP31 equ $-IDT32 ;Reserved. [-/-/CE=No)]
    dq 0x0

;Interrupciones
;PIC MAESTRO
DESC_INTERR32 equ $-IDT32 ;Programmable timer interrupt
    dq 0x0
DESC_INTERR33 equ $-IDT32 ;Keyboard interrupt
    dq 0x0
DESC_INTERR34 equ $-IDT32 ;Cascade (used internally by the two PICs. never raised)
    dq 0x0
DESC_INTERR35 equ $-IDT32 ;COM2 (if enabled)
    dq 0x0
DESC_INTERR36 equ $-IDT32 ;COM1 (if enabled)
    dq 0x0
DESC_INTERR37 equ $-IDT32 ;LPT2 (if enabled)
    dq 0x0
DESC_INTERR38 equ $-IDT32 ;Floppy Disk
    dq 0x0
DESC_INTERR39 equ $-IDT32 ;LPT1 / Unreliable "spurious" interrupt (usually)
    dq 0x0
    
;PIC ESCLAVO
DESC_INTERR40 equ $-IDT32 ;CMOS real-time-clock (if enabled)
    dq 0x0
DESC_INTERR41 equ $-IDT32 ;Free for peripherals / Legacy SCSI / NIC
    dq 0x0
DESC_INTERR42 equ $-IDT32 ;Free for peripherals / SCSI / NIC
    dq 0x0
DESC_INTERR43 equ $-IDT32 ;Free for peripherals / SCSI / NIC
    dq 0x0
DESC_INTERR44 equ $-IDT32 ;PS2 Mouse
    dq 0x0
DESC_INTERR45 equ $-IDT32 ;FPU / Coprocessor / Inter-processor
    dq 0x0
DESC_INTERR46 equ $-IDT32 ; Primary ATA hard disk
    dq 0x0
DESC_INTERR47 equ $-IDT32 ; Secondary ATA hard disk
    dq 0x0
    
LENGTH_IDT equ $-IDT32

my_idtr: dw LENGTH_IDT-1
         dd IDT32





;********************************************************************************
; 						-  -- --- Fin de archivo --- --  -
; D. Garcia 																c2013
;********************************************************************************

