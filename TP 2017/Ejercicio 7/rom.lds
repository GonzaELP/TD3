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
		
		
        
           .sys_idt 0x00010000 :
		{ __sys_idt_start = . ; 
		*(.sys_idt);        /*Los datos no inicializados no tienen un lugar definido en LMA!! ya que no ocupan lugar en ROM*/
		__sys_idt_end = . ;}
        __sys_idt_size = SIZEOF(.sys_idt);
     
            
        .tablas_paginas 0x00020000 : 
                {__pag_tables_start = . ; 
                *(.pag_tables);
		__pag_tables_end = . ;}
        __pag_tables_size = SIZEOF(.tablas_paginas);
        
        
        
		
	.tables 0x00100000 : 
	  AT ( LOADADDR(.init) + SIZEOF(.init) )                           /*LMA de .init (es decir 0xFFFF0000) + "Lo que ocupe init" allí se                                           posicionará en LMA */
		{ __sys_tables_LMA = LOADADDR(.tables);                   /*__sys_tables_LMA tendra la direccion LMA de las tablas*/
		__sys_tables_start = .;                                   /*__sys_tables_start tendra el comienzo de las tablas en VMA*/
		*(.sys_tables*);                                          /*Incluye todas las secciones sys_tables*/
		__sys_tables_end = . ;}                                   /*Luego de incluirlas estaremos parados en la posicion final de las tablas en VMA*/
        __sys_tables_size = SIZEOF(.tables);
        __sys_tables_phy_addr = 0x00200000;
   
		
        .stack 0x00160000 :
		{ __stack_start = . ; 
		*(.stack);        /*Los datos no inicializados no tienen un lugar definido en LMA!! ya que no ocupan lugar en ROM*/
		__stack_end = . ;} 
	__stack_size = SIZEOF(.stack);	
	__stack_phy_addr = 0x00260000;
        
        . = 0x00170000; 							/* location counter = VMA */
	__main_start = . ;							/* VMA del punto de entrada 1Mb */
	.main :										/* seccion de salida */
	  AT ( LOADADDR(.tables) + SIZEOF(.tables) )
		{ __main_LMA = LOADADDR(.main);			/* LMA del codigo de 32 */
		*(.main);                                     /*Incluye todas las secciones MAIN*/
		 __main_end = . ; }                        /*Luego de incluir todo es el "__main_end" en VMA*/
	__main_size = SIZEOF(.main);
	__main_phy_addr = 0x00270000;
		
	.mdata 0x002A0000 : 	
	  AT ( LOADADDR(.main) + SIZEOF(.main) )
		{ __mdata_LMA = LOADADDR(.mdata);
		  __mdata_start = . ; *(.data);
		  __mdata_end = . ; }
        __mdata_size = SIZEOF(.mdata);
        __mdata_phy_addr = 0x003A0000;
		  
		  
        __datos_no_iniciali_inicio = .;
	 .bss 0x002B0000 :
		{ __bss_start = . ; 
		*(.bss);        /*Los datos no inicializados no tienen un lugar definido en LMA!! ya que no ocupan lugar en ROM*/
		*(.dat_no_inic*);
		__bss_end = . ;}
        __bss_size = SIZEOF(.bss);
	__bss_phy_addr = 0x003B0000;	  
		  
        . = 0x002D0000; 							/* location counter = VMA */
	__func_start = . ;							/* VMA del punto de entrada 1Mb */
	.func :										/* seccion de salida */
	  AT ( LOADADDR(.mdata) + SIZEOF(.mdata) )
		{ __func_LMA = LOADADDR(.func);			/* LMA del codigo de 32 */
		*(.func);                                     /*Incluye todas las secciones MAIN*/
		 __func_end = . ; }                        /*Luego de incluir todo es el "__main_end" en VMA*/
	__func_size = SIZEOF(.func);	
	__func_phy_addr = 0x003D0000;	
	 
     
  

}