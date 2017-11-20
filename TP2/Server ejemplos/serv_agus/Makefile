CC		= gcc
OBJS		= server_TCP.o

.PHONY : help
help:
	@echo	''
	@echo	'Uso:'
	@echo	'  make all:      Compila'
	@echo	'  make help:     Muestra estas opciones'
	@echo	'  make clean:    Elimina archivos auxiliares'
	@echo	''
	
.PHONY : all
all: 
	@echo	''
	@echo	'---> Compilando server_TCP.c'
	gcc server_TCP.c -o server

.PHONY : clean
clean:
	@echo	''
	@echo	'---> Limpieza de archivos'
	rm -f *.*~ *~ *.o server
	