BITS 16 


xchg bx,bx
jmp inicio

columnaEsquiador 	db 40
metros		 	dd 0
semilla			dd 0
izq			db 0
der			db 0
ticks			db 0

inicio:
      cli      
      jmp capturar_interr
fin_inicio:
      mov bx,0xb800     	;
      mov es,bx        		;Base destino que usa rep stosw
      mov di,0          	;Indice destino que usa rep stosw
      mov ax,0x0720     	;Patron de cada caracter
      mov cx,80*25      	;Tamaño de la pantalla
      cld 			;Flag de direccion a CERO, direcciones ascendentes.
      rep stosw			;Borra la pantalla

ciclo_principal:
      mov si,160*1		;Linea 1
      mov di,160*0		;Linea 0
      mov cx, 24*80
      push es
      pop ds			;Apunto DS a la base de video (0xb800)
      rep movsw 		;memcpy
      mov cx,80
      mov ax,0x0720
      rep stosw
      push cs
      pop ds			;cargue DS con CS..
      mov eax,dword[metros]
      inc dword[metros]; agregado por mi, incremento en 1 metro por cada linea, sino no crece la cantidad de arboles!
      mov edx,0
      mov ecx,100
      div ecx			;Divido los metros por 100..
      inc eax			
      cmp eax,10		;Maximo 10 arboles
      jb Ok_Arboles
      mov eax,10

Ok_Arboles:
      mov ecx,eax
Ciclo_Arboles:
      mov eax, 314159265
      mul dword[semilla]
      add eax, 123456789
      mov [semilla],eax
      mov edx,80
      mul edx
      
      mov byte[es:24*160+edx*2],"Y"
      loop Ciclo_Arboles
      mov al,[columnaEsquiador]
      sub al,[izq]
      add al,[der]
      movzx eax,al
      cmp byte[es:eax*2],"Y"
me_cuelgo: je me_cuelgo
      mov [columnaEsquiador], al
      mov byte[es:eax*2], "H"
      mov cx,4
espera:
      mov al,[ticks]
espera2:
      cmp al,[ticks]
      je espera2
      loop espera
      jmp ciclo_principal

int_timer:      
      pushad
      push ds
      mov ax,cs
      mov ds,ax
      inc byte[ticks]
      mov al,0x20
      out 0x20,al
      pop ds
      popad	
      iret

int_teclado:
;      xchg bx,bx
      pushad	
      push ds
      mov ax,cs
      mov ds,ax
      in al,0x60      ;bit 7: Apreto (0) o levanto la tecla (1).. 
      cmp al,1
      jne no_aprete_esc
      mov byte[izq],1
      jmp me_voy
no_aprete_esc:
      cmp al, 0x81
      jne no_solte_esc
      mov byte[izq],0
      jmp me_voy
no_solte_esc:
      cmp al,0x02
      jne no_aprete_f1
      mov byte[der],1
      jmp me_voy
no_aprete_f1:
      cmp al,0x82
      jne me_voy
      mov byte[der],0
me_voy:
      mov al,0x20
      out 0x20,al
      pop ds
      popad
      iret

capturar_interr:
      mov ax,0
      mov ds,ax
      mov word[0x08*4],int_timer
      mov word[0x08 *4 +2],cs
      mov word[0x09*4], int_teclado
      mov word[0x09*4 + 2],cs
      mov al,0xFC
      out 0x21,al
      sti
      jmp fin_inicio


times 510- ($-$$) db 0
db 0x55
db 0xAA

