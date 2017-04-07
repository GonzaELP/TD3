;==============================================
;
;CL=Fila
;CH=Columna
;DL=Atributo
;DH=Caracter
;ES:SI=Puntero a Buffer de Video
;Atributo Rojo sobre Blanco para lineas pares
;Atributo Blanco sobre Rojo para lineas impares
;==============================================

ORG 8000h	; acá nos carga nuestro bootloader
BITS 16

	MOV AX,0xB800       ;Selector Buffer de Video
	MOV ES,AX
	MOV SI,0            ;Puntero a Buffer de Video
	MOV DH,"A"          ;Caracter inicial
	MOV CL,0            ;Fila inicial
	MOV DL,0x74         ;Atributo inicial

ciclo_fila:

	MOV CH,0            ;Columna inicial

ciclo_columna:

	MOV byte[ES:SI],DH  ;Escribir caracter
	MOV byte[ES:SI+1],DL;Escribir atributo

	ADD SI,2            ;Adelantar puntero a la posición
                        ;del caracter siguiente
	INC CH              ;Incrementa la columna

	CMP CH,80           ;Verifica extremo derecho de
                        ;la pantalla
    JC ciclo_columna

    INC DH              ;Siguiente caracter
    INC CL              ;Siguiente fila

    ROR DL,4            ;Cambia el atributo

    CMP CL,25           ;Compara extremo inferior
    JC ciclo_fila

    JMP $               ;Fin
