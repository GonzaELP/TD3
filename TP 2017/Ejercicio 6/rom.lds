SECTIONS
{
	. = 0xFFFFFFF0; 							/* location counter = VMA */
	.reset_vector : 							/* Reset vector (seccion de salida) */ 
	  AT ( 0xFFFFFFF0 )							/* LMA al origen del binario */
		{ *(.reset_vector);
		__reset_vector = . ; }                       /*Todas las secciones de entrada comenzadas con .reset_vector*/

	. = 0xFFFF0000; 							/* location counter = VMA */
	.init :										/* seccion de salida */
	  AT ( 0xFFFF0000 )							/* Desplazo para alinear a 0x100 el offset de init16.asm */
		{ *(.init); }
		
	.tables 0x00008000 : 
	  AT ( LOADADDR(.init) + SIZEOF(.init) )                           /*LMA de .init (es decir 0xFFFF0000) + "Lo que ocupe init" allí se                                           posicionará en LMA */
		{ __sys_tables_LMA = LOADADDR(.tables);                   /*__sys_tables_LMA tendra la direccion LMA de las tablas*/
		__sys_tables_start = .;                                   /*__sys_tables_start tendra el comienzo de las tablas en VMA*/
		*(.sys_tables*);                                          /*Incluye todas las secciones sys_tables*/
		__sys_tables_end = . ;}                                   /*Luego de incluirlas estaremos parados en la posicion final de las tablas en VMA*/
		
        .stack 0x00009000 :
		{ __stack_start = . ; 
		*(.stack);        /*Los datos no inicializados no tienen un lugar definido en LMA!! ya que no ocupan lugar en ROM*/
		__stack_end = . ;} 
		
        
        . = 0x0000A000; 							/* location counter = VMA */
	__main_start = . ;							/* VMA del punto de entrada 1Mb */
	.main :										/* seccion de salida */
	  AT ( LOADADDR(.tables) + SIZEOF(.tables) )
		{ __main_LMA = LOADADDR(.main);			/* LMA del codigo de 32 */
		*(.main);                                     /*Incluye todas las secciones MAIN*/
		 __main_end = . ; }                        /*Luego de incluir todo es el "__main_end" en VMA*/
		
		
	.mdata 0x0000B000 : 	
	  AT ( LOADADDR(.main) + SIZEOF(.main) )
		{ __mdata_LMA = LOADADDR(.mdata);
		  __mdata_start = . ; *(.data);
		  __mdata_end = . ; }		
		  
		  
        __datos_no_iniciali_inicio = .;
	 .bss 0x0000C000 :
		{ __bss_start = . ; 
		*(.bss);        /*Los datos no inicializados no tienen un lugar definido en LMA!! ya que no ocupan lugar en ROM*/
		*(.dat_no_inic*);
		__bss_end = . ;}
		  
		  
        . = 0x0000D000; 							/* location counter = VMA */
	__func_start = . ;							/* VMA del punto de entrada 1Mb */
	.func :										/* seccion de salida */
	  AT ( LOADADDR(.mdata) + SIZEOF(.mdata) )
		{ __func_LMA = LOADADDR(.func);			/* LMA del codigo de 32 */
		*(.func);                                     /*Incluye todas las secciones MAIN*/
		 __func_end = . ; }                        /*Luego de incluir todo es el "__main_end" en VMA*/
		
		
	 
        .sys_idt :
		{ __sys_idt_start = . ; 
		*(.sys_idt);        /*Los datos no inicializados no tienen un lugar definido en LMA!! ya que no ocupan lugar en ROM*/
		__sys_idt_end = . ;} 
     
            
        .tablas_paginas ALIGN(0x1000) : 
                {__pag_tables_start = . ; 
                *(.pag_tables);
		__pag_tables_end = . ;} 
  

}