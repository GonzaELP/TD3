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
%define SC_MAKE_ESC 0x01

%define SC_BREAK_E (SC_MAKE_E+0x80)
%define SC_BREAK_U (SC_MAKE_U+0x80)
%define SC_BREAK_D (SC_MAKE_D+0x80)
%define SC_BREAK_G (SC_MAKE_G+0x80)
%define SC_BREAK_P (SC_MAKE_P+0x80)
%define SC_BREAK_ESC (SC_MAKE_ESC+0x80)

%define DATA_PORT_PS2 0x60


;Defines multitasking.
%define SC_MAKE_A
%define SC_MAKE_B
%define SC_MAKE_C

%define SC_BREAK_A
%define SC_BREAK_B
%define SC_BREAK_C

%define COUNT_T1_X
%define COUNT_T1_Y

%define COUNT_T2_X
%define COUNT_T2_Y

%define COUNT_T3_X
%define COUNT_T3_Y

;--------------------------------------------------------------------------------
; Simbolos externos
;--------------------------------------------------------------------------------
GLOBAL		start32
GLOBAL          print
GLOBAL          clrscr
GLOBAL          vect_handlers
GLOBAL          LENGTH_VECT_HANDLERS_EXCEP
GLOBAL          LENGTH_VECT_HANDLERS_INTERR

GLOBAL          kernel_idle
    
EXTERN          SEL_CODIGO

EXTERN          IDT32
EXTERN          PAGE_DIR_SO
EXTERN          PAGE_TABLES1_40_SO

EXTERN          PAGE_DIR_TASK1
EXTERN          PAGE_DIR_TASK2
EXTERN          PAGE_DIR_TASK3

EXTERN          __task1_stack_end 
EXTERN          __task2_stack_end 
EXTERN          __task3_stack_end 

EXTERN          task1_context
EXTERN          task2_context
EXTERN          task3_context


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

msg_ej6 db "Tecla ESC presionada",0

msg_excep0 db "Excepcion 0, division por cero",0 ;los ceros al final son para hacer el fin de linea!!

msg_excep6 db "Excepcion 6, codigo de operacion invalido",0 

msg_excep8 db "Excepcion 8, Doble falta ABORTAR",0

msg_excep13 db "Excepcion 13, fallo general de proteccion",0

msg_excep14 db "Excepcion 14, fallo de pagina",0

msg_task1 db "Tarea 1 ejecutandose",0
msg_task2 db "Tarea 2 ejecutandose",0
msg_task3 db "Tarea 3 ejecutandose",0

task_init:
    db 0x00
    db 0x00
    db 0x00
    
task_pds:
    dd PAGE_DIR_TASK1
    dd PAGE_DIR_TASK2
    dd PAGE_DIR_TASK3

task_stacks:
    dd __task1_stack_end
    dd __task2_stack_end
    dd __task3_stack_end
    
task_list:
    dd task1
    dd task2
    dd task3
    
task_contexts:
    dd task1_context
    dd task2_context
    dd task3_context




USE32
;********************************************************************************
; Codigo principal
;********************************************************************************
SECTION  	.main 			progbits

kernel_idle:
    hlt
    jmp kernel_idle

;;CODIGO AGREGADO POR GONZALO
	
;********************************************************************************
;CODIGO DE LAS TAREAS
;********************************************************************************	
SECTION .task1_code progbits
task1:
    push .buffer_itoa_t1
    push dword[.task1_count]
    call itoa
    add esp,8;add esp,8; bajo el esp los 2 push

    push dword[atributos]
    push 0x00
    push dword[columna]
    push .buffer_itoa_t1
    call print; 
    add esp,16; balo el esp los 4 push
    inc dword[.task1_count]
    nop
jmp task1

.task1_count dd 0x00
.buffer_itoa_t1 times 11 db 0x00

SECTION .task2_code progbits
task2:
    push .buffer_itoa_t2
    push dword[.task2_count]
    call itoa
    add esp,8;add esp,8; bajo el esp los 2 push
    
    push dword[atributos]
    push 0x01
    push dword[columna]
    push .buffer_itoa_t2
    call print; 
    add esp,16; balo el esp los 4 push
    inc dword[.task2_count]
    nop
jmp task2
.task2_count dd 0x00
.buffer_itoa_t2 times 11 db 0x00

SECTION .task3_code progbits
task3:
    push .buffer_itoa_t3
    push dword[.task3_count]
    call itoa
    add esp,8;add esp,8; bajo el esp los 2 push
    
    push dword[atributos]
    push 0x02
    push dword[columna]
    push .buffer_itoa_t3
    call print; 
    add esp,16; balo el esp los 4 push
    inc dword[.task3_count]
    nop
jmp task3

.task3_count dd 0x00
.buffer_itoa_t3 times 11 db 0x00

;FUNCIONES AGREGADAS
SECTION .func progbits
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
; RUTINA PARA GENERAR DIRECCIONES ALEATORIAS
;********************************************************************************
;Devuelve en eax una direccion de  32 bits generada de manera aleatoeria

gen_random_addr32:
    jmp .inicio_gen_addr
    .semilla: dd 0x00
    .inicio_gen_addr:
      mov eax, 314159265
      mul dword [.semilla]
      add eax, 123456789
      mov [.semilla],eax
      mov edx,0x10000000; quiero que el  maximo numero sea 0x1000000!!
      sub edx,0x00400000; le resto 0x400000 ya que NO quiero direcciones lineales de la primera. 
      mul edx; De esta manera generare un numero entre 0x00 y 0x0FC00000
      add edx, 0x00400000; pero lo que yo quiero es entre 0x00400000 y 0x10000000, entonces le sumo 0x00400000
      mov eax,edx; por abi 32 el retorno va en eax
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
;Escape presionado  
;--------------------------------------------------------------------------------    
esc_presionada:
  call clrscr
    
  push dword[atributos]
  push dword[fila]
  push dword[columna]
  push msg_ej6

  call print;
  add esp,16; bajo los 4 push
  hlt 
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
    ;Conservo en: eax = Direccion lineal (SOLO TEMPORALMENTE)
    ;             edx = direccion lineal desplazada 22 bits. Es decir entrada del directorio de paginas
    ;             ecx = Entrada de la tabla de paginas (bits 21 a 12)
    
    
    pop edx; popeo el codigo de error
    
    pushad
    
    jmp .alocar_pagina
    
    .msg_pise_rom db "Excepcion 14: Fallo de pagina, intento de acceso fuera de rango",0
    .msg_pise_mem_cableada db "Excepcion 14: Fallo de pagina, intento fallido de acceso a memoria mapeada",0
    .msg_pagina_alocada db "Excepcion 14: Fallo de pagina, Pagina no presente, se asigno una pagina nueva",0
    .msg_pagina_presente db "Excepcion 14: Pagina PRESENTE, se debe a otra cosa...",0
    
    
    jmp .alocar_pagina
    
    .phys_mem_actual dd  0x400000; las direcciones fisicas arrancan en 0x400000!
    
    .alocar_pagina:
    mov eax,cr2; en CR2 quedo la direccion lineal que causó el fallo de pagina
    mov edx,eax
    shr edx,22; si quiero saber a que entrada del DIRECTORIO pertenece, debo quedarme con los primeros 10 bits.
    mov ecx,eax;
    shr ecx,12; elimino los 12 bits menos significativos
    and ecx, 0x3FF; con esto elimino los 10 MSb, que corresponden al directorio y me quedo con la entrada de la TABLA
     
    cmp eax, 0x10000000 ;pongo un limite a las direcciones virtuales, para no pisar las tablas de paginas que estan con identity mapping. Si excede esto se va
    ja .fuera_de_rango
    
    cmp edx,0; si pertenece a la entrada 0...
    je .pise_mem_cableada
    
    ;consulto si la entrada del directorio esta presente
    test dword[PAGE_DIR_SO+edx*4], 0x01
    jz .tabla_no_presente
    jmp .cargar_tabla
 
    .tabla_no_presente:
    mov ebx,edx; cargo el indice dentro del directorio de paginas en ebx
    shl ebx,12; multiplico por 4096 para obtener la posicion de memoria dentro de las multiples tablas de paginas!!!
    lea ebx,[PAGE_TABLES1_40_SO-4096+ebx]; cargo en ebx la memoria fisica correspondiente a la posicion en la tabla.
    and ebx, 0xFFFFF000; por las dudas borro los 12LSb, ya que tiene que quedar multiplo de 4k en memoria fisica!!.
    or ebx,0x03; le seteo los atributos en Lectura/Escritura y Presente
    mov [PAGE_DIR_SO+edx*4],ebx; Cargo en la entrada del directorio que corresponda, la ubicacion fisica de la nueva tabla de paginas!.
    jmp .cargar_tabla
    
    .cargar_tabla:
    mov ebx,edx
    shl ebx,12
    test dword[PAGE_TABLES1_40_SO-4096+ebx],0x01; compruebo si el bit de presente la pagina esta encendido o no!!
    jnz .pagina_presente
    mov eax,[.phys_mem_actual]; la nueva pagina se coloca en las siguientes posiciones de memoria!!
    and eax,0xFFFFF000; limpio los 12LSb por las dudas, ya que la pagina debe estar en multiplo de 4k!!
    or eax,0x03 ; seteo el bit de presente y Lectura/Escritura
    lea ebx,[PAGE_TABLES1_40_SO-4096+ebx]
    mov [ebx+ecx*4], eax;cargo la entrada correspondiente de la tabla!!
    add dword[.phys_mem_actual],0x1000; Incremento la posicion de memoria fisica actual en 4k!!
    
    call clrscr
    
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push .msg_pagina_alocada
    
    call print; 
    add esp,16
    jmp .fin_ok
    
    .fuera_de_rango:
    
    call clrscr
    
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push .msg_pise_rom
    
    call print; 
    add esp,16
    jmp .fin_error
    
    .pise_mem_cableada:
    
    call clrscr
    
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push .msg_pise_mem_cableada
    
    call print;
    add esp,16
    jmp .fin_error
    
    .pagina_presente:
    
    call clrscr
    
    push dword[atributos]
    push dword[fila]
    push dword[columna]
    push .msg_pagina_presente
    
    call print;
    add esp,16
    jmp .fin_ok
    
    .fin_error:
    hlt;
    popad
    iret
    
    .fin_ok:
    popad
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
    cmp byte[task_init+0],0x00; la tarea 1 NO esta inicializada
    je .init_task
    cmp byte[task_init+1],0x00; la tarea 2 NO esta inicializada
    je .init_task
    cmp byte[task_init+2],0x00; la tarea 3 NO esta inizialidada
    je .init_task
    
    jmp .task_switch ;si ya quedaron todas las tareas inicializadas...
    
    .init_task:
    cmp dword[.task_actual], 0x00; si task_actual es 0, es porque es la primera vez que entra al handler!, entonces no debo salvar el contexto...
    je .load_task
    
    ;sino es la tarea 1... entonces debo salvar el contexto de la tarea de la cual provengo.
    push eax ; pusheo el valor de eax para resguardarlo
    mov eax,dword[.task_actual]
    mov eax,[task_contexts+eax*4-4]; en eax tengo ahora el puntero al contexto.
    ;En este orden se guardan: EAX,ECX,EDX,EBX,EBP,ESI,EDI,ES,DS,FS y GS
    pop dword[eax+4*0]; guardo el valor de eax en el contexto
    mov [eax+4*1],ecx
    mov [eax+4*2],edx
    mov [eax+4*3],ebx
    mov [eax+4*4],ebp
    mov [eax+4*5],esi
    mov [eax+4*6],edi
    mov [eax+4*7+2*0],es
    mov [eax+4*7+2*1],ss
    mov [eax+4*7+2*2],ds
    mov [eax+4*7+2*3],fs
    mov [eax+4*7+2*4],gs
    
   .load_task:
    pop ecx
    pop ecx
    pop ecx; aquí queda el EFLAGS
    
    mov eax,[.task_actual]
    xor edx,edx ;limpio edx
    mov ebx,0x03
    div ebx ; si eax es 0, el resto es cero, si eax es 1, el resto es 1, si eax es 2, el resto es 2, si eax es 3, el resto es 0 de vuelta y así suscesivamente.
    mov eax,edx;
    add eax,1; acá finalmente en eax dejo 1,2 o 3 (la tarea actual)
    mov [.task_actual],eax; actualizo el valor de task actual con eax.
    mov esp,[task_stacks+eax*4-4]; cambio la pila
    mov ebx,[task_pds+eax*4-4]; cargo en ebx el nuevo cr3
    mov cr3,ebx ; cambio el arbol de paginacion
    mov ebx, [task_list+eax*4-4]; cargo la posición de inicio de la tarea en cuestión en ebx
    mov [.task_actual], eax; la tarea actual corriendo es el valor situado en eax
    mov byte[task_init+eax-1],0x01 ; la tarea queda inicializada!
    
    sub esp,8
    mov [esp+8],ecx
    mov dword[esp+4], SEL_CODIGO
    mov [esp],ebx
    
    mov al, 0x20
    out 0x20,al ; Marco el EOI
    
    iret ; salto al inicio de la tarea
    
    .task_switch: ;aca va a empezar a entrar una vez que se hayan inicializado todas las tareas
    xchg bx,bx
    ;SALVO EL CONTEXTO DE LA TAREA QUE VENIA CORRIENDO
    push eax ; pusheo el valor de eax para resguardarlo
    mov eax,dword[.task_actual]
    mov eax,[task_contexts+eax*4-4]; en eax tengo ahora el puntero al contexto.
    ;En este orden se guardan: EAX,ECX,EDX,EBX,EBP,ESI,EDI,ES,DS,FS y GS
    pop dword[eax+4*0]; guardo el valor de eax en el contexto
    mov [eax+4*1],ecx
    mov [eax+4*2],edx
    mov [eax+4*3],ebx
    mov [eax+4*4],ebp
    mov [eax+4*5],esi
    mov [eax+4*6],edi
    mov [eax+4*7+2*0],es
    mov [eax+4*7+2*1],ss
    mov [eax+4*7+2*2],ds
    mov [eax+4*7+2*3],fs
    mov [eax+4*7+2*4],gs
    
    ;CAMBIO A LA NUEVA TAREA
    mov eax,[.task_actual]
    xor edx,edx ;limpio edx
    mov ebx, 0x03
    div ebx ; si eax es 0, el resto es cero, si eax es 1, el resto es 1, si eax es 2, el resto es 2, si eax es 3, el resto es 0 de vuelta y así suscesivamente.
    mov eax,edx;
    add eax,1; acá finalmente en eax dejo 1,2 o 3 (la tarea actual)
    mov [.task_actual],eax; actualizo el valor de task actual con eax.
    
    mov eax,[task_contexts+eax*4-4]; puntero al nuevo almacenamiento de contextos.
    
    mov ecx,[eax+4*1]
    mov edx,[eax+4*2]
    mov ebx,[eax+4*3]
    mov ebp,[eax+4*4]
    mov esi,[eax+4*5]
    mov edi,[eax+4*6]
    mov es,[eax+4*7]
    mov ss,[eax+4*7+2*1]
    mov ds,[eax+4*7+2*1]
    mov fs,[eax+4*7+2*2]
    mov gs,[eax+4*7+2*3]
    ;para este punto ya cargué la pila
    push dword[eax+4*0]; pusheo el valor del eax viejo!

    mov eax,[.task_actual]
    ;cargo el nuevo arbol de páginas
    mov eax,[task_pds+eax*4-4]
    mov cr3, eax
    
    mov al, 0x20
    out 0x20,al ; Marco el EOI
    
    pop eax; recupero el valor de eax!
    
    iret; hago el ret para volver a la ejecución de la tarea correspondiente
    
    .task_actual dd 0x00
    
handler_interr1: ;handler del teclado!
    pushad; pusheo los registros de proposito general
    
    in al, DATA_PORT_PS2 ;leo el valor de la tecla
    mov [scan_code_actual],al ;guardo el scan_code en la variable correspondiente
    
    mov al, 0x20
    out 0x20,al ; Marco el EOI
    
    popad
    
    iret
    
handler_interr2:
    iret
    
handler_interr3:
    iret
    
handler_interr4: ;Interrupcion de puerto serie (COM1)
    pushad; pusheo los registros de proposito general

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
 
