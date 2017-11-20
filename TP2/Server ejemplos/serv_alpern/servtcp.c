#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <signal.h> //para manejo de señales
#include <sys/wait.h> //para wait y waitpid
#include <sys/stat.h> // para las funciones de archivos
#include <fcntl.h>

#define MAX_CONN 10 //Nro maximo de conexiones en espera

#define DEFAULT_PORT 8000


#define IMG_PATH "./img/utn.png"



int genMsg(char**,char*, char*, char*,int);
int genBadResourceMsg(char**);
int genBadMethodMsg(char**);
int genPageMsg(char**);
int genImgMsg(char**);

void HandlerSIGCHLD(int);


char httpGet[]="GET"; //Metodo GET. Para comprobar si me envia un metodo INVALIDO y dar error 400
//Posibles recursos "/" (root) o "/img/utn.png". Sino es alguno de estos dos, debo dar "bad resource"
char httpGetImg[]= "GET /img/utn.png HTTP/1.1";  
char httpGetRoot[]= "GET / HTTP/1.1"; 

char httpOk[]= "HTTP/1.1 200 Ok \n";	//Respuesta en caso de peticion valida
char httpBadMethod[]="HTTP/1.1 400 Bad method \n"; //Respuesta en caso de metodo erroneo
char httpBadResource[]= "HTTP/1.1 404 Bad resource \n"; //Respuesta en caso de recurso inexistente

char httpTextHeader[]= "Content-Type: text/html; charset=UTF-8\nContent-Length: "; //valido para error o texto normal
char httpImgHeader[]="Content-Type: image/png\nContent-Length: "; //valido para imagenes png

char htmlPage[]="<!DOCTYPE html>\
					<meta http-equiv=\"refresh\" content=\"1\">\
					<html>\
						<body>\
							<h1>My First Heading</h1>\
								<p>My first paragraph.</p>\
							<h2> \
								<div align=\"center\" style=\"padding: 10px\">\
									<img src=\"img/utn.png\" alt=\"logo\" width=\"900\" height=\"300\" border=\"3\">\
								</div>\
							<h2>\
						</body>\
					</html>";

char htmlBadResource[]="<!DOCTYPE html>\
								<html>\
									<body>\
										<h1>Error 404</h1>\
											<p>Bad Resource</p>\
									</body>\
								</html>";

char htmlBadMethod[]="<!DOCTYPE html>\
								<html>\
									<body>\
										<h1>Error 400</h1>\
											<p>Bad Method</p>\
									</body>\
								</html>";
	

/**********************************************************/
/* funcion MAIN                                           */
/* Orden Parametros: Puerto                               */
/*                                                        */
/**********************************************************/
int main(int argc, char *argv[])
{
  int sockClient, sockServer;
  int forkRetVal;
  struct sockaddr_in address;
  char entrada[255];
  char ipAddr[20];
  int Port;
  int numChilds=0;
  socklen_t addrlen;

  if (argc == 2)
  {
	  signal (SIGCHLD, HandlerSIGCHLD);
    //Se crea el socket
    sockServer = socket(AF_INET, SOCK_STREAM,0);
	
    if (sockServer != -1)
    {
      
	  // Informacion de significado de los campos de la estructura en:
	  //https://www.gta.ufrj.br/ensino/eel878/sockets/sockaddr_inman.html
	  
	  // Asigna el puerto indicado y una IP de la maquina
      address.sin_family = AF_INET;
      //address.sin_port = htons(atoi(argv[1])); 
      address.sin_port = htons(DEFAULT_PORT); //htons: converts the unsigned short integer hostshort from host byte order to network byte order
	  address.sin_addr.s_addr = htonl(INADDR_ANY);  //Se usa INADDR_ANY cuando no necesito bindear el socket a una IP especifica sino a CUALQUIERA

      // Conecta el socket a la direccion local
	  //prototipo del bind: int bind(int sockfd, struct sockaddr *my_addr, socklen_t addrlen);
	  //Bind asigna una direccion (especificada en la estructura my_addr) al socket pasado como parametro.
      if( bind(sockServer, (struct sockaddr*)&address, sizeof(address)) != -1)
      {
        printf("\n\aServidor ACTIVO escuchando en el puerto: %s\n",argv[1]);
        // Indicar que el socket encole hasta MAX_CONN pedidos
        // de conexion simultaneas.
        if (listen(sockServer, MAX_CONN) < 0) // quedo escuchando en el PORT especificado
        {
          perror("Error en listen");
          exit(1);
        }
        // Permite atender a multiples usuarios
        while (1)
        {
  
          // La funcion accept rellena la estructura address con informacion
          // del cliente y pone en addrlen la longitud de la estructura.
          // Aca se podria agregar codigo para rechazar clientes invalidos
          // cerrando s_aux. En este caso el cliente fallaria con un error
          // de "broken pipe" cuando quiera leer o escribir al socket.
          addrlen = sizeof(address);
          if ((sockClient = accept (sockServer, (struct sockaddr*) &address, &addrlen)) < 0)
          {
            perror("Error en accept");
            exit(1);
          }
		  
		  if((forkRetVal=fork()) < 0)
		  {
			  perror("Error en el fork al intentar captar conexiones");
			  exit(1);
		  }
		  
		  if(forkRetVal==0) //Estoy en el proceso HIJO!
		  {
			  printf("Hola estoy en el hijo...\n");
			  char buffRecv[1000];// buffer de rececpcion
			  char* msgOut;
			  int msgSize=0;
			  
			  recv(sockClient,buffRecv,1000,0);
			  
			  if(!strncmp(buffRecv,httpGet,strlen(httpGet))) //si se cumple recibió un GET
			  {
				  if(!strncmp(buffRecv,httpGetRoot,strlen(httpGetRoot))) //texto
				  {
					  msgSize=genPageMsg(&msgOut);
				  }
				  else if(!strncmp(buffRecv,httpGetImg,strlen(httpGetImg))) //imagen
				  {
					  msgSize=genImgMsg(&msgOut);
				  }
				  else //bad resource 
				  {
					  msgSize=genBadResourceMsg(&msgOut);
				  }
			  }
			  else //bad Method
			  {
				  msgSize=genBadMethodMsg(&msgOut);
			  }
			  
			  if(send(sockClient,msgOut,msgSize,0) == -1)
			  {
				  perror("Error al enviar mensaje");
				  exit(1);
			  }
			  
			  free(msgOut);
			  close(sockClient);
			  exit(1);
		  }
		  
		  strcpy(ipAddr, inet_ntoa(address.sin_addr));
          Port = ntohs(address.sin_port);
		  
		  printf("Se creo un proceso hijo con pid: %d para atender al cliente para atender la conexion de la IP %s en el puerto %d \n",forkRetVal,ipAddr,Port);
			  
          // Cierra la conexion con el cliente actual
          close(sockClient);		  
        }
        // Cierra el servidor
        close(sockServer);
      }
      else
      {
        printf("ERROR al nombrar el socket\n");
      }
    }
    else
    {
      printf("ERROR: El socket no se ha creado correctamente!\n");
    }
  }
  else
  {
    printf("\n\nLinea de comandos: servtcp Puerto\n\n");
  }
  return 0;
}


int genBadResourceMsg(char** pMsg)
{return genMsg(pMsg,httpBadResource,httpTextHeader,htmlBadResource,0);}

int genBadMethodMsg(char** pMsg)
{return genMsg(pMsg,httpBadMethod,httpTextHeader,htmlBadMethod,0);}

int genPageMsg(char** pMsg)
{return genMsg(pMsg,httpOk,httpTextHeader,htmlPage,0);}


int genImgMsg(char** pMsg)
{
	int fd;
	struct stat buffer;
	long filelength;
	char* buff;
	char* pret=NULL;
	int bytes_leidos=0;
	int tot_size;
	
	/*Intento abrir el archivo*/
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
	
	//buff[filelength]='\0'; //agrego el caracter nulo para poder ver el tamaño con strlen()
	close(fd);
	
	tot_size=genMsg(pMsg,httpOk,httpImgHeader,buff,filelength);
	free(buff);
	
	return tot_size; 
}



int genMsg(char** pDest, char* method, char* header, char* html,int imgLen)
{
	char* len;
	char* stot;
	char twoNewLine[]="\n\n";
	
	int size_overhead;
	int size_html;
	int tot_size;
	int aux=0;
	int digits =0;
	int i=0;
	
	/*Calculo del tamaño del HTML. Sea texto o imagen*/
	if(imgLen==0) //es TEXTO!!
	{size_html=strlen(html);} //tamaño del HTML
	else //es una IMAGEN
	{size_html=imgLen;}
	
	/*si ESTOY RECIBIENDO UNA IMAGEN, VIENE con el caracter nulo, pero debo borrarlo
	 por tal motivo, el size será de uno menos 
	if(options==GEN_IMG) 
	{size_html--;}*/

	aux=size_html; //variable auxiliar para calcular la cantidad de digitos del tamaño del html
	
	/*Calculo la cantidad de digitos que tiene el length*/
	if(aux==0) //si el tamaño es 0, al menos hay 1 digito.
	{digits=1;}
	
	while(aux != 0) //ejemplo: 99 / 10 = 9; 9/10 = 0; -> 2 digitos
	{
		aux/=10;
		digits++;
	}
	
	len=(char*) malloc(digits+1); //reservo lugares para el size 1 byte por digito y 1 para el null char
	sprintf(len,"%d",size_html); //paso a string el tamaño del html
	
	//Calculo del tamaño TOTAL de la cadena a enviar
	size_overhead = strlen(method)+strlen(header)+strlen(len)+strlen(twoNewLine); //tamaño del "overhead" incluye el metodo HTTP, el header con el Length y los dos saltos de linea
	tot_size=size_overhead+size_html; //tamaño TOTAL de lo que se enviara
	
	printf("El total es... %d\n",tot_size);
	
	//Pido memoria para la cadena total
	stot =(char*) malloc(tot_size+1); //+1 para el null
	
	strcat(stot,method);
	strcat(stot,header);
	strcat(stot,len);
	strcat(stot,twoNewLine);
	
	if(imgLen==0) //si es TEXTO, simplemente concatena la cadena HTML
	{strcat(stot,html);}
	
	else //si es una imagen.... debe agregarla, pero NO sirve strcat ya que el archivo puede tener caracteres '\0'
	{
		for(i=0; i<size_html;i++) 
		{stot[size_overhead+i]=html[i];}
		stot[tot_size]=' ';
	}
	
	//Si es una imagen, le saco el nullchar del final!!
	//if(options=GEN_IMG)
	//{stot[tot_size]=' ';}
	
	free(len);  //libero el puntero interno len.	
	*pDest=stot; //devuelvo el puntero al string armado. RECORDAR LIBERARLO EN LA APLICACION
	
	return tot_size;
	
}

void HandlerSIGCHLD(int signum)
{
		pid_t pid;
		pid=wait(NULL);
		printf("El proceso de pid %d finalizo \n",pid);
}