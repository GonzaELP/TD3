// Hecho por Dario Alpern
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int main(void)
{ 	char buff[50];
	unsigned int temp=0;


	int fd;
	if ((fd = open ("/dev/i2c_td3", O_RDWR))<0)
	{printf("No se pudo abrir el I2C :( \n");}
	else
	{printf("Se pudo abrir el puerto satisfactoriamente :), el puerto es %d",fd);}
   
	if(ioctl(fd,0x703,0x48)<0)		//Por datasheet la direccion es 100 1A2A1A0 es decir entre 0x48 y 0x4F
	{printf("No de pudo configurar la direccion del dispositivo esclavo \n");}	
	else
	{printf("Direccion de esclavo configurada de manera satisfactoria \n");}	
	
	temp=write(fd,buff,1);
	{printf("La temperatura leida es %d \n",temp);}
	return 0;	


}