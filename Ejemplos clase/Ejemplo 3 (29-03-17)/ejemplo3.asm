BITS 16
org 0x7C00 ;todos los saltos se realizan relativos a esta posicion!!!
;La bios me deja con CS:IP = 00:7C00!!

jmp $
jmp Inicio

GDT: ;comienza a definir la gdt

db 0,0,0,0,0,0,0,0 ; dejar vacio un descriptor

;DESCRIPTOR DE CODIGO FLAT (toda la memoria; segmento flat=ocupa TODA la memoria)
dw 0xFFFF; limite en uno
dw 0x0000; parte baja de la base en cero
db 0x00 ; base 16:23
db 10011000b; presente, DPL(x2), sist (codigo o datos), tipo (x4) 
db 11001111b; granularidad (limite en mult de 4 pag), D/B, L, 
db 0x00; base


;DESCRIPTOR IGUAL QUE EL ANTERIOR PERO DE DATOS
dw 0xFFFF; limite en uno
dw 0x0000; parte baja de la base en cero
db 0x00 ; base 16:23
db 10011010b; presente, DPL(x2), sist (codigo o datos), tipo (x4) 
db 11001111b; granularidad (limite en mult de 4 pag), D/B, L, 
db 0x00; base

valor_gdtr:     dw $-GDT; define el limite
                dd GDT; define la base

text: db "Hello World"; define 11 bytes"

Inicio:
lgdt [valor_gdtr]; carga el GDT

cli; apaga las interrupciones para que no entren 
mov eax,cr0; UNO DE LOS BITS DEL cr0 indica si esta o no EN MODO PROTEGIDO
or al,1; le hago una operacion OR al or 1 
mov cr0, eax; en cuanto hago esto el procesador ya empieza a trabajar en modo PROTEGIDO!, comenzara a usar la GDT
jmp 08:ModoProt; el 0x08 va al selector de codigo!, el de datos es el 0x10. VER LO CARGADO EN LA GDT!


ModoProt:
BITS 32; esto va ACA si o si, si lo pngo antes cagué!
mov ax,0x10
mov ds,as; cargo en ds el selector de datos

mov esi, 0x000b8000; como la base ya es cero!, por lo configurado en los descriptores, pongo el indice en b8000
mov cx,11
mov edi,text

lazo:
    mov al,[ds:edi]
    mov [ds:esi],al
    add esi,2
    inc edi
    loop lazo

hlt; pone al procesador en alta impedancia

times 510- ($-$$) db 0



