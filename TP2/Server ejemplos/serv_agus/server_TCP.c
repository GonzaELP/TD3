
/**
 * @brief Título: Servidor concurrente TCP/IP server_TCP.c
 *
 * Servidor concurrente que espera conexiones por puerto definido por consola.
 * Cada conexión es atendida por un proceso hijo. Existe un proceso hijo que cada 1 segundo toma la lectura del sensor de temperatura y lo almacene en una variable
 * manteniendo una media móvil de 5 lecturas.
 *
 * @version 3.0
 * @author Agustin Leonel Guallan Silva
 * @date 09/11/2017
 */



/*********************************************************************************
* Bibliotecas
*********************************************************************************/

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


/*********************************************************************************
* Macros y Globales
*********************************************************************************/
#define PATH_IMAGEN "./img/utn.png" //Path de la imagen
#define PATH_ICO "./img/favicon.ico" //Path del icono de la pagina
#define MAX_CONN  10 //Nro maximo de conexiones en espera que va a tener nuestro servidor. OJO, no confundir conexiones en espera con conexiones entrantes
#define HTTP      1 //Estado que manda msj http
#define IMG       2 //Estado que manda msj img
#define FAVICON   3 //Estad que manda icono
#define SH_MEM_SZ 4 //Size de memoria compartida
#define SHM_FLAG 0666|IPC_CREAT //Flag para shared memory
#define ERROR    -1
#define ENCENDIDO 1
#define APAGADO   0
#define TIME_SLEEP 1 //Tiempo de consulta de temperatura

char MSG_GET [] = "GET"; //Solicitud GET del cliente, me voy a fijar si siempre es GET, sino error 400
char msg_OK [] = "HTTP/1.1 200 Ok \n"; //Respuesta del servidor a metodo GET valido
char msg_BadMethod [] = "HTTP/1.1 400 Bad method \n"; //Respuesta del servidor si el metodo no es GET
char msg_BadResource [] = "HTTP/1.1 404 Bad resource \n"; //Respuesta del servidor si el recurso no es / o /img/utn.png
char msg_GET_HTTP [] = "GET / HTTP/1.1"; //Solicitud del cliente para visualizar la pagina
char msg_GET_IMG [] = "GET /img/utn.png HTTP/1.1"; //Respuesta del cliente al enviar una imagen en el html
char msg_GET_FAVICON [] = "GET /favicon.ico HTTP/1.1"; //Solicitud del cliente de icono de la pagina
char msg_header [] = "Content-Type: text/html; charset=UTF-8\nContent-Length: xxx"; //Dejo un espacio para luego meter el Content_Lenght, El número es: strlen(HTML) \n\n
char msg_header_img [] = "Content-Type: image/png\nContent-Length: xxxxxxx"; //idem, el número es: sizeof(buffer_imagen) \n\n
char doble_new_line [] ="\n\n"; //doble enter final de header.

 /* Msj de prueba Hola Mundo en HTML */
 //char msg_Hola[] = "<!DOCTYPE html>\n<html lang=""es"">\n<head>\n</head>\n<body>\n<h4>Hola mundo desde mi server concurrente</h4>\n<img src=""img/utn.png"" alt=""logo"" width=""400"" height=""100"" align=""left"" border=""3"">\n</body>\n</html>\n"; //msj de prueba

 /* Msj HTML con la pagina */
char msg_html1 [] = "<!DOCTYPE html> \
                    <meta http-equiv =\"Refresh\"content=\"1\"\
                     <html lang=\"es\">\
                     <head>\
                      <title>Tecnicas Digitales 3</title>\
                     </head>\
                     <body style=\"background-color: #000000; \">\
                      <div align=\"center\">\
                        <h1 style=\"color: #0000CC;text-align: center;\">Tecnicas Digitales III</h1>\
                        <h2 style=\"color: #0000CC;text-align: center;\">- 2017 -</h2>\
                      </div>\
                      <div align=\"center\">\
                        <h3 style=\"color: #0000CC;text-align: center;\">Terminal de datos</h3>\
                        <h3 style=\"color: #0000CC;text-align: center;\">Proyecto con Beaglebone Black</h3>\
                      </div>\
                        <div style=\"background-color: #009933;border:1px solid #CEDCEA;\" align=\"center\">\
                          <h2 style=\"color: #00FF00;text-align: center;\">Temperatura recibida: ";

char msg_html2 [] = " C</h3>\
                        </div>\
                      <div align=\"center\" style=\"padding: 10px\">\
                        <img src=\"img/utn.png\" alt=\"logo\" width=\"300\" height=\"100\" border=\"3\">\
                      </div>\
                     </body>\
                   </html>";

 /* Msj HTML con error 400 */
char msg_error_400 [] = "<!DOCTYPE html> \
                         <html lang=\"es\">\
                         <head>\
                          <title>Tecnicas Digitales 3</title>\
                         </head>\
                         <body style=\"background-color: #000000; \">\
                          <div align=\"center\">\
                            <h1 style=\"color: #0000CC;text-align: center;\">Tecnicas Digitales III</h1>\
                            <h2 style=\"color: #0000CC;text-align: center;\">- 2017 -</h2>\
                          </div>\
                          <div align=\"center\">\
                            <h3 style=\"color: #0000CC;text-align: center;\">Terminal de datos</h3>\
                            <h3 style=\"color: #0000CC;text-align: center;\">Proyecto con Beaglebone Black</h3>\
                          </div>\
                            <div style=\"background-color: #860608;border:1px solid #CEDCEA;\" align=\"center\">\
                              <h2 style=\"color: #ED1114;text-align: center;\">Opss...</h2>\
                              <h3 style=\"color: #ED1114; text-align: center;\">ERROR 400 BAD METHOD</h3>\
                            </div>\
                         </body>\
                        </html>";

 /* Msj HTML con error 404 */
char msg_error_404 [] = "<!DOCTYPE html> \
                           <html lang=\"es\">\
                           <head>\
                            <title>Tecnicas Digitales 3</title>\
                           </head>\
                           <body style=\"background-color: #000000; \">\
                            <div align=\"center\">\
                              <h1 style=\"color: #0000CC;text-align: center;\">Tecnicas Digitales III</h1>\
                              <h2 style=\"color: #0000CC;text-align: center;\">- 2017 -</h2>\
                            </div>\
                            <div align=\"center\">\
                              <h3 style=\"color: #0000CC;text-align: center;\">Terminal de datos</h3>\
                              <h3 style=\"color: #0000CC;text-align: center;\">Proyecto con Beaglebone Black</h3>\
                            </div>\
                              <div style=\"background-color: #860608;border:1px solid #CEDCEA;\" align=\"center\">\
                                <h2 style=\"color: #ED1114;text-align: center;\">Opss...</h2>\
                                <h3 style=\"color: #ED1114; text-align: center;\">ERROR 404 Not Found BAD RESOURCE</h3>\
                              </div>\
                           </body>\
                          </html>";

 
/**
 * @struct Smem
 * @brief Representa la shared memory en donde voy a alojar la temperatura promedio y las lectura para que las vean todos los procesos
 */

/*Estructura de datos de la memoria compartida */
typedef struct memoria
{
  float temp_promedio;
  float lecturas[5];
  char indice;
} SMem;

unsigned char ServerRun = ENCENDIDO; //Variable Global para mantener el server encendido hasta que lo queramos apagar

/*********************************************************************************
* Prototipos
*********************************************************************************/
char* MsgBuild (int*, float); //Funcion para armar el msj html
char* MsgBuildError (char*, int*, char*); //Funcion para armar el msj html
char* MsgBuildImg (char*,int*); //Funcion para armar el msj con la imagen
void ChildWork(int sock_client, SMem *); //Funcion del proceso hijo que trabaja con el cliente.

void HandlerSigCHLD(int signal); //Funcion que maneja la senal SigChild para matar el proceso hijo
void HandlerSigINT(int signal); //Funcion que maneja la senal SigINT para cerrar todo.
void TemperaturaProcess(SMem *); //Funcion que procesa la temperatura leida y hace el promedio
int LeerTemp(void);


/**
 * @brief Función MAIN
 * @param argc es la cantidad de parametros que recibe
 * @param argv es un char* con los parametros por consola. Recibe el puerto de conexion al Server TCP/IP.
 * @return Retorna 0 si finalizó OK el server o 1 si hubo algun error.
 */

int main(int argc, char *argv[])
{
 int m_socket, s_client; ///< Socket server y socket cliente
 struct sockaddr_in address; ///<Estructura provista por la libreria de socket para almacenar las direcciones.
 socklen_t addrlen; ///<Se va a usar para el tamaño de la estructura address
 char ipAddr[20]; ///<Direccion ip del cliente, es un string
 int Port; ///<Numero de puerto (8000)
 int rc; ///<Para manejar hijos
 int pid_child_temp; ///<pid del hijo que va a manejar la temp, lo necesito para matarlo
 key_t key_Shmem = ftok("memcompartida", 'a'); ///< Key de la shared memory, ftok genera una clave IPC, en funcion del path y id
 int ShmemID; ///<ID para la shared memory
 void *ShMemAddr = NULL; ///<puntero a la estructura para los datos de la shared memory
 SMem *pshmem = NULL; ///<puntero auxiliar a la estructura para los datos de la shared memory
 int i = 0;

 /*Capturo la senal SIG CHILD */
 signal (SIGCHLD, HandlerSigCHLD);
 /*Capturo la senal SIG INT */
 signal (SIGINT, HandlerSigINT);

 if (argc != 2) //Si tiene dos argumentos (el mismo programa y el puerto, crea el socket, sino error)
 {
	printf("\n\nTenes que ingresar por Linea de comandos con la siguiente nomeclatura: servtcp NºPuerto\n\n"); //cantidad de parametros enviados por linea de comando incorrecta
	exit(1);
 }

 /* Creo la memoria compartida donde se va a alojar la temperatura, en el padre. */
 if( (ShmemID = shmget (key_Shmem, SH_MEM_SZ, SHM_FLAG)) == ERROR) //Me devuelve un ID, le paso una clave, un tamaño y el flag de IPC
 {
  perror("Fallo el shmget para pedir memoria compartida");
  exit(EXIT_FAILURE);
 }

 /*Adjunto memoria al proceso padre, hago un attach */
 if((ShMemAddr = shmat (ShmemID, NULL, 0)) == (int *) ERROR)
 {
  perror("Error en attach de memoria compartida en proceso padre");
  exit(EXIT_FAILURE);
  
 }

 pshmem = (SMem *) ShMemAddr; //Tengo un puntero a la direccion de memoria compartida para la temperatura

 /* Crea un proceso hijo para leer la temperatura cada 1 seg y procesarla. */
 if ((rc = fork()) < 0)
  {
    printf("Error en fork para proceso hijo temperatura");
    exit(1);
  }

 if (rc == 0) //Si rc=0 estoy en el proceso hijo.
  {
    /*Inicializo valores de estructura default*/
    pshmem->indice = 0;
    pshmem->temp_promedio = 0;
    for (i ; i < 5; i++)
    {
      pshmem->lecturas[i] = 0;
    }
    /*El hijo queda en un while 1 procesando la temperatura */
    while (1)
    {
      TemperaturaProcess(pshmem); //Funcion que procesa la temperatura del lector y guarda el promedio
      sleep(TIME_SLEEP); //Duerme durante el tiempo TIME_SLEEP
      //printf("Vemos la temp promedio: %f\n", pshmem->temp_promedio);
    }
    exit(0);
  }
  else
  {
    pid_child_temp = rc; //Guardo el PID del hijo para matarlo despues.
    printf("pid del hijo: %d\n", pid_child_temp);
  }


 /* 1. Crea el socket, bloque de control de transmision maestro. */
 m_socket = socket(AF_INET, SOCK_STREAM,0); //funcion socket provista por sys/socket, en s tenemos un numero de socket provisto por el SO
 if (m_socket < 0) //Si no hay errores al crear el socket sigue, sino error.
 {
 	printf("ERROR: El socket no se ha creado correctamente!\n"); //Error al crear el socket
 	exit(1);
 }

 /* 2. Crea una estructura de datos para mantener la direccion y puerto local de IP a usar. Se asigna puerto pasado por parametro. */
 /* Asigna el puerto indicado y una IP de la maquina */
 address.sin_family = AF_INET; //Indicador que siempre va AF_INET para td3
 address.sin_port = htons(atoi(argv[1])); //atoi convierte a entero el puerto que le pasamos por shell y htons lo convierte para meter en la struct
 address.sin_addr.s_addr = htonl(INADDR_ANY); //htonl convierte para meter en la struct y la macro INADDR_ANY es para indicar que aceptamos cualquier direccion IP de afuera

 /* 3. Conecta el socket a la direccion local con Bind (Bindear). Se pasa el socket, un puntero a la estructura de address y el tamaño de la estructura */
 if (bind(m_socket, (struct sockaddr*)&address, sizeof(address))) //Trata de bindear, si no puede, error
 {
 	printf("ERROR al nombrar el socket\n"); //Error al bindear el socket.
 	perror("Error en bind");
 	exit(1);
 }

 /* Server Activo */
 printf("\n\aServidor ACTIVO escuchando en el puerto: %s\n",argv[1]);


 /* 4. Indica que el socket encole hasta MAX_CONN pedidos de conexion simultaneas. */

 if (listen(m_socket, MAX_CONN) < 0) // Con listen le indicamos que puede enconlar hasta un maximo de conexiones simultanesas por ese puerto.
 {
	perror("Error en listen"); //Funcion del sistema operativo para indicar error en el proceso.
	exit(1); //sale del programa
 }

 /* 5. Ciclo infinito, espera multiples conexiones entrantes (clientes) por puerto indicado (8000).
 Accept devolvera un nuevo descriptor de conector que se usara con dicho cliente. Para cada conexion va a haber un proceso hijo
 Se va a mantener el While hasta que quiera detener el server con ctrl+c, voy a capturar la señal y salir del while.*/

 while (ServerRun)
 {
  /* La funcion accept rellena la estructura address con informacion del cliente y pone en addrlen la longitud de la estructura.
  Aca se podria agregar codigo para rechazar clientes invalidos cerrando s_aux. En este caso el cliente fallaria con un error 
  de "broken pipe" cuando quiera leer o escribir al socket. */

  /* A accept se le pasa el numero de socket, un puntero a la estructura address y un puntero al tamaño de la estructura address,
  devuelve un numero de identificacion, entero. */

  addrlen = sizeof(address);
  if ((s_client = accept (m_socket, (struct sockaddr*) &address, &addrlen)) < 0)
  {
    perror("Error en accept"); //Error con la funcion accept
    exit(1); //sale del programa
  }

  /* 6. Crea un proceso hijo para manejar al cliente. */
  if ((rc = fork()) < 0)
  {
    printf("Error en fork");
    exit(1);
  }

  if (rc == 0) //Si rc=0 estoy en el proceso hijo.
  {
    ChildWork(s_client, pshmem);
    /* Cierra la conexion con el cliente actual */
    close(s_client);
    exit(0);
  }

  /* Cierra el descriptor en el padre, ya lo tengo al hijo con un despcriptor apuntando a ese socket */
  close(s_client);
 }

 printf("\nCerrando Server...\n");

 shmdt(ShMemAddr); //Hago un Desattachment del proceso padre a la memoria compartido
 shmctl(ShmemID, IPC_RMID, 0); //Elimino la memoria compartida

 kill(pid_child_temp, SIGKILL); //Mato proceso hijo que lee temperatura
 while(waitpid(-1, NULL, WNOHANG) > 0); //Espero que se mueran todos los hijos
 close(m_socket); // Cierra el servidor

 printf("\nServer Detenido\n");

 return 0;
}




/**
 * @brief Función ChildWork
 * Se encarga de enviar el contenido html al cliente.
 *
 * @param sock_client recibe el socket asignado por el SO
 * @param pshmem recibe un puntero a la estructura que esta en la shared memory
 * @return Retorna void
 */

void ChildWork(int sock_client, SMem *pshmem)
{
 char msg_entrada[1024]; //Se va a usar para almacenar el mensaje que envia el cliente
 char ipAddr[20]; //Direccion ip del cliente, es un string
 socklen_t length; //Se va a usar para el tamaño de la estructura ClientAddr.
 struct sockaddr_in clientAddr; //Estructura provista por la libreria de socket para almacenar las direcciones.
 int Port; //Num de puerto por donde se conecta el cliente.
 char *msg_OUT; //Puntero a string de msj de Salida al cliente.
 int SZ_msg_OUT; //Variable para almacenar el tamaño del string de msj de salida.
 int method = ERROR; //Key del switch para los mensajes recibidos.
 float temperatura = pshmem->temp_promedio; //Tomo la temperatura promedio de la shared memory

 /* Obtiene direccion IP y puerto del cliente */
 length = sizeof(clientAddr);
 if (getpeername(sock_client, (struct sockaddr *)&clientAddr, &length))
 {
	perror("peername");
	exit(1);
 }

 strcpy(ipAddr, inet_ntoa(clientAddr.sin_addr)); //Copio en mi variable ipAddr la ip del cliente usando la funcion inter_ntoa como ayuda. Es un string!
 Port = ntohs(clientAddr.sin_port); //Copio el valor del puerto (8000) y lo convierto a entero usando ntohs.

 /* Recibe el mensaje del cliente usando recv. Se pasa el numero de identificacion del accept, la variable para almacenar y el tamaño */
 if (recv(sock_client, msg_entrada, sizeof(msg_entrada), 0) == -1)
 {
	perror("Error en recv"); //Error recibiendo el mensaje.
	//exit(1);
 }

 /* Logueo info del cliente en consola */
 printf("Recibido del cliente %s:%d: %s\n", ipAddr, Port, msg_entrada); //Muestra un mensaje indicando la direc. IP del cliente, el puerto y el msj

 /* Me fijo si el metodo recibido es un GET, si no lo es, error 400*/
 if (strncmp(MSG_GET, msg_entrada, strlen(MSG_GET)) == 0)
 {
    /* Me fijo si el mensaje recibido es GET HTTP */
    if (strncmp(msg_GET_HTTP, msg_entrada, strlen(msg_GET_HTTP)) == 0) { method = HTTP; }

    /* Me fijo si el mensaje recibido es GET Image */
    if (strncmp(msg_GET_IMG, msg_entrada, strlen(msg_GET_IMG))==0) { method = IMG; }

    /* Me fijo si el mensaje recibido es GET Favicon, icono de la pagina */
    if (strncmp(msg_GET_FAVICON, msg_entrada, strlen(msg_GET_FAVICON))==0) { method = FAVICON; }

    switch(method)
    {
      case HTTP:
      /* MsgBuild que se va a encargar de preparar el msj de salida. Le paso la temperatura y la variable del tamaño del msj.
      Devuelve un puntero al msj de Salida. Es memoria dinamica, dsp hay que hacer un free. */
      msg_OUT = MsgBuild(&SZ_msg_OUT, temperatura);
      break;

      case IMG:
      /* MsgBuildImg que se va a encargar de preparar el msj de salida con la imagen. Le paso la variable del tamaño del msj.
      Devuelve un puntero al msj de Salida. Es memoria dinamica, dsp hay que hacer un free. */
      msg_OUT = MsgBuildImg(PATH_IMAGEN, &SZ_msg_OUT);
      break;

      case FAVICON:
      msg_OUT = MsgBuildImg(PATH_ICO,&SZ_msg_OUT);
      break;

      default:
      /* Por default si no recibo un GET para ninguno de esos recursos, es un error 404.
      * MsgBuildError que se va a encargar de preparar el msj de error. Le paso el msg de error y la variable del tamaño del msj.
      * Devuelve un puntero al msj de Salida. Es memoria dinamica, dsp hay que hacer un free. */
      msg_OUT = MsgBuildError(msg_error_404, &SZ_msg_OUT, msg_BadResource);
      break;
    }
 }
 else
 {
    msg_OUT = MsgBuildError(msg_error_400, &SZ_msg_OUT, msg_BadMethod);
 }

  /* Envia el mensaje al cliente usando el numero de identificacion del accept. */

  if (send(sock_client, msg_OUT, SZ_msg_OUT, 0) == -1)
  {
    perror("Error en send"); //error enviando el msj
    //exit(1);
  }

  free(msg_OUT); //Libera memoria tomada por el mensaje de salida
 }



/**
 * @brief Función msgBuild
 * Se encarga de armar el mensaje html con los headers correspondientes.
 *
 * @param SZ_message recibe la direccion para guardar el tamaño total del msj.
 * @param temperatura recibe la temperatura del sensor.
 * @return Retorna un puntero al mensaje de salida
 */

char* MsgBuild (int *SZ_message, float temperatura)
{
  char * ptr_msg_OUT; //Puntero para armar el msj de salida.
  char buffer_temp[10]; //String para guardar la temperatura
  int SZ_HTML; //variable para alojar el tamaño final del msj html

  sprintf(buffer_temp,"%f",temperatura); //Convierto la temperatura a string

  SZ_HTML = sizeof(char)*(strlen(msg_html1)+strlen(buffer_temp)+strlen(msg_html2)); //Guardo el tamaño total del msj html.

  sprintf(msg_header+strlen(msg_header)-3,"%d",SZ_HTML); //Le agrego el tamaño del html al header, info necesaria en html.

  /* Pido memoria para un buffer con todo el msj html. */
  ptr_msg_OUT = malloc ((sizeof(char)*(strlen(msg_OK)+strlen(msg_header)+strlen(doble_new_line)))+SZ_HTML+1);

  sprintf(ptr_msg_OUT, "%s", msg_OK); //Agrego el msg_OK al msj de salida.
  strcat(ptr_msg_OUT, msg_header); //Agrego el msg_header al msj de salida, ya tiene el tamaño del html.
  strcat(ptr_msg_OUT, doble_new_line); //Agrego el doble enter al final del header.
	strcat(ptr_msg_OUT, msg_html1); //Agrego el msj html al msj de salida.
  strcat(ptr_msg_OUT, buffer_temp); //Agrego la temperatura al msj de salida.
  strcat(ptr_msg_OUT, msg_html2); //Agrego el resto del msj html al msj de salida.
	
  *SZ_message = strlen(ptr_msg_OUT); //Guardo en la variable SZ_message el tamaño del msj de salida.

  //printf("mensaje antes de enviar:\n%s",ptr_msg_OUT);
  //printf("strlen de temperatura: %d\n", sizeof(char)*strlen(t));
  return ptr_msg_OUT; //retorno el puntero al msj de salida.
}

/**
 * @brief Función MsgBuildError
 * Se encarga de armar el mensaje html de error 400 o 404 con los headers correspondientes.
 *
 * @param message recibe un puntero al mensaje html
 * @param SZ_message recibe la direccion para guardar el tamaño total del msj.
 * @param msg_first_line recibe un puntero con el heade
 * @return Retorna un puntero al mensaje de salida
 */

char* MsgBuildError (char* message,int *SZ_message, char* msg_first_line)
{
  char * ptr_msg_OUT; //Puntero para armar el msj de salida.

  /* Pido memoria para un buffer con todo el msj html. */
  ptr_msg_OUT = malloc (sizeof(char)*(strlen(msg_first_line)+strlen(msg_header)+strlen(message)+strlen(doble_new_line)));

  sprintf(msg_header+strlen(msg_header)-3,"%d",(unsigned int)strlen(message)); //Le agrego el tamaño del html al header, info necesaria en html.
  sprintf(ptr_msg_OUT, "%s", msg_first_line); //Agrego el msg_OK al msj de salida.
  strcat(ptr_msg_OUT, msg_header); //Agrego el msg_header al msj de salida, ya tiene el tamaño del html.
  strcat(ptr_msg_OUT, doble_new_line); //Agrego el doble enter al final del header.
  strcat(ptr_msg_OUT, message); //Agrego el msj html al msj de salida.
  
  *SZ_message = strlen(ptr_msg_OUT); //Guardo en la variable SZ_message el tamaño del msj de salida.

  //printf("mensaje antes de enviar:\n%s",ptr_msg_OUT);

  return ptr_msg_OUT; //retorno el puntero al msj de salida.
}


/**
 * @brief Función MsgBuildImg
 * Se encarga de armar el mensaje html de error 400 o 404 con los headers correspondientes.
 *
 * @param PATH_img recibe un puntero con el path de la imagen
 * @param SZ_message recibe la direccion para guardar el tamaño total del msj.
 * @return Retorna un puntero al mensaje de salida
 */

char* MsgBuildImg (char *PATH_img,int *SZ_message)
{
  int i = 0; //Acumulador que voy a usar para leer de archivo imagen.
  int fp_origen, it_leidos; //File pointer y cantidad de items leidos, para uso en archivos.
  char *buffer; //Puntero a mensaje de salida

  int N_Caracteres = strlen(msg_OK) + strlen(msg_header_img) + strlen(doble_new_line); //tamaño del header de msj de imagen.

  /* Pido memoria para el buffer con todo el header. */
  buffer = (char *) malloc(sizeof(char)*N_Caracteres);
  if (buffer == NULL) //Si el SO me devuelve un ptro a NULL, error.
  {
    printf(" Error al intentar reservar memoria ");
    exit(1);
  }

  sprintf(buffer, "%s", msg_OK); //Copio el msg_OK a mi buffer.
  strcat(buffer, msg_header_img); //Copio el msg_header_img a mi buffer.
  strcat(buffer, doble_new_line); //Copio el enter doble a mi buffer.

  *SZ_message=N_Caracteres; //Guardo el tamaño del header hasta el momento.

  /* Abro el archivo de la imagen en Read Only. */
  fp_origen = open (PATH_img, O_RDONLY);
  if(fp_origen == -1)
  {
    perror("Error de apertura de archivo de origen\n");
    exit(1);
  }

  buffer = (char *) realloc (buffer,sizeof(char)*(N_Caracteres+1)); //Pido memoria para un elemento char mas, aparte de lo que ya tenia el buffer.
  if (buffer == NULL) //Si el SO me devuelve un ptro a NULL, error.
  {
    printf(" Error al intentar reservar memoria ");
    exit(1);
  }

  /* Voy a ir leyendo del archivo de la imagen y copiando en el buffer, a medida que agrando el buffer, hasta que se acabe el archivo. */
  while ((it_leidos = read(fp_origen, buffer + N_Caracteres + i, sizeof(char))) > 0)
  {
    if(it_leidos == -1) //Si Items leidos es -1, es error.
    {
      perror("Error leyendo archivo de origen\n");
      exit(1);
    }

    i++; //Aumento el acumulador
    buffer = (char*) realloc (buffer, sizeof(char)*(N_Caracteres + 1 + i)); //Pido mem para un elemento char mas, aparte de lo que ya tenia el buffer.

    if (buffer == NULL) //Si el SO me devuelve un ptro a NULL, error.
    {
      printf(" Error al intentar reservar memoria ");
      exit(1);
    }
  }

  close (fp_origen); //Cierro el archivo.
  *SZ_message+=i; //Agrego el tamaño de la imagen a la variable de tamaño de mensaje de salida.
  sprintf(buffer+strlen(msg_OK)+strlen(msg_header_img)-7,"%d",i); //Copio el tamaño de la img al header del msj de salida. Se copia con /0 al final. Tiene 6 digitos el tamaño de la imagen.
  *(buffer+strlen(msg_OK)+strlen(msg_header_img)-1) = ' '; //Saco el /0 que se metio al hacer sprintf.
  //printf("mensaje antes de enviar:\n%s",buffer);
  //printf("tamaño de i: %d\n", i);
  //printf("tamaño SZ_message %d\n", *SZ_message);
  return buffer; //retorno el puntero al msj de salida.
}




/**
 * @brief Función TemperaturaProcess
 * Se encarga procesar la temperatura leida hacer el promedio manteniendo una media movil de 5 lecturas
 *
 * @param pshmem recibe un puntero a la estructura en la memoria compartida
 * @return Retorna void
 */

void TemperaturaProcess(SMem *pshmem)
{
  float temp_leida; //Almaceno la temperatura leida

  temp_leida = LeerTemp(); //Leo del sensor
  pshmem->lecturas[pshmem->indice] = temp_leida; //Guardo la lectura en el array, segun el indice correspondiente
  pshmem->indice = pshmem->indice + 1; //incremento el indice
  
  if (pshmem->indice == 6) //si me pase de 5, reinicio el indice
  {
    pshmem->indice = 0;
  }

  /*Hago la media movil de las 5 lecturas y guardo el valor */
  pshmem->temp_promedio = (pshmem->lecturas[0]+pshmem->lecturas[1]+pshmem->lecturas[2]+pshmem->lecturas[3]+pshmem->lecturas[4])/5;

  return;
}

  /*Funcion auxiliar de prueba */
 int LeerTemp(void)
 {
  return 1;
 }




/**
 * @brief Función HandlerSigCHLD
 * Se encarga antender la señal emitida por los procesos hijos para matarlos
 *
 * @param signal recibe un int con la señal
 * @return Retorna void
 */

void HandlerSigCHLD (int signal)
{
  while(waitpid(-1, NULL, WNOHANG) > 0); //espera hasta matar a todos los hijos
  return;
}



/**
 * @brief Función HandlerSigINT
 * Se encarga antender la señal INTERRUPT ctrl+C y saca del while 1 al proceso padre.
 *
 * @param signal recibe un int con la señal
 * @return Retorna void
 */

void HandlerSigINT(int signal) 
{
  ServerRun = APAGADO; //Le cambia el valor a la variable ServerRun para que salga del while
  return;
}