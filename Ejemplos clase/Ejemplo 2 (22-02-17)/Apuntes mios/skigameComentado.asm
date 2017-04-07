BITS 16 


xchg bx,bx
jmp inicio ; salta a inicio porque sino tomaria las variables como codigo!!!

columnaEsquiador 	db 40
metros		 	dd 0
semilla			dd 0
izq			db 0
der			db 0
ticks			db 0

inicio:
      cli   ;deshabilita el flag de interrupciones! asi no pueden entrar interrupciones aquí
      jmp capturar_interr ;salta captura de interrupciones

fin_inicio:
      mov bx,0xb800     	;(carga el inicio del buffer de video en bx)
      mov es,bx        		;(carga el selector del extra segment 0xb000*0x10 = 0xb8000) Base destino que usa rep stosw
      mov di,0          	;Indice destino que usa rep stosw
      mov ax,0x0720     	;Patron de cada caracter RECORDAR QUE INTEL ES LITTLE ENDIAN!!! es decir, primero guarda la parte menos significativa (ATRIBUTOS) y luego el ASCII del caracter en cuestión! En ese caso de eligen los atributos 0000 0111 (Blink= 0 RGB_background=000 (Negro) Brillo=0  RGB_frente = 111 (blanco))
      mov cx,80*25      	;Tamaño de la pantalla
      cld 			;Flag de direccion a CERO, direcciones ascendentes.
      rep stosw			
      ;(stosw: guarda la WORD en [ES:DI]<-AX, si la antecedo con el prefijo rep lo que hace es [ES:(DI+2)]<-AX, es decir incrementa en 2 el indice  
      ;a cada repetición (en 2 por que se trata de stosW (word) si fuera stosB (Byte) el indice se incrementaria en 1, y si fuera stosD (Double Word) el indice se 
      ;e incrementaria en 4.  Se repite decrementando CX hasta que CX sea cero) Borra la pantalla

ciclo_principal:

;----------------------------------------------------------------------------------------------------------------------------------------
        ;MUEVO UNA LINEA HACIA ARRIBA
      mov si,160*1		;Linea 1, coloco 160 en fuente indice de memoria de la linea 2
      mov di,160*0		;Linea 0, coloco cero en destino, indice de memoria de la linea 1
      mov cx, 24*80
      push es                   ;Como movsw usa los registros DS, debo cargar la base de video en estos registros, NO SE PUEDE HACER MOV DS,ES!!
      
      pop ds			;Apunto DS a la base de video (0xb800)
      rep movsw 		;memcpy (Copia DS:DI <- DS:SI y luego si DF=0 (dir ascendentes) incrementa SI y DI; si DF=1 (dir 						                           descendentes) decrementa SI y DI). como DI=0 y SI=160 => Lo que hará será copiar la linea 2 a la 1, la 3 a la 2... y asi suscesivamente                         hasta la 25 a la 24). En definitiva lo que hace es desplazar toda la pantalla una linea hacia arriba.
;---------------------------------------------------------------------------------------------------------------------------------------------------
     
    ;PONGO EN BLANCO LA ULTIMA LINEA
     mov cx,80
      mov ax,0x0720
      rep stosw ; nuevamente, recordar que stosw lo que hace es que ES:DI<-AX. DI quedó en la última linea de la operación anterior!. 

      push cs; Pusheo el selector del Code segment a la pila
      pop ds ; cargo DS con CS!! ahora CS esta en el code segment!!! esto es para poder leer las variables???

      mov eax,dword[metros] ;carga eax con metros... lo que se divide es EDX EAX  de 64 bits! y en EXC está el divisor.
      mov edx,0 ; Cargo edx con 0
      mov ecx,100 ; Cargo ecx con 100
      
      div ecx			;Aca se hace la división. El resultado se guarda en EAX y el resto en EDX
      
      inc eax			;en EAX quedó cargado el número de metros/100, lo incrementa en 1 para que no sea 0 al principio
      cmp eax,10		;Maximo 10 arboles, fija como máximo 10 arboles... 
      jb Ok_Arboles             ;Jb, jump if below si eax < 10 entonces salta a Ok
      mov eax,10                ;sino, carga 10 en eax

Ok_Arboles: ;carga en ecx, eax para que el loop "ciclo arboles" se repita tantas veces como sean necesarias para generar una cantidad de arboles de 1 a 10
      mov ecx,eax
      
Ciclo_Arboles:
      mov eax, 314159265 ;uso un úmero "raro" para multiplicar a la semilla, en este caso se usa PI, esto me dará la aleatoriedad
      mul dword[semilla]; mul funciona así: uno de los multiplos es EAX y el otro es el que se pone en la instrucción. El resultado de 64bits se guarda en EDX EAX
      add eax, 123456789; se suma este numero "largo" a EAX 
      mov [semilla],eax; guarda en semilla el valor que quedó en eax.
      
      ;A partir de acá EAX queda cargado con un número determinado, que será pseudo aleatorio.
      
      
      mov edx,80 ; coloca 80 en edx
      mul edx; multiplica EAX por 80 y lo guarda en EDX EAX. ESTO SIEMPRE DARA COMO RESULTADO UN NUMERO TAL QUE EDX SIEMPRE SERA MENOR QUE 80!!!!!
      ;Ya que en el peor de los casos, si se hiciera 80 * 2^32, lo que quedaría es el 80 posicionado en EDX!!! es decir, se desplazaría 32 digitos binarios!.
      
      mov byte[es:24*160+edx*2],"Y" 
      ; es:24*160, notar que si o si debo ir al extra segment!! porque tengo el ds cargado con el selector del cs!!!!. 
      ; Con esta primera parte me posicionaría en la primera columna de la última fila, a esto le debo sumar un número aleatorio para poner siempre el arbol en posiciones
      ; diferentes, el numero aleatorio está en edx, y se lo multiplica por 2 ya que edx va de 0 a 79 de 1 en 1 y los saltos deben ser de 2 en 2 ya que los caracteres ocupan 2 bytes y no uno solo!!.
      ; Luego, en esa posición, coloco una "Y" que indicará la presencia de árboles.
      
loop Ciclo_Arboles ;repito el ciclo hasta agregar 1 a 10 arboles según corresponda.

      mov al,[columnaEsquiador] ;cargo en AL la columna en la que se encuentra actualmente el columnaEsquiador
      sub al,[izq] ;le resto una posición si presionaron para que se desplace a la izquierda
      add al,[der] ; le sumo una posición si presionaron para que se desplace a la derecha
      movzx eax,al ;  "Move with zero extend" hace EAX<-AL y rellena con ceros.
      cmp byte[es:eax*2],"Y" ; compara la posición actual del esquiador (que ha quedado en EAX) con "Y", es decir, si un arbol lo "pisó" ...
      
me_cuelgo: je me_cuelgo ; termina el juego, se queda loopeando aquí.

    ;caso contrario...
      mov [columnaEsquiador], al ; sino lo pisó, actualizo en memoria la posición del esquiador
      mov byte[es:eax*2], "H" ; escribo en la pantalla la "H" con la posición del esquiador
      mov cx,4 ;cargo CX con 4 para esperar 4 ticks...
      
espera:
      mov al,[ticks] ; carga "ticks" en AL
espera2:
      cmp al,[ticks] ; si ticks aun no se incremento,es porque no pasó un tick aún, me quedo esperando aquí hasta que pase...
      je espera2
loop espera ;si llega aquí, pasó al menos un tick, CX se decrementa y vuelve a espera... así hasta que pasen 4 ticks

      jmp ciclo_principal ;vuelve al ciclo principal

;************************************************************************
;INTERRUPCIONES
;************************************************************************    

int_timer:      
      pushad ;Pushea todos los registros de proposito general 
      push ds ; pushea el data segment
      ;es fuertemente conveniente pushear TODO lo que será alterado en el handler
      
      mov ax,cs ;carga ax con el CS 
      mov ds,ax ;carga ds con ax, en definitiva queda DS cargado con CS, esto me permite acceder a las variableS!!!
      inc byte[ticks]; incrementa la variable TICKS
      
      ;Nuevamente hay que referirse al link (http://www.brokenthorn.com/Resources/OSDevPic.html). En el puerto I/O 0x20 se escriben los comandos para el PIC.
      ;El comando 0x20 (0010 0000) lo que hace es setear el BIT5 (EOI, end of interrupt) para avisar que la atención a interrupción ha terminado y pueda entrar otra a ser atendida!
      mov al,0x20 
      out 0x20,al
      
      pop ds ;pop de ds
      popad ; pop de los registros de proposito general
      iret ; iret, siempre va esto al terminar una interrupcion! vuelve a donde habia dejado la ejecución!

int_teclado:
      pushad	
      push ds
      mov ax,cs
      mov ds,ax
      ;en estas primeras 4 lineas se hace exactamente lo mismo que en "int_timer"
      
      in al,0x60  ;lo que hace aca es leer la memoria I/O correspondiente al controlador de teclado 8042 (ver http://wiki.osdev.org/Can_I_have_a_list_of_IO_Ports)
      ;Como se puede ver en el enlace (http://wiki.osdev.org/%228042%22_PS/2_Controller), en el puerto 0x60 se lee el data port del teclado, es decir, que tecla se pulsó definida por su SCAN CODE (ver scan codes aqui http://wiki.osdev.org/PS/2_Keyboard)  
      
      cmp al,1 ; si se presiono ESC (Scan code = 0x01)
      jne no_aprete_esc ;sino se presiono, salta a no aprete esc;
      mov byte[izq],1 ; si efectivamente se presionó, coloca "1" en izq
      jmp me_voy; salta al final de la interrupcion
      
no_aprete_esc:
      cmp al, 0x81; aquí hace lo mismo si se soltó el escape, pone un 0 en en el desplazamiento a la izquierda 
      jne no_solte_esc ; si este no es el scancode, revisa el f1
      mov byte[izq],0 
no_solte_esc:
      cmp al,0x02 ; se fija si se presiono f1
      jne no_aprete_f1; sino se presiono, salta
      mov byte[der],1 ; si se presiono mueve a la derecha
      jmp me_voy ; y se va
no_aprete_f1:
      cmp al,0x82 ;si se solto, termina
      jne me_voy
      mov byte[der],0
me_voy:
;hace lo mismo que en la otra interrupcion para volver.
      mov al,0x20
      out 0x20,al
      pop ds
      popad
      iret


capturar_interr:
      mov ax,0 ;carga AX con cero
      mov ds,ax; carga el selector de datos con 0.
      
      ;Nota importante:La IVT (interrupt vector table) está situada en la posición 0x00:0x00, sus posiciones estan conformadas por 4 bytes. Como el vector tiene 256 posiciones 4B * 256B = 1024B = 1KByte.
      ;El primer KB de direcciones en modo real, está destinado a este propósito, contener el vector de interrupciones. 
     
     ;Los 4 bytes que conforman cada posición de la tabla, están definidos de la siguiente manera:
      ;Byte 0: Parte baja del offset del handler
      ;Byte 1: Parte alta del offset del handler
      ;Byte 2: Parte baja del selector de segmento de codigo (o en el segmento en el cual se encuentre alojada la subrrutina de atencion a interrupcion, en general CS)
      ;Byte 3: Parte alta del selector de segmento de codigo (o en el segmento en el cual se encuentre alojada la subrrutina de atencion a interrupcion, en general CS)
     
     ;Algunas de las interrupciones de HW gestionadas por el 8259 MASTER "pisan" por defecto a las del microprocesador (ver http://wiki.osdev.org/Interrupt_Vector_Table)
     ;Las interrupciones que usaremos son la del Timertick (cada 55ms), cuyo número de interrupcion es 0x08 y la del teclado cuyo numero es 0x09
      
      mov word[0x08*4],int_timer; carga el offset del handler para el timer. Notar que hace 0x08*4. Ya que cada entrada de la IVT tiene 4 bytes y por ende para llegar a la posición debe moverse 32 bytes. Luego, carga los dos primeros bytes (word) con el offset del handler, que está debidamente etiquetado como "int_timer" en el segmento de codigo.
      mov word[0x08 *4 +2],cs; carga el segmento del handler para el timer. Notar que suma suma 2, para ir a los superiores de la entrada en la tabla. Carga esa posición con el CS, que es el segmento donde justamente se encuentra la subrutina.
    
    ;repite los pasos anteriores pero para el teclado
      mov word[0x09*4], int_teclado
      mov word[0x09*4 + 2],cs
      
      
      mov al,0xFC ;1111 1100
      
      ;para entender lo que se realiza en esta linea hay que leer sobre el 8259 (ver IMR en http://www.brokenthorn.com/Resources/OSDevPic.html). 
      ;El registro interno IMR (interrupt mask register) del 8259 esta mapeado a la direccion I/O 0x021 del uP. Por lo tanto si escribo
      ;con OUT dicha dirección, lo que en realidad estaré haciendo es escribiendo el registro IMR del 8259.
      ;
      ;La función del IMR es que me permite enmascarar interrupciones (es decir, ignorarlas). Si un BIT está en 1, la interrupción se IGNORARA, si el BIT está en 0 se atenderá. Como se ve Bit0 = IRQ0 = Timer y bit 1= IRQ1 = Teclado están en 0, es decir se atenderán. Al tiempo que todo el resto de las interrupciones está en 1, es decir se ignorarán.;
      out 0x21,al ;escribo el IMR
      sti ;subo el flag de interrupciones del uP, quedan habilitadas las interrupciones
      
      jmp fin_inicio


times 510- ($-$$) db 0
db 0x55
db 0xAA

