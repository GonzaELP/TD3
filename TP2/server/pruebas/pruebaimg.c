#include <stdio.h> //Biblioteca standard input/output
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/wait.h>

#define IMG_PATH "./img/utn.png"

int main(void)
{
	int fd;
	struct stat buffer;
	long filelength;
	char* buff;
	int bytes_leidos=0;
	
	
	if((fd = open(IMG_PATH,O_RDONLY)) <0)
	{
		printf("El error al intentar abrir el archivo \n");
		exit(1);
	}
	fstat(fd,&buffer);	
	filelength=buffer.st_size;
	
	if((buff=(char*)malloc(filelength+1))==NULL)
	{
		printf("Fallo el MALLOC para la imagen \n");
		close(fd);
		exit(1);
	}
	
	if( (bytes_leidos=read(fd,buff,filelength)) < 0)
	{
		printf("Fallo al leer el archivo de imagen \n");
		close(fd);
		free(buff);
		exit(1);
	}
	close(fd);
	
}