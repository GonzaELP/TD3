
#include <stdio.h> //Biblioteca standard input/output
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#define PATH_PAGE "./htmls/page.html"

char* genMsg(char* method, char* header, char* html)
{	
	char* len;
	char* stot;
	char twoNewLine[]="\n\n";
	
	int size_html;
	int tot_size;
	int aux=0;
	int digits =0;
	
	/*Calculo del tamaño del HTML*/
	size_html=strlen(html); //tamaño del HTML
	aux=size_html; //variable auxiliar para calcular la cantidad de digitos del tamaño del html
	
	if(aux==0) //si el tamaño es 0, al menos hay 1 digito.
	{digits=1;}
	
	while(aux != 0) //ejemplo: 99 / 10 = 9 ; 9/10 = 0; -> 2 digitos
	{
		aux/=10;
		digits++;
	}
	
	len=(char*) malloc(digits+1); //reservo lugares para el size 1 byte por digito y 1 para el null char
	sprintf(len,"%d",size_html); //paso a string el tamaño del html
	
	//Calculo del tamaño TOTAL de la cadena a enviar
	tot_size = strlen(method)+strlen(header)+strlen(len)+strlen(twoNewLine)+strlen(html);
	
	//Pido memoria para la cadena total
	stot =(char*) malloc(tot_size+1); //+1 para el null
	
	strcat(stot,method);
	strcat(stot,header);
	strcat(stot,len);
	strcat(stot,twoNewLine);
	strcat(stot,html);
	
	free(len);  //libero el puntero interno len.
	
	return stot; //devuelvo el puntero al string armado. RECORDAR LIBERARLO EN LA APLICACION
	
}

int main(int argc, char *argv[])
{
	char s1[]="Hola ";
	char s2[]="Mundo ";
	char s3[]="Longitud: ";
	char s4[]=" <Aqui ira codigo HTML>";
	char s5[]="\n\n";
	char* stot;
	
	stot=genMsg(s1,s2,s4);
	
	printf("%s \n", stot);
	
	free(stot);
	
	/*char* len;
	char* stot;
	
	int size_html;
	int aux=0;
	int digits =0;
	
	size_html=strlen(s4); //tamaño del HTML
	aux=size_html;
	
	if(aux==0) //si el tamaño es 0, al menos hay 1 digito.
	{digits=1;}
	
	while(aux != 0) //ejemplo: 99 / 10 = 9 ; 9/10 = 0; -> 2 digitos
	{
		aux/=10;
		digits++;
	}
	
	len=(char*) malloc(digits+1); //reservo lugares para el size 1 byte por digito y 1 para el null char
	sprintf(len,"%d",size_html); //paso a string el tamaño del html
	
	int tot_size;
	tot_size = strlen(s1) + strlen(s2)+ strlen(s3)+strlen(len)+strlen(s4)+strlen(s5);
	
	stot =(char*) malloc(tot_size+1); //+1 para el null
	
	strcat(stot,s1);
	strcat(stot,s2);
	strcat(stot,s3);
	strcat(stot,len);
	strcat(stot,s4);
	strcat(stot,s5);
	
	free(len);
	printf("%s",stot);
	
	free(stot);*/
	
}
