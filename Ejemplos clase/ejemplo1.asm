
xchg bx,bx; el bochs usa esto como magic breakpoint (no hace nada!)

JMP INICIO



columnaEsquiador db 40 ; db define una variable BYTE inicializada (en este caso en  40, la mitad de la pantalla)
metros dd 0; dd es para definir una variable double word (4 bytes)
semilla dd 0;
izq db 0; esto lo seteara o reseteara la interrupcion de teclado
der db 0;
ticks db 0; 

INICIO:
mov BX,0xB800
mov ES,BX ; Inicializa el extra segment para que apunte al buffer de video
mov DI,0 ; puntero destino
mov AX,0x0720 ; patron de cada caracter
mov CX,25*80 ; cantidad de copias 
cld ; Flag de direccion a CERO, direcciones ascendentes
rep stosw ; borra la pantalla

CICLO_PRINCIPAL:
mov SI,1*160; Linea 1
mov DI, 0*160; Linea 0
mov CX,24*80 ; rep movsw [ES:D1]<-[DS:S1] (esto hace estra instruccion)
push es ;no existe mov ds,es POR ESO LO PASO POR LA PILA
pop ds
rep movsw; rep opera solamente con instrucciones de cadena (movsw, stosw, etc). Opera con Cx, repite la instruccion mientras CX no sea cero y decrementa CX
mov cx,80
mov ax,0x0720
rep stosw
push cs
pop ds
mov eax, DWORD[metros]
mov edx,0; sino pongo esto se me cuelga 
mov ecx,100; carga ecx con 100
div ecx; el dividendo SIEMPRE tiene que estar en EDX EAX (bit mas y menos significativo). El cociente lo manda a eax y el resto lo manda a edx
inc eax; 
cmp eax,10
jb OK_ARBOLES
mov eax,10;  si eax es mayor que 10, lo pongo a 10


OK_ARBOLES:
	mov ecx,eax; aca vendrá si es menor que 10, y entonces cargará a ecx el eax.
	

CICLO_ARBOLES:
mov EAX,314159265
mul DWORD[semilla]
add EAX,123456789
mov [semilla],EAX
mov EDX,80
mul EDX
mov BYTE[es:24*160+EDX*2],"Y"; 160 bytes por linea
loop CICLO_ARBOLES
mov al,[COLUMNA_ESQUIADOR]
sub AL,BYTE[IZQ]
add AL,BYTE[DER]
movzx EAX,AL; extiendo el registro AL a EAX!
cmp BYTE[EAX*2],"Y"

ME_CUELGO: JE ME_CUELGO

mov [columnaEsquiador],AL
mov BYTE(EAX,*2),"H"

mov cx,4

ESPERA: 
		MOV AL,[ticks]
		
ESPERA2: mov AL,BYTE[ticks]
		JE ESPERA2
		LOOP ESPERA
		JMP CICLO_PRINCIPAL
	

INT_TIMER:
	pushad ; salva los registros de uso general, los flags LOS SALVA SOLO EL MCRO
	push ds; pusheo el data segment
	mov ax,cs ; la variable ticks esta definida en el codigo! para poder accederla, debo pasarla al data segment
	mov ds,ax; EL REGISTRO DE SEGMENTO POR DEFAULT ES EL DATA SEGMENT!!!! IMPORTANTISIMO
	pop ds
	popad
	ret

INT_TECLADO:
	pushad
	push ds
	mov ax,cs
	mov ds,ax
	in AL, 0x60; esta instruccion me permite acceder al teclado IN lee 0x60 (teclado) y lo carga en AL
	cmp AL,1 ; el 1 es ESCAPE, comparo inicialmente contra 1 
	jne NO_APRETE_ESC
	mov byte[izq],1
	jmp me_voy

NO_APRETE_ESC:
	cmp al,0x81
	jne NO_SOLTE_ESC
	mov byte[izq],0
	jmp me_voy

NO_SOLTE_ESC:
	cmp al,0x02
	jne no_aprete_f1
	mov byte[der],1
	jmp me_voy

NO_APRETE_F1:
	cmp al,0x82
	jmp me_voy
	mov byte[der],0
me_voy:
	mov al,0x20 ;me sirve para impedir la reentrancia en la interrupcion
	out 0x20,al
	pop ds
	popad
	iret

CAPTURAR_INTERR:
	mov AX,0
	mov ds,ax
	mov WORD[0x08*4],INT_TIMER
	mov WORD[0x08*4+2],cs
	mov WORD[0x09*4],INT_TECLADO
	mov WORD[0x09*4],cs
	mov AL, 0xFC; mascara de interrupciones 1111 1100
	OUT 0x21,AL ; habilito en el pic la mascara de interrupciones. En el 0x21 esta el PIC! asi que lo cargo con esto. 
	STI; setea el flag de que habilita las interrupciones



