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
GLOBAL          vect_handlers

EXTERN          IDT32

;********************************************************************************
; Datos
;********************************************************************************
SECTION 	.data    

vect_handlers:
;Handlers de excepciones
    dd handler_excep0
    dd handler_excep1
    dd handler_excep2
    dd handler_excep3
    dd handler_excep4
    dd handler_excep5
    dd handler_excep6
    dd handler_excep7
    dd handler_excep8
    dd handler_excep9
    dd handler_excep10
    dd handler_excep11
    dd handler_excep12
    dd handler_excep13
    dd handler_excep14
    dd 0x0 ;Se saltea la 15, es reservada
    dd handler_excep16
    dd handler_excep17
    dd handler_excep18
    dd handler_excep19
    dd handler_excep20
    times 9 dd 0x0;Se saltea 21-29, son reservadas
    dd handler_excep30
    dd 0x0;Se saltea la 31, es reservada

;Handlers de interrupciones
    dd handler_interr0
    dd handler_interr1
    dd handler_interr2
    dd handler_interr3
    dd handler_interr4
    dd handler_interr5
    dd handler_interr6
    dd handler_interr7
    dd handler_interr8
    dd handler_interr9
    dd handler_interr10
    dd handler_interr11
    dd handler_interr12
    dd handler_interr13
    dd handler_interr14
    dd handler_interr15
LENGTH_VECT_HANDLERS equ $-vect_handlers
    


atributos dd DEFAULT_ATTRIBUTES;
fila dd 0
columna dd 0

msg_excep0 db "Excepcion 0, division por cero"
db 0x0

msg_excep6 db "Excepcion 6, codigo de operacion invalido"
db 0x0

msg_excep8 db "Excepcion 8, Doble falta ABORTAR"
db 0x00

msg_excep13 db "Excepcion 13, fallo general de proteccion"
;db 0x00


USE32
;********************************************************************************
; Codigo principal
;********************************************************************************
SECTION  	.main 			progbits

start32:

;;CODIGO AGREGADO POR GONZALO

    mov ebp,esp; apunto ebp a esp

    call clrscr; limpio la pantalla
    
    call generar_GP
    
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
 

;--------------------------------------------------------------------------------
; Rutinas para generar excepciones
;--------------------------------------------------------------------------------
generar_DE: ;division por cero
    mov ebx, 0
    mov eax, 10
    div ebx
    ret

generar_UD:
    db 0xFF
    db 0xFF
    ret
    
generar_DF:
    mov word[IDT32+8*0+2],0x00 ;rompo el selector de codigo del descriptor de la excepcion cero!, lo mando al nulo
    mov ebx,0
    mov eax,10
    div ebx; genero excepcion cero, como encontrara el descriptor roto, hara doble falta
    ret
    
generar_GP:
    ;De esta manera genero un mensaje de error con el indice del descriptor en la GDT! (en este caso 1, ya que corresponde a la entrada 1)
    mov ax, 0x08
    mov es, ax; cargo el extra segment con el indice del segmento de codigo!
    mov [es:eax],eax ; intento escribir en el segmento de codigo!! 
    
    ;jmp 0x00:0x00 ; salto al selector nulo!!
    ret

generar_PF: ;hasta no ver paginacion no lo podemos hacer....
    ret


;--------------------------------------------------------------------------------
; Handlers de excepciones
;--------------------------------------------------------------------------------
handler_excep0:
    
    call clrscr
    
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push msg_excep0
    
    call print; 
    hlt;
    iret

handler_excep1:
    iret

handler_excep2:
    iret
    
handler_excep3:
    iret

handler_excep4:
    iret

handler_excep5:
    iret

handler_excep6: ;(invalid opcode)
    call clrscr
    
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push msg_excep6
    
    call print; 
    hlt;
    iret

handler_excep7:
    iret

handler_excep8: ;(double fault)
    pop edx; popeo el codigo de error
    
    call clrscr
    
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push msg_excep8
    
    call print; 
    hlt;
    iret

handler_excep9:
    iret

handler_excep10:
    iret

handler_excep11:
    iret

handler_excep12:
    iret

handler_excep13: ;(General protection fault)
   pop edx; popeo el codigo de error
    
    call clrscr
    
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push msg_excep13
    
    call print; 
    hlt;
    iret

handler_excep14:
    iret
    
;Se saltea la 15, es reservada
handler_excep16:
    iret
    
handler_excep17:
    iret
    
handler_excep18:
    iret
    
handler_excep19:
    iret
    
handler_excep20:
    iret

;Se saltea 21-29, son reservadas

handler_excep30:
    iret
    
;Se saltea la 31, es reservada

;--------------------------------------------------------------------------------
; Handlers de interrupciones
;--------------------------------------------------------------------------------
handler_interr0:
    iret
    
handler_interr1:
    iret
    
handler_interr2:
    iret
    
handler_interr3:
    iret
    
handler_interr4:
    iret
    
handler_interr5:
    iret

handler_interr6:
    iret
    
handler_interr7:
    iret
    
handler_interr8:
    iret
    
handler_interr9:
    iret
    
handler_interr10:
    iret
    
handler_interr11:
    iret
    
handler_interr12:
    iret
    
handler_interr13:
    iret
    
handler_interr14:
    iret
    
handler_interr15:
    iret
    
    
;********************************************************************************
; 						-  -- --- Fin de archivo --- --  -
; D. Garcia 																c2013
;********************************************************************************
 
