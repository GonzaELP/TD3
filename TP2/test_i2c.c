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
	{printf("Se pudo abrir el puerto satisfactoriamente :), el puerto es %d \n" ,fd);}
   
	if(ioctl(fd,0x703,0x48)<0)		//Por datasheet la direccion es 100 1A2A1A0 es decir entre 0x48 y 0x4F
	{printf("No de pudo configurar la direccion del dispositivo esclavo \n");}	
	else
	{printf("Direccion de esclavo configurada de manera satisfactoria \n");}	

	int i=0;

	for(i=0; i < 20; i++)
	{
		buff[0]=3;
		buff[1]=i;
		buff[2]=0x00;
		write(fd,buff,3);
		
		buff[0]=3;
		write(fd,buff,1);
		
		read(fd,buff,2);
	
		temp=(buff[0]<<8)+buff[1];
		{printf("El umbral de sobretemperatura es %x \n",temp);}
	}
	
	
	buff[0]=0;
	write(fd,buff,1);
	
	for(i=0; i< 5; i++)
	{
		read(fd,buff,2);
		temp= (buff[0] << 3)+(buff[1] >> 5);
		temp= temp/8;
		printf("La temperatura leida es %d \n",temp);
	}
	
	
	buff[0]=0;
	write(fd,buff,1);
	read(fd,buff,2);
	
	temp=(buff[0]<<8)+buff[1];
	{printf("La temperatura leida es %x \n",temp);}
	
	buff[0]=1;
	write(fd,buff,1);
	read(fd,buff,1);
	
	temp=buff[0];
	{printf("El registro de configuracion es %x \n",temp);}
	
	buff[0]=2;
	write(fd,buff,1);
	read(fd,buff,2);
	
	temp=(buff[0]<<8)+buff[1];
	{printf("La histeresis es %x \n",temp);}
	
	buff[0]=3;
	write(fd,buff,1);
	read(fd,buff,2);
	
	temp=(buff[0]<<8)+buff[1];
	{printf("El umbral de sobretemperatura es %x \n",temp);}
	

	return 0;	

}