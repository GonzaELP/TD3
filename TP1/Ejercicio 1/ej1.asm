%define DEFAULT_ATTRIBUTES 0x07
%define VIDEO_BASE_ADDRESS 0xB8000


ORG 0x8000
BITS 16

xchg bx,bx; pongo un magic breakpoint aquí

jmp Inicio

atributos dd DEFAULT_ATTRIBUTES;
fila dd 0
columna dd 0
string_ptr db "Hola mundo"


GDT:
    times 8 db 0 ; define 8 bytes sin nada para la entrada de la tabla
    
    SEL_CODIGO equ $-GDT ;esta cuenta daria 8, indicando el indice 1 de la tabla (TI=0 es decir GDT y RPL=00 es decir el privilegio maximo)
    
    ;DESCRIPTOR DE SEGMENTO DE CODIGO
    db 0xFF; bits 7:0 del limite
    db 0xFF; bis 15:8 del limite
    db 0x00; bits 7:0 de la Base Address
    db 0x00; bits 15:7 de la Base Address
    db 0x00; bits 23:16 de la Base Address
    db 10011000b;(Presente (x1) , Privilegio 0 (x2), Seg Datos o Codigo (S=1) (x1), De codigo (x1), Solo ejecucion,no conforme y no accedido (x3)
    db 11001111b; Granularidad 4k (x1), Default 32bits (x1), Fijos (x2), bits 19:16 limite (x4)
    db 0x00; bits 31:24 de la Base Address

    SEL_DATOS equ $-GDT ;esta cuenta daria 16, indicando el indice 2 de la tabla (TI=0 es decir GDT y RPL=00 es decir el privilegio maximo)
    
    ;DESCRIPTOR DEL SEGMENTO DE DATOS
    db 0xFF; bits 7:0 del limite
    db 0xFF; bis 15:8 del limite
    db 0x00; bits 7:0 de la Base Address
    db 0x00; bits 15:7 de la Base Address
    db 0x00; bits 23:16 de la Base Address
    db 10010010b;(Presente (x1) , Privilegio 0 (x2), Seg Datos o Codigo (S=1) (x1), De datos (x1), De lectura/escritura, epansion hacia arriba, no accedido (x3)
    db 11001111b;Granularidad 4k (x1), Default 32bits (x1), Fijos (x2), bits 19:16 limite (x4)
    db 0x00; bits 31:24 de la Base Address
    
    
valor_gdtr: dw $-GDT; limite de la GDT, estos dos bytes van primero
            dd GDT; base de la gdt estos dos van despues

Inicio:
    lgdt [valor_gdtr]; cargo el registro con la GDT.
    cli; apago las interrupciones para que no entren durante el pasaje a modo protegido
    mov eax,cr0; cargo eax con cr0
    or  al,1; pongo en 1 el bit de modo protegido
    mov cr0,eax; lo bajo ya seteado a cr0
    jmp SEL_CODIGO:Modo_Prot; Esta instruccion se ejecuta en 16 bits!.
    
Modo_Prot:
    BITS 32; Paso a 32 bits.
    mov ax,SEL_DATOS;
  
    ;Cargo DS, SS y ES con el selector de datos, todos estos son segmentos de datos con permiso de lectura y escritura solapados en memoria!
    mov ds,ax;
    mov ss,ax;
    mov es,ax;
    
    mov eax,base_pila;
    mov ebp,eax; apunto tanto esp 
    mov esp,eax; como ebp a la base de la pila

    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push string_ptr 

    call print

    pop eax
    pop eax
    pop eax
    pop eax

    hlt

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
    
     
times 509-($-$$) db 0;

base_pila: db 0; defino la base de la pila casi al final del bootloader, en las direcciones más bajas

db 0x55
db 0xAA


    