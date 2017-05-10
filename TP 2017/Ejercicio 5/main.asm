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


;defines para el teclado
%define SC_MAKE_E 0x12
%define SC_MAKE_U 0x16
%define SC_MAKE_D 0x20
%define SC_MAKE_G 0x22
%define SC_MAKE_P 0x19

%define SC_BREAK_E (SC_MAKE_E+0x80)
%define SC_BREAK_U (SC_MAKE_U+0x80)
%define SC_BREAK_D (SC_MAKE_D+0x80)
%define SC_BREAK_G (SC_MAKE_G+0x80)
%define SC_BREAK_P (SC_MAKE_P+0x80)

%define DATA_PORT_PS2 0x60




;--------------------------------------------------------------------------------
; Simbolos externos
;--------------------------------------------------------------------------------
GLOBAL		start32
GLOBAL          print
GLOBAL          clrscr
GLOBAL          vect_handlers
GLOBAL          LENGTH_VECT_HANDLERS_EXCEP
GLOBAL          LENGTH_VECT_HANDLERS_INTERR

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

    

entero_itoa dd 0
buffer_itoa times 11 db 0x00;lo maximo que puede tener un entero de 32 bits es 10 cifras, y 1 mas para el fin de cadena

scan_code_actual db 0x0

sys_ticks dd 0x00

buffer_COM1 db 0x00,0x00 ;defino un buffer de un caracter!

atributos dd DEFAULT_ATTRIBUTES;
fila dd 0
columna dd 0
string_ptr db 0x00
db 0x0; fin de cadena

;Ubicacion en pantalla de los numeros
fila_cuenta dd 24
columna_cuenta dd 70

msg_inicio:
        db "Ingrese la opcion que desee: #DE=E, #UD=U, #DF=D, #GP=G, #PF=P",0

msg_excep0 db "Excepcion 0, division por cero",0 ;los ceros al final son para hacer el fin de linea!!

msg_excep6 db "Excepcion 6, codigo de operacion invalido",0 

msg_excep8 db "Excepcion 8, Doble falta ABORTAR",0

msg_excep13 db "Excepcion 13, fallo general de proteccion",0

msg_excep14 db "Excepcion 14, fallo de pagina",0



USE32
;********************************************************************************
; Codigo principal
;********************************************************************************
SECTION  	.main 			progbits

start32:
   
    espero_tecla: 
        in al,0x40
        cmp dword[sys_ticks],10; si sys
        jae imprimir_incremental; salto si sys_tics >= 10

        mov al, [scan_code_actual]
        cmp al,SC_BREAK_E
        je generar_DE
        cmp al,SC_BREAK_D
        je generar_DF
        cmp al,SC_BREAK_G
        je generar_GP
        cmp al,SC_BREAK_U
        je generar_UD
        cmp al,SC_BREAK_P
        je generar_PF
        
    
        cmp byte[buffer_COM1],0x00 ;si recibio algo
        jne imprimir_serie
        
        
    jmp espero_tecla
    
    
    imprimir_incremental:
    
    push buffer_itoa
    push dword[entero_itoa]
    
    call itoa
    
    add esp,8;add esp,8; bajo el esp los 2 push
    
    push dword[atributos]
    push dword[fila_cuenta]
    push dword[columna_cuenta]
    push buffer_itoa
    
    call print; 
    
    add esp,16; balo el esp los 4 push
    
    mov dword[sys_ticks],0x00; blanqueo el sys_ticks
    inc dword[entero_itoa]; incremento el itoa
    
    jmp espero_tecla
    
    
    imprimir_serie:
            
        push dword[atributos]
        push dword[fila]
        push dword[columna]
        push buffer_COM1; pusheo para imprimir el caracter!
        
        call print
        
        add esp,16; balo el esp los 4 push
    jmp espero_tecla
    
fin:
    nop
    jmp fin

;;CODIGO AGREGADO POR GONZALO
	
	

;FUNCIONES AGREGADAS
SECTION .func progbits

times 15 dd 0x00
;********************************************************************************
; FUNCION PRINT
;********************************************************************************
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
    

;********************************************************************************
; FUNCION CLRSCR
;********************************************************************************
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
; FUNCION ITOA (convierte ascii a entero)
;********************************************************************************
;char* itoa(int valor, char* string)
;Recibe: EIP de regreso (EBP+4)
;int valor (EBP+8)
;char* string (EBP+12)
itoa:
    push ebp; guardo el ebp original
    mov ebp,esp; me muevo por la pila con ebp
    
    mov eax, [ebp+8]; cargo en eax el valor entero
    
    xor edx,edx; pongo edx en cero
    mov ecx,10; pongo 10 en ecx, que es la cantidad maxima de cifras que puede tener un entero
    
    mov edi, [ebp+12]; coloco el puntero de la base de la cadena en el registro de destino
    
ciclo_itoa:
    mov ebx,10 ; cargo ebx con 10
    div ebx; eax/10
    add edx,48; en edx esta el resto, le sumo 48 para pasarlo a ascii
    mov ebx,edx; muevo el ascii a ebx
    mov [edi+ecx-1],bl; muevo el ascii al string caracter, empiezo desde la ultima cifra!
    xor edx,edx; limpio edx para que no afecte la proxima division
    dec ecx; decremento ecx en 1
    cmp eax,0; es cero?
    jne ciclo_itoa
    
inversion_itoa: ;debo invertir la cadena ya que con este algoritmo se carga en sentido inverso
    mov esi,edi; cargo destino con origen
    add esi,ecx; le sumo a la fuente ecx de esta forma me paro en el ultimo digito copiado!
    
    mov ebx,11
    sub ebx,ecx; (11-ecx, de esta forma conozco la cantidad de digitos a mover, para incluso mover el caracter nulo!)
    mov ecx,ebx; pongo esa cifra en ecx
    
    rep movsb; muevo 10-ecx bytes de si a di

fin_itoa:   
    pop ebp
    ret

;********************************************************************************
; RUTINAS PARA GENERAR EXCEPCIONES
;********************************************************************************
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
    jmp 0xF0000000 ; intento saltar a un lugar que no habilite en la paginacion...
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

handler_excep10: ;(con Codigo de error)
    pop edx; popeo el codigo de error
    iret

handler_excep11:
    pop edx; popeo el codigo de error
    iret

handler_excep12:
    pop edx; popeo el codigo de error
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
    pop edx; popeo el codigo de error
        
    call clrscr
    
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push msg_excep14
    
    call print; 
    hlt;
        
    iret
    
;Se saltea la 15, es reservada
handler_excep16:
    iret
    
handler_excep17:
    pop edx; popeo el codigo de error
    iret
    
handler_excep18:
    iret
    
handler_excep19:
    iret
    
handler_excep20:
    iret

;Se saltea 21-29, son reservadas

handler_excep30:
    pop edx; popeo el codigo de error
    iret
    
;Se saltea la 31, es reservada

;--------------------------------------------------------------------------------
; Handlers de interrupciones
;--------------------------------------------------------------------------------
handler_interr0: ;handler del timer    
    pushad
    pushfd
    
    inc dword[sys_ticks]
    
    mov al, 0x20
    out 0x20,al ; Marco el EOI
    
    popfd
    popad
    iret
    
    
handler_interr1: ;handler del teclado!  
    pushad; pusheo los registros de proposito general
    pushfd; pusheo los flags
    
    in al, DATA_PORT_PS2 ;leo el valor de la tecla
    mov [scan_code_actual],al ;guardo el scan_code en la variable correspondiente
    
    mov al, 0x20
    out 0x20,al ; Marco el EOI
    
    popfd
    popad
    
    iret
    
handler_interr2:
    iret
    
handler_interr3:
    iret
    
handler_interr4: ;Interrupcion de puerto serie (COM1)
    pushad; pusheo los registros de proposito general
    pushfd; pusheo los flags 
    
    mov dx, 0x3F8+2;esta es la direccion del IIR para el COM1
    in al,dx ;leo el valor del registro IIR (interrupt identifier register)
    mov bl,al; paso al a bl
    
    and bl,0x04; veo a ver si el flag de Interrupcion por recepcion esta encendido
    cmp bl,0
    jne handler_interr4_rx
    
    mov bl,al;cargo nuevamente el valor original del IIR en bl!
    and bl,0x02
    cmp bl,0
    jne handler_interr4_tx
    
    jmp handler_interr4_fin
    
    handler_interr4_rx:
    mov [buffer_COM1],al ;guardo lo recibido en la variable correspondiente
    jmp handler_interr4_fin
    
    handler_interr4_tx:    
    jmp handler_interr4_fin 
    
    handler_interr4_fin:
    mov al, 0x20
    out 0x20,al ; Marco el EOI
    
    popfd
    popad
    
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
 
