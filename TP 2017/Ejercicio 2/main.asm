;################################################################################
;#	Título: Codigo principal de la aplicacion de 32 bits						#
;#																				#
;#	Versión:		1.0							Fecha: 	27/04/2015				#
;#	Autor: 			D. Garcia					Tab: 	4						#
;#	Compilación:	Usar Makefile												#
;#	Uso: 			-															#
;#	------------------------------------------------------------------------	#
;#	Descripción:																#
;#	------------------------------------------------------------------------	#
;#	Revisiones:																	#
;#		1.0 | 27/04/2015 | D.GARCIA | Inicial									#
;#	------------------------------------------------------------------------	#
;#	TODO:																		#
;#		-																		#
;################################################################################

;--------------------------------------------------------------------------------
; Macros
;--------------------------------------------------------------------------------
%define DEFAULT_ATTRIBUTES 0x07
%define VIDEO_BASE_ADDRESS 0xB8000


;--------------------------------------------------------------------------------
; Simbolos externos
;--------------------------------------------------------------------------------
GLOBAL		start32
GLOBAL          print
GLOBAL          clrscr

;********************************************************************************
; Datos
;********************************************************************************
SECTION 	.data	

atributos dd DEFAULT_ATTRIBUTES;
fila dd 0
columna dd 0
string_ptr db "Hola mundo"

USE32
;********************************************************************************
; Codigo principal
;********************************************************************************
SECTION  	.main 			progbits

start32:

;;CODIGO AGREGADO POR GONZALO

    mov ebp,esp; apunto ebp a esp

    call clrscr; limpio la pantalla
    
    ;pusheo de argumento de la funcion print
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push string_ptr 

    call print; imprimo el hola mundo

    pop eax
    pop eax
    pop eax
    pop eax

fin:
    nop
    jmp fin

;;CODIGO AGREGADO POR GONZALO
	
	

;FUNCIONES AGREGADAS
SECTION .text


;void print(char *string_ptr, char columna, char fila, char color)
;Recibe:
; EIP de regreso: EBP+4
; sting_ptr: EBP+8
; columna: EBP+12
; fila: EBP+16
; color: EBP+20
print:
    push ebp; guardo el base pointer original.
    mov ebp, esp; cargo el stack pointer en el base pointer.
    
    ;La pantalla es de 80x25, debo hacer fila*80+columna para obtener la posición.
    mov eax, 160; cargo en eax la la cantidad de caracteres por fila*2 ya que cada caracter ocupa 2 bytes
    mov ebx, [EBP+16]; cargo en ebx (EBP+16) en la cual quiero escribir y se lo guarda en edx:eax. (aquí estaría en la columna cero).
    mul ebx;
    add eax,[EBP+12]; le sumo la columna.
    add eax,[EBP+12]; le sumo la columna una segunda vez ya que cada caracter ocupa 2 bytes!!
    add eax, VIDEO_BASE_ADDRESS; le sumo la base de video. Con lo que me queda la dirección de memoria
    mov edi, eax ;cargo en el di la direccion inicial de memoria sobre la que debo escribir!. edi tendra la direccion donde debo empezar a escribir
    mov esi, [EBP+8];cargo en el si la direccion de donde comenzaré a sacar los caracteres. esi tendra la direccion donde tengo el primer caracter del texto
    
    
ciclo_print:
    mov al,byte[esi]
    mov byte[edi],al;copio el primer caracter del texto en la primera posicion de memoria
    mov al,byte[EBP+20]
    mov byte[edi+1],al;copio el color correspondiente en la segunda
    add edi,2 ;incremento la posicion del destino en 2
    add esi,1; incremento la posicion de la fuente en 1
    cmp byte[esi],0
    jne ciclo_print

fin_print:
    pop ebp; recupero el valor de ebp original
    ret
    

    
;void clrscr(void)
;Recibe: NADA 
clrscr:
    mov al, 0; caracter nulo
    mov ah, DEFAULT_ATTRIBUTES; atributos por defecto.
    mov edi, VIDEO_BASE_ADDRESS
    mov cx,25*80; cargo en cx el tamaño de la pantalla en "numero de caracteres"
    
ciclo_clear:
    mov word[edi], ax; copio el caracter en la memoria de video
    add edi,2; incremento dos posicicones ya que cada caracter ocupa 2!
    loop ciclo_clear

fin_clear:
    ret
	
;********************************************************************************
; 						-  -- --- Fin de archivo --- --  -
; D. Garcia 																c2013
;********************************************************************************
 
