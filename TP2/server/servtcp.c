/****************************************************************************************************
Autor: Gonzalo de Brito
Servidor WEB concurrente con acceso a sensor de temperatura I2C. 

******************************************************************************************************/

/****************************************************************************************************
INCLUDES
******************************************************************************************************/
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
#include <sys/ipc.h> // para poder usar el System V IPC
#include <sys/shm.h> //para poder usar shared memory
#include <sys/sem.h> //para poder utilizar semaforos

/****************************************************************************************************
DEFINES
******************************************************************************************************/
/*Numero maximo de conexion en espera*/
#define MAX_CONN 10

/*Tiempo que duerme el proceso de lectura de temperatura (en segundos)*/
#define T_GET_TEMP 1

/*Cantidad de lecturas de temperatura que se promedian para obtener la media*/
#define CANT_TEMPS_MEAN 5

/*Path de la imagen a enviar*/
#define IMG_PATH "./img/utn.png"

/*Path de un archivo generico para generar la llave de la shered memory y el semaforo*/
#define KEY_PATH "./key/arch.txt"

/*Path del driver de I2C*/
#define PATH_I2C "/dev/i2c_td3"

/*Flags para la creacion de la Shared Memory*/
#define SHM_FLG (0666 | IPC_CREAT)

/*Cantidad de semaforos a crear y flags para su creacion de los semaforos*/
#define CANT_SEMS 1
#define SEM_FLG (0666 | IPC_CREAT | IPC_EXCL)

/*Numeros que indican si el servidor esta encendido o apagado*/
#define RUNNING 1
#define NOT_RUNNING 0

/*Direccion del sensos LM75B en el bus I2C (es el valor que tiene con todos los pines de ADDR a GND*/
#define I2C_LM75_ADDR 0x48
/*Valor del comando de seteo de direccion de esclavo para el IOCTL del I2C*/
#define I2C_SLAVE_CMD 0x703

/****************************************************************************************************
DEFINICION DE TIPOS, ESTRUCTURAS y UNIONES
******************************************************************************************************/
/*Estructura de lectura de temperaturas que ira en Shared Memory para poder
ser accedida por todos los clientes*/
typedef struct temps
{
	float tempMax;
	float tempMin;
	float tempMean;
	float temps[5];
}Temps;

/*Definicion de la union semun, El MAN de SEMCTL pide que se defina esta union!*/
union semun {
               int              val;    /* Value for SETVAL */
               struct semid_ds *buf;    /* Buffer for IPC_STAT, IPC_SET */
               unsigned short  *array;  /* Array for GETALL, SETALL */
               struct seminfo  *__buf;  /* Buffer for IPC_INFO
                                           (Linux-specific) */
           };
		   

/****************************************************************************************************
DEFINICION DE LOS PROTOTIPOS DE LAS FUNCIONES UTILIZADAS
******************************************************************************************************/
/*Funcion que lee la temperatura del LM75
 Recibe: 1) File descriptor del device I2C
 Devuelve: valor de temperatura*/
float getTemp(int fd);

/*Funcion del proceso hijo de gestion de clientes.
 Recibe: 1) Socket para comunicarse con el cliente
		 2) SemID del semaforo que controla el acceso a la SharedMem
		 3) El SemBuf para poder tomar o liberar dicho semaforo con semop()
		 4) El puntero a la estructura Temps en Shared Memory
 Devuelve: void*/
void fClientsChild(int sockClient,int SemID, struct sembuf* SemBuf, Temps* ShMemTemps);

/*Funcion del proceso hijo de lectura de la temperatura.
 Recibe: 1) SemID del semaforo que controla el acceso a la SharedMem
		 2) El SemBuf para poder tomar o liberar dicho semaforo con semop()
		 3) El puntero a la estructura Temps en Shared Memory
 Devuelve: void*/
void fTempChild(int, struct sembuf*,Temps*);

/*Funcion que genera el mensaje completo HTTP+HTML a ser enviado al cliente!
 Recibe: 1) Puntero a la de destino donde se guardara el mensaje completo
		 2) Cadena que contiene el Metodo HTTP a responder
		 3) Cadena que contiene el Header HTTP.
		 4) Cadena que contiene el codigo HTML
		 5) Tamaño de la imagen en bytes. Si se coloca 0,se interpreta que el mensaje es de TEXTO.
 Devuelve: tamaño total de a cadena a enviar*/
int genMsg(char**,char*, char*, char*,int);

/*Funcion que genera el mensaje completo HTTP+HTML de bad resource a ser enviado al cliente
 Recibe: 1) Puntero a la de destino donde se guardara el mensaje completo. HACER FREE LUEGO DE USARLA!! PARA NO GENERAR LEAK
		 2) Cadena con el Header de Texto HTTP
 Devuelve: tamaño total de a cadena a enviar*/
int genBadResourceMsg(char**,char*);

/*Funcion que genera el mensaje completo HTTP+HTML de bad Method a ser enviado al cliente
 Recibe: 1) Puntero a la de destino donde se guardara el mensaje completo. HACER FREE LUEGO DE USARLA!! PARA NO GENERAR LEAK
		 2) Cadena con el Header de Texto HTTP
 Devuelve: tamaño total de a cadena a enviar*/
int genBadMethodMsg(char**,char*);

/*Funcion que genera el mensaje completo HTTP+HTML de la imagen a ser enviado al cliente
 Recibe: 1) Puntero a la de destino donde se guardara el mensaje completo. HACER FREE LUEGO DE USARLA!! PARA NO GENERAR LEAK
		 2) Cadena con el Mensaje de respuesta HTTP OK 200
 Devuelve: tamaño total de a cadena a enviar*/
int genImgMsg(char**,char*);

/*Funcion que genera el mensaje completo HTTP+HTML de la pagina principal a ser enviado al cliente
 Recibe: 1) Puntero a la de destino donde se guardara el mensaje completo
		 2) Cadena con el mensaje de respuesta HTTP OK 200
		 3) Cadena con el Header de Texto HTTP
		 4) SemID del semaforo que controla el acceso a la SharedMem
		 5) El SemBuf para poder tomar o liberar dicho semaforo con semop()
		 6) El puntero a la estructura Temps en Shared Memory
 Devuelve: tamaño total de a cadena a enviar*/
int genPageMsg(char**,char*,char*,int,struct sembuf*,Temps*);

/****************************************************************************************************
Definicion de los prototipos de los handler de señales
******************************************************************************************************/
void HandlerSIGCHLD(int); //para Matar a los procesos hijos
void HandlerSIGINT(int); //para finalizar la ejecucion del programa
void HandlerTempKill(int);//para finalizar la ejecucion del proceso HIJO que lee la temperatura

/****************************************************************************************************
VARIABLES GLOBALES
******************************************************************************************************/
/*Variables globales que indican si el server y el proceso que lee temperatura estan activos o no
 es global para poder alterarla desde el Handler de SIGINT para finalizar la ejecucion*/
int serverRunning;
int sockServer; //lo pongo como variable global para poder cesar la ejecucion del programa durante el Listen
int tempRunning;
					
/**********************************************************/
/* funcion MAIN                                           */
/* Orden Parametros: Puerto de conexion                   */
/*                                                        */
/**********************************************************/
int main(int argc, char *argv[])
{
  /*Variables para el control de los semaforos*/
  int SemID;
  key_t SemKey;
  union semun SemArg;
  struct sembuf SemBuf;
  SemBuf.sem_num=0; //numero de semaforo 0
  SemBuf.sem_op=-1; //arranca LOCKED 
  SemBuf.sem_flg=0;
  
  /*Variables para gestion de la Memoria compartida*/
  int ShMemID; 
  key_t ShMemKey;  
  Temps* ShMemTemps;
  
  /*Variables para la gestion de procesos hijos*/
  int forkRetVal; //variable para almacenar el retval de los fork()
  pid_t pidTempProc; //variable para contener el PID del proceso que lee la temperatura, para luego matarlo
  
  /*Variables para la gestion de los sockets y la conexion*/
  int sockClient;
  struct sockaddr_in address;
  char entrada[255];
  char ipAddr[20];
  int Port;
  socklen_t addrlen;
  
  /*Pregunto si recibió el puerto, sino ceso la ejecución y lo vuelvo a solicitar*/
  if (argc == 2)
  {
	 //Coloco la variable del servidor corriendo en ON. El handler de SIGINT la apaga. Para salir limpiando todo lo creado
	serverRunning=RUNNING; 
	
	/*Vinculo las señales con los handlers*/
	signal (SIGCHLD, HandlerSIGCHLD);
	signal (SIGINT, HandlerSIGINT);
	signal (SIGTERM, HandlerSIGINT); //copio el mismo handler para sigterm, por si me tiran "kill"
	  
	/*Creacion e Inicializacion de la SHARED MEMORY*/
	if(((ShMemKey=ftok(KEY_PATH,'A'))<0) | (serverRunning==NOT_RUNNING)) //creo la llave
	{
		perror("Error al crear la llave de la memoria compartida");
		exit(EXIT_FAILURE);
	}
	  
	if(((ShMemID=shmget(ShMemID,sizeof(Temps),SHM_FLG))<0) | (serverRunning==NOT_RUNNING)) //obtengo la region de Memoria compartidas 
	{
		perror("Error obtener el ID de la memoria compartida");
		exit(EXIT_FAILURE);
	}
	 
	if(((ShMemTemps=(Temps*)shmat(ShMemID,NULL,0)) < 0) | (serverRunning==NOT_RUNNING)) //adjunto la region de memoria compartida al proceso padre
	{
		/*En caso de error, deshago todo lo realizado hasta aqui*/
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida
		perror("Error al intentar attachear la memoria");
		exit(EXIT_FAILURE);
	}
	 
	/*Creacion e inicializacion del SEMAFORO*/
	if(((SemKey=ftok(KEY_PATH,'Z'))<0) | (serverRunning==NOT_RUNNING)) //creo la llave del semaforo
	{
		/*En caso de error, deshago todo lo realizado hasta aqui*/
		shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida
		perror("Error al crear la llave del semaforo");
		exit(EXIT_FAILURE);
	}
	 
	if(((SemID=semget(SemKey,CANT_SEMS,SEM_FLG)) < 0) | (serverRunning==NOT_RUNNING)) //Creo el semaforo
	{
		/*En caso de error, deshago todo lo realizado hasta aqui*/
		shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida
		perror("Error al intentar obtener el ID del semaforo");
		exit(EXIT_FAILURE);
	}
	 
	SemArg.val=1;
	if ((semctl(SemID, 0, SETVAL, SemArg) == -1)  | (serverRunning==NOT_RUNNING))//inicializo el semaforo
	{
		/*En caso de error, deshago todo lo realizado hasta aqui*/
		semctl(SemID,0,IPC_RMID); //elimino el semaforo
		shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida
		perror("Error al intentar configurar el semaforo");
        exit(EXIT_FAILURE);
	}
	 
	/*Creo el proceso hijo para lectura de la temperatura, Si FALLA, elimino el semaforo y la SharedMem*/
	if(((forkRetVal=fork()) < 0)  | (serverRunning==NOT_RUNNING))
	{
		/*En caso de error, deshago todo lo realizado hasta aqui*/
		semctl(SemID,0,IPC_RMID); //elimino el semaforo
		shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida 
		perror("Error al intentar attachear la memoria compartida");
		exit(EXIT_FAILURE);
	}
	if(forkRetVal==0) //proceso hijo de lectura de temperatura. No sale de aqui
	{
		tempRunning=RUNNING;
		fTempChild(SemID, &SemBuf,ShMemTemps); //acciones de obtencion de temperatura
		exit(EXIT_FAILURE); //jamas deberia llegar aqui
	}
	else //proceso padre
	{
		/*Guardo el pid del hijo que lee temperatura para liquidarlo al finalizar*/
		pidTempProc=forkRetVal; 
	}
	
	/*Creo el socket del SERVER*/
	if(((sockServer = socket(AF_INET, SOCK_STREAM,0)) < 0) | (serverRunning==NOT_RUNNING))
	{
		/*En caso de error, deshago todo lo realizado hasta aqui*/
		kill(pidTempProc,SIGKILL);
		semctl(SemID,0,IPC_RMID); //elimino el semaforo
		shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida
		perror("ERROR: El socket no se ha creado correctamente!\n");
		exit(EXIT_FAILURE);		  
	}
	 
	/*Asigna el puerto indicado y una IP de la maquina*/
    address.sin_family = AF_INET;
    address.sin_port = htons(atoi(argv[1])); //asigno el puerto recibido por linea de comandos
	address.sin_addr.s_addr = htonl(INADDR_ANY);  //Se usa INADDR_ANY cuando no necesito bindear el socket a una IP especifica sino a CUALQUIERA

    /* Conecto el socket a la direccion local*/
	if((bind(sockServer, (struct sockaddr*)&address, sizeof(address)) < 0) | (serverRunning==NOT_RUNNING))
    {
		/*En caso de error, deshago todo lo realizado hasta aqui*/
		perror("ERROR al nombrar el socket\n");
		close(sockServer);//cierro el socket, elimino su fd
		kill(pidTempProc,SIGKILL); //mato el proceso hijo de lectura de temperatura
		semctl(SemID,0,IPC_RMID); //elimino el semaforo
		shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida
		exit(EXIT_FAILURE);
	}
	
	printf("\n\aServidor ACTIVO escuchando en el puerto: %s\n",argv[1]);
    
	/*Escucho en el puerto especificado a la espera de conexiones entrantes*/
	if((listen(sockServer, MAX_CONN) < 0) | (serverRunning==NOT_RUNNING)) // quedo escuchando en el PORT especificado
    {
		/*En caso de error, deshago todo lo realizado hasta aqui*/
       perror("ERROR en listen");
	   close(sockServer);//cierro el socket, elimino su fd
	   kill(pidTempProc,SIGKILL); //mato el proceso hijo de lectura de temperatura
	   semctl(SemID,0,IPC_RMID); //elimino el semaforo
	   shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
	   shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida
       exit(EXIT_FAILURE);
    }
		
	while (serverRunning==RUNNING)
	{
	  addrlen = sizeof(address);
	  
	  /*Entro una conexión... la acepto!*/
	  if ((sockClient = accept (sockServer, (struct sockaddr*) &address, &addrlen)) < 0)
	  {
		/*En caso de error, deshago todo lo realizado hasta aqui*/
		perror("Error en accept");
		close(sockServer); //cierro el socket, elimino su fd
		semctl(SemID,0,IPC_RMID); //elimino el semaforo
		shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida 
		kill(pidTempProc, SIGKILL);
		exit(EXIT_FAILURE);
	  }
	  /*Si el accept no dió error... creo un hijo para atenderla*/
	  if((forkRetVal=fork()) < 0)
	  {
		/*En caso de error, deshago todo lo realizado hasta aqui*/
		perror("Error en el fork al intentar captar conexiones");
		close(sockClient); //cierro el socket delcliente
		close(sockServer); //cierro el socket, elimino su fd
		semctl(SemID,0,IPC_RMID); //elimino el semaforo
		shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida 
		kill(pidTempProc, SIGKILL);
		exit(EXIT_FAILURE);
	  }
	  
	  if(forkRetVal==0) //Estoy en el proceso HIJO de gestion de conexiones
	  {
		/*Dentro del hijo atiendo las tareas de la conexion*/
		fClientsChild(sockClient,SemID,&SemBuf,ShMemTemps);
		exit(EXIT_FAILURE); //nunca deberia llegar aquí 
	  }
	  
	  /*Informo por consola sobre la conexion entrante en el proceso padre*/
	  strcpy(ipAddr, inet_ntoa(address.sin_addr));
	  Port = ntohs(address.sin_port);
	  printf("Conexion recibida. Direccion de origen %s:%d\n",ipAddr,Port);
	  
	  // Cierra la conexion con el cliente actual, que ahora la maneja el hijo
	  close(sockClient);		  
	}
	
		// Cierra el servidor. Limpio todo lo creado
		close(sockClient); //cierro el socket delcliente
		close(sockServer); //cierro el socket, elimino su fd
		semctl(SemID,0,IPC_RMID); //elimino el semaforo
		shmdt(ShMemTemps); //Hago un Desattachment del proceso padre a la memoria compartido
		shmctl(ShMemID, IPC_RMID, 0); //Elimino la memoria compartida 
		kill(pidTempProc, SIGKILL);
		printf("Cierra el server\n");
		exit(EXIT_SUCCESS);
	}

	else
	{	
		//no se ingreso por linea de comandos el puerto, o bien se ingresaron mal los parametros
		printf("\n\n ERROR de parametros, colocar en la linea de comandos: servtcp Puerto\n\n");
	}	

  return 0;
}


/****************************************************************************************************
IMPLEMENTACION DE LA FUNCION PARA LEER TEMPERATURA DEL SENSOR LM75
******************************************************************************************************/
float getTemp(int fd)
{
	char buffer[2];
	float temp;
	if(read(fd,buffer,2)!=2) //no se leyeron los bytes que deberian haberse leido...
	{
		close(fd); //cierro el descriptor que maneja al I2C
		perror("Error al leer la temperatura");
		exit(EXIT_FAILURE);
	}
	
	
	temp= (float)((buffer[0] << 3)+(buffer[1] >> 5));
	temp=temp*0.125;
	return temp;
}

/****************************************************************************************************
IMPLEMENTACION DE LAS FUNCIONES EJECUTADAS POR LOS PROCESOS HIJOS
******************************************************************************************************/
void fClientsChild(int sockClient,int SemID, struct sembuf* SemBuf, Temps* ShMemTemps)
{
	char buffRecv[1000];// buffer de rececpcion
	char* msgOut;
	int msgSize=0;
	
	/*Metodo GET. Para comprobar si me envia un metodo INVALIDO y dar error 400*/
	char httpGet[]="GET"; 
	
	/*Posibles recursos "/" (root) o "/img/utn.png". Sino es alguno de estos dos, debo dar "bad resource"*/
	char httpGetImg[]= "GET /img/utn.png HTTP/1.1";  
	char httpGetRoot[]= "GET / HTTP/1.1"; 
	
	/*Respuesta en caso de peticion correcta. Se declara aqui y no en el interior de las funciones
	generadoras de mensajes, ya que puede ser utilizada tanto por la funcion generadora de la pagina principal
	como por la de la imagen*/
	char httpOk[]= "HTTP/1.1 200 Ok \n";	//Respuesta en caso de peticion valida
	
	/*Header HTTP para el caso de enviar texto. Se declara aqui y no en el interior de las funciones
	generadoras de mensajes, ya que puede se utilizada por la funcion generadora de la pagina principal
	como por las de errores. (todas son de texto)*/
	char httpTextHeader[]= "Content-Type: text/html; charset=UTF-8\nContent-Length: "; //valido para error o texto normal

	/*Recibo del cliente la cadena*/
	recv(sockClient,buffRecv,1000,0);
	
	/*La Imprimo para tener informacion sobre lo que mado*/
	printf("%s\n\n",buffRecv);

	/*Comparo con las cadenas permitidas (o no) y en funcion de ello genero el mensaje*/
	if(!strncmp(buffRecv,httpGet,strlen(httpGet))) //si se cumple recibió un GET
	{
	  if(!strncmp(buffRecv,httpGetRoot,strlen(httpGetRoot))) //texto
	  {
		  msgSize=genPageMsg(&msgOut,httpOk,httpTextHeader,SemID,SemBuf,ShMemTemps);
	  }
	  else if(!strncmp(buffRecv,httpGetImg,strlen(httpGetImg))) //imagen
	  {
		  msgSize=genImgMsg(&msgOut,httpOk);
	  }
	  else //bad resource 
	  {
		  msgSize=genBadResourceMsg(&msgOut,httpTextHeader);
	  }
	}
	else //bad Method
	{
		msgSize=genBadMethodMsg(&msgOut,httpTextHeader);
	}

	/*Envio al cliente el mensaje completo*/
	if(send(sockClient,msgOut,msgSize,0)< 0)
	{
	  perror("Error al enviar mensaje");
	  exit(EXIT_FAILURE);
	}
	
	/*Libero la memoria pedida para el mensaje completo en el interior de las funciones generadoras*/
	free(msgOut);
	/*Cierro el socket del cliente*/
	close(sockClient);
	exit(EXIT_SUCCESS);
}

void fTempChild(int SemID, struct sembuf* SemBuf,Temps* ShMemTemps )
{
	int i=0;
	int j=0;
	char buff[1];
	float acum=0.0;
	float tempLeida=0.0;
	int fd;
	
	signal(SIGTERM, HandlerTempKill);
	signal(SIGINT, HandlerTempKill);
	
	/*intento abrir el driver de I2C*/
	if((fd=open(PATH_I2C,O_RDWR))<0)
	{
		perror("Error al intentar abrir el archivo I2C1...pruebe instalando el modulo");
		exit(EXIT_FAILURE);
	}
	/*Configuro la direccion en la que se encuentra el sensor*/
	if(ioctl(fd,I2C_SLAVE_CMD,I2C_LM75_ADDR)<0)
	{
		close(fd);
		perror("Error de IOCTL al intentar configurar la Slave Addr");
		exit(EXIT_FAILURE);
	}
	
	buff[0]=0; //Coloco el puntero del sensor en 0, para leer el registro interno de temperatura.
	if(write(fd,buff,1)!=1)
	{
		close(fd);
		perror("Error al Intentar escribir el puntero del registro en el sensor de temperatura");
		exit(EXIT_FAILURE);
	}
	
	//leo la temperatura del I2C1
	tempLeida=getTemp(fd); 
	
	/*Tomo el semaforo para escribir la memoria compartida!*/
	SemBuf->sem_op=-1; //Lockeo el semaforo
	if(semop(SemID,SemBuf,1) < 0)
	{perror("Error en semop de shared mem 1 \n");}
	
	/*Inicializo las estructuras de memoria compartida*/
	for(i=0; i<CANT_TEMPS_MEAN; i++)
	{ShMemTemps->temps[i]=tempLeida;}

	ShMemTemps->tempMax=tempLeida;
	ShMemTemps->tempMin=tempLeida;
	ShMemTemps->tempMean=tempLeida;
	
	SemBuf->sem_op=1; //unlockeo el semaforo
	if(semop(SemID,SemBuf,1) < 0)
	{perror("Error en semop de shared mem 2 \n");}
	
	i=0;
	
	while(tempRunning)
	{
		//Tomo el semaforo para operar sobre la shared MEM
		SemBuf->sem_op=-1; //lockeo el semaforo
		if(semop(SemID,SemBuf,1) < 0)
		{perror("Error en semop de shared mem 3 \n");}
		
		/*Leo sin eliminar hasta llenar por primera vez el buffer*/
		if(i < CANT_TEMPS_MEAN)
		{
			tempLeida=getTemp(fd);
			ShMemTemps->temps[i]=tempLeida;
			i++;
		}
		else //si ya llene el buffer, elimino la primera, desplazo las otras y tomo una nueva
		{
			for(j=0; j<(CANT_TEMPS_MEAN-1); j++)
			{
				ShMemTemps->temps[j]=ShMemTemps->temps[j+1];
			}
			tempLeida=getTemp(fd);
			ShMemTemps->temps[j]=tempLeida;//en el ultimo lugar coloco la temperatura leida
		}
		
		/*Actualizo el valor del MAXIMO*/
		if(tempLeida > ShMemTemps->tempMax)
		{ShMemTemps->tempMax=tempLeida;}
	
		/*Actualizo el valor del MINIMO*/
		if(tempLeida < ShMemTemps->tempMin)
		{ShMemTemps->tempMin=tempLeida;}
		
		/*Calculo de la media Movil*/
		for(j=0;j<CANT_TEMPS_MEAN;j++)
		{acum+=ShMemTemps->temps[j];}
		ShMemTemps->tempMean=(acum/CANT_TEMPS_MEAN);
		acum=0.0; //limpio la variable de acumulacion para la proxima vuelta
		
		SemBuf->sem_op=1; //unlockeo el semaforo
		if(semop(SemID,SemBuf,1) < 0)
		{perror("Error en de shared mem 4 \n");}
	
		sleep(T_GET_TEMP); //duermo el proceso por un tiempo
	}
	
	close(fd);
	exit(EXIT_SUCCESS);
	
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
		
	//Pido memoria para la cadena total
	stot =(char*) malloc(tot_size+1); //+1 para el null
	
	/*Concateno todo lo que debe tener la parte inicial del HTML*/
	strcat(stot,method);
	strcat(stot,header);
	strcat(stot,len);
	strcat(stot,twoNewLine);
	
	if(imgLen==0) //si es TEXTO, simplemente concatena la cadena HTML
	{strcat(stot,html);}
	
	else //si es una imagen.... debe agregarla, pero NO sirve strcat ya que el archivo puede tener caracteres '\0'
	{
		/*Por lo tanto, voy agregando los bytes de la imagen en la cadena, pero a partir del fin del overhead*/
		for(i=0; i<size_html;i++) 
		{stot[size_overhead+i]=html[i];}
		stot[tot_size]=' ';
	}
		
	free(len);  //libero el puntero interno len.	
	*pDest=stot; //devuelvo el puntero al string armado. RECORDAR LIBERARLO EN LA APLICACION
	
	return tot_size;
}

int genBadResourceMsg(char** pMsg, char* httpTextHeader)
{
	char httpBadResource[]= "HTTP/1.1 404 Bad resource \n"; //Respuesta en caso de recurso inexistente
	
	/*Codigo HTML de la pagina Bad Resource*/
	char htmlBadResource[]="<!DOCTYPE html>\
								<html>\
									<body style=\"background-color: #2E2E2E;\">\
										<h1 style=\"color: #8181F7;\">Error 404</h1>\
										<h2 style=\"color: #8181F7;\">Bad Resource</h2>\
									</body>\
								</html>";
	
	return genMsg(pMsg,httpBadResource,httpTextHeader,htmlBadResource,0);
}

int genBadMethodMsg(char** pMsg, char* httpTextHeader)
{
	char httpBadMethod[]="HTTP/1.1 400 Bad method \n"; //Respuesta en caso de metodo erroneo
	
	/*Codigo HTML del Bad Method*/								
	char htmlBadMethod[]="<!DOCTYPE html>\
									<html>\
										<body style=\"background-color: #2E2E2E;\">\
											<h1 style=\"color: #8181F7;\">Error 400</h1>\
												<h2 style=\"color: #8181F7;\">Bad Method</h2>\
										</body>\
									</html>";
	
	return genMsg(pMsg,httpBadMethod,httpTextHeader,htmlBadMethod,0);
}

int genPageMsg(char** pMsg,char* httpOk, char* httpTextHeader,int SemID, struct sembuf* SemBuf,Temps* ShMemTemps)
{

	int auxSize;
	char auxBuff[4096]; //buffer auxiliar para guardar el mensaje con el sprintf
	char* auxHtml;
	
	/*Codigo HTML de la pagina principal*/
	char htmlPage[]="<!DOCTYPE html>\
						<meta http-equiv=\"refresh\" content=\"1\">\
						<html>\
							<body style=\"background-color: #2E2E2E;\">\
								<h1 style=\"color: #8181F7;text-align: center;\">Tecnicas Digitales III</h1>\
								<h2 style=\"color: #8181F7;text-align: center;\">TP Nº2: Web server concurrente y driver i2c para BBB </h2>\
								<h2 style=\"color: #8181F7;text-align: center;\">-2017-</h2>\
								<h2 style=\"color: #D7DF01;text-align: center;\">Temperatura Media: %.2fºC</h2>\
								<h2 style=\"color: #FF0000;text-align: center;\">Temperatura Maxima: %.2fºC</h2>\
								<h2 style=\"color: #298A08;text-align: center;\">Temperatura Minima: %.2fºC</h2>\
								<h2 style=\"color: #8181F7;text-align: center;\">Ultimas 5 temperaturas: %.2fºC  %.2fºC  %.2fºC  %.2fºC  %.2fºC</h2>\
									<div align=\"center\" style=\"padding: 10px\">\
										<img src=\"img/utn.png\" alt=\"logo\" width=\"300\" height=\"100\" border=\"3\">\
									</div>\
								<h2>\
							</body>\
						</html>";
	
	/*Tomo el semaforo para acceder sobre a la memoria compartida*/
	SemBuf->sem_op=-1; //lockeo el semaforo
	if(semop(SemID,SemBuf,1) < 0)
	{perror("Error en semop de shared mem para READ 1\n");}
	
	/*Lleno la cadena de la pagina con los valores de las temperaturas faltantes y la guardo en auxBuff*/
	sprintf(auxBuff,htmlPage,ShMemTemps->tempMean,ShMemTemps->tempMax,ShMemTemps->tempMin,
			ShMemTemps->temps[0],ShMemTemps->temps[1],ShMemTemps->temps[2],ShMemTemps->temps[3],ShMemTemps->temps[4]);

	/*Libero el semaforo ya que termine de usar la memoria compartida*/
	SemBuf->sem_op=1; //lockeo el semaforo
	if(semop(SemID,SemBuf,1) < 0)
	{perror("Error en semop de shared mem para READ 2\n");}

	/*Pido memoria para guardar la cadena completa HTML*/
	if((auxHtml=(char*)malloc(strlen(auxBuff)+1))==NULL)
	{
		perror("genPageMsg: Error en malloc");
		exit(1);
	}
	
	/*Copio lo que habia en el buffer auxiliar a auxHtml */
	auxHtml=strcpy(auxHtml,auxBuff); 
	
	/*Genero la cadena final con todo el contenido HTTP y Html a enviar*/
	auxSize=genMsg(pMsg,httpOk,httpTextHeader,auxHtml,0);
	
	/*Libero la memoria del buffer auxiliar */
	free(auxHtml);
	
	/*Devuelvo el tamaño total*/
	return auxSize;
}

int genImgMsg(char** pMsg,char* httpOk)
{
	char httpImgHeader[]="Content-Type: image/png\nContent-Length: "; //valido para imagenes png
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
		perror("El error al intentar abrir el archivo");
		exit(EXIT_FAILURE);
	}
	/*Con estas funciones de linux, puedo obtener el TAMAÑO del archivo de imagen*/
	fstat(fd,&buffer);	
	filelength=buffer.st_size;
	
	/*Conociendo ese tamaño, pido con malloc una cantidad suficiente para alojarlo*/
	if((buff=(char*)malloc(filelength+1))==NULL)
	{
		perror("Fallo el MALLOC para la imagen");
		close(fd);
		exit(EXIT_FAILURE);
	}
	
	/*Leo el archivo y lo guardo en el buffer antes solicitado*/
	if( (bytes_leidos=read(fd,buff,filelength)) < 0)
	{
		perror("Fallo al leer el archivo de imagen");
		close(fd);
		free(buff);
		exit(EXIT_FAILURE);
	}
	
	close(fd);
	
	tot_size=genMsg(pMsg,httpOk,httpImgHeader,buff,filelength);
	free(buff);
	
	return tot_size; 
}


/****************************************************************************************************
IMPLEMENTACION DE LOS HANDLER DE SEÑALES
******************************************************************************************************/
void HandlerSIGINT(int signum)
{
	/*cierro el socket por si el server quedo en "listen()". 
	de esta manera fuerzo que termine el liste() y el server falla en el accept,
	cerrando el server de manera prolija (es decir eliminando semaforos, shmem, hijos,etc)*/
	close(sockServer); 
	serverRunning=NOT_RUNNING;
}

void HandlerSIGCHLD(int signum)
{
	/*espero que mueran TODOS los hijos, ya que pueden haber muerto varios!
	 uso 0 para matar procesos */
	while(waitpid(0,NULL,WNOHANG)>0) {} 
}

/*Handler para  matar correctamente al proceso hijo que lee temperatura*/
void HandlerTempKill(int signum)
{
		tempRunning=NOT_RUNNING;
}