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


;Inicializacion de la pila.
    mov ax,SEL_DATOS
    mov ss,ax
    mov esp,STACK_ADDRESS+STACK_SIZE ;(direccion fisica de la pila + tamaño, ojo no pisar otras secciones!!)

;Inicializacion de los PICs
    mov bx, 0x2028 ; Base de los pics, similar a un paso de parametros por registro.
    call InitPIC; llamada a la rutina de inicializacion de los PICS


;Salto al main
    mov eax,start32 ;coloco en eax el offset del start
    push dword SEL_CODIGO ; Pusheo primero el selector de codigo
    push eax ;luego el offset
    retf ;si hago un return far saltare a SEL_CODIGO:start32 que es en el archivo "main"

;;CODIGO AGREGADO POR GONZALO
    
    
    
    
    
    
    
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
;;No uso interrupciones en este caso así que no defino una IDT
;********************************************************************************
; 						-  -- --- Fin de archivo --- --  -
; D. Garcia 																c2013
;********************************************************************************
