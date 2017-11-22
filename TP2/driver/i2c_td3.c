/*
Autor: Gonzalo de Brito
Driver I2C para la BBB. Probado y funcionando en BBB rev. C con Linux v4.1.15-ti-rt-r43 y Debian v 4.9.2-10 

Para hacerlo funcionar, primero de sebe dar de baja el modulo "cape universal" que habilita en el arranque
el modulo I2C1. Para esto se debe editar en el directorio /boot el archivo uEnt.txt
Se debe cambiar la linea:
cmdline=coherent_pool=1M quiet cape_universal=enable
Por: 
cmdline=coherent_pool=1M quiet
De esta manera quedará deshabilitado el driver original del I2C y podrá utilizarse el de este archivo.

*/


#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/gpio.h>
#include <linux/fs.h>
#include <linux/errno.h>
#include <asm/uaccess.h>
#include <linux/version.h>
#include <linux/types.h>
#include <linux/kdev_t.h>
#include <linux/device.h>
#include <linux/cdev.h>
#include <linux/sched.h>
#include <asm/io.h>
#include <linux/ioctl.h>
#include <linux/irqdomain.h> //para poder mapear interrupciones fisicas al kernel
#include <linux/interrupt.h> //para poder usar interrupciones!

/*Base y longitud del juego de registros del modulo I2C1*/
#define I2C1_BASE_ADDR 0x4802A000
#define I2C1_LENGTH 0x1000

/*OFFSETS de los registros del modulo I2C*/
#define I2C_IRQSTATUS_RAW 0x24
#define I2C_IRQSTATUS 0x28
#define I2C_IRQENABLE_SET 0x2C
#define I2C_IRQENABLE_CLR 0x30
#define I2C_IRQ_ARDY (1<<2)
#define I2C_IRQ_RRDY (1<<3)
#define I2C_IRQ_XRDY (1<<4)
#define I2C_IRQ_BF (1<<8)

#define I2C_CON 0xA4
#define I2C_CON_I2C_EN (1<<15)
#define I2C_CON_MST (1<<10)
#define I2C_CON_TRX (1<<9)
#define I2C_CON_STT (1<<0)
#define I2C_CON_STP (1<<1)

#define I2C_SA 0xAC

#define I2C_PSC 0xB0
#define I2C_PSC_DIVIDER_12MHZ 0x03 // se divide por 3, ya que (48/12)-1 = 3. El -1 lo exige el modulo

#define I2C_SCLL 0xB4
#define I2C_SCLL_VAL_100KHZ 0x71 // ya que 12Mhz / 0.1 Mhz (del I2C = 120 - 7 (pedido por datasheet) = 113 = 0x71

#define I2C_SCLH 0xB8
#define I2C_SCLH_VAL_100KHZ 0x73 // ya que 12Mhz / 0.1 Mhz (del I2C = 120 - 5 (pedido por datasheet) = 115 = 0x71

#define I2C_CNT 0x98
#define I2C_DATA 0x9C
#define I2C_BUFSTAT 0xC0

/*Numero de IRQ del modulo I2C1*/
#define I2C1_IRQ (71)

/*Registros de habilitacion y control del clock del modulo I2C*/
#define CM_PER_BASE 0x44E00000
#define CM_PER_L4LS_CLKCTRL 0x00
#define CM_PER_I2C1_CLKCTRL 0x48

#define CM_PER_L4LS_CLKCTRL_SW_WKUP 0x02 // valor para forzar un wake up por software
#define CM_PER_I2C1_CLKCTRL_MODULEMODE_ENABLE 0x02 //valor para habilitar el clock del modulo I2C1

/*Registro de control y offsets para la configuracion del PinMux para usar el I2C1*/
#define SOC_CONTROL_REGS 0x44E10000
#define CONTROL_CONF_SPI0_D1  0x958
#define CONTROL_CONF_SPI0_CS0   0x95C

/*Opciones elegidas para los pines. El modo 2 corresponde a I2C*/
#define PIN_PULL_UP (1<<4)	
#define PIN_RX_ENABLED (1<<5)
#define PIN_SR_SLOW (1<<6)
#define PIN_MUX_2 0x02 

/*Numero de comando de IOCTL para setear la direccion del esclavo. Se usa este numero
ya que es el mismo que usa la direccion de */
#define I2C_SLAVE 0x0703 //define para setear la direccion del esclavo. 

/*Tamaño de los buffer de transmision y recepcion*/
#define RX_BUFF_SIZE 500
#define TX_BUFF_SIZE 500

/*Tamaño de los registros en bytes (32bits = 4 bytes)*/
#define AM335x_REG_BSIZE 4

MODULE_LICENSE("Dual BSD/GPL");
MODULE_AUTHOR("de Brito Gonzalo");
MODULE_DESCRIPTION("Driver I2C para BBB");

/*Variables de clase y device utilizadas para el init del driver en kernel*/
static dev_t dev;
static struct class *cl; 

/*Puntero a las direcciones virtuales asignadas por el kernel a los registros del I2C1*/
static void __iomem* i2c_mem;

/*Variable que contiene el numero de interrupcion asignado por el kernel*/
static unsigned int virq; 

/*Colas de espera para la comunicacion I2C*/
static wait_queue_head_t waitqueue_rx;
static wait_queue_head_t waitqueue_tx;
static wait_queue_head_t waitqueue_ardy;

/*Variables de la comunicacion I2C*/
volatile unsigned int tCount; //numero de bytes transmitidos
volatile unsigned int rCount; //numero de bytes recibidos
volatile unsigned char dataR[RX_BUFF_SIZE]; //buffer de recepcion
volatile unsigned char dataT[TX_BUFF_SIZE]; //buffer de tranmsision
volatile unsigned int numOfBytes; //numero de bytes a enviar/recibir
volatile unsigned int accessRdy=0; //flag de access ready

/*Prototipo del handler de la interrupcion I2C*/
static irq_handler_t  i2c_td3_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs);
 


static int i2c_open(struct inode *i, struct file *f)
{
	//Variable auxiliar para leer/escribir registros
	unsigned int a=0;

	/*Espacio de memoria correspondiente al control del clock del modulo I2C*/
	void __iomem* p1 = ioremap(CM_PER_BASE+CM_PER_I2C1_CLKCTRL,AM335x_REG_BSIZE);
	void __iomem* p2 = ioremap(CM_PER_BASE+CM_PER_L4LS_CLKCTRL,AM335x_REG_BSIZE);
	/*Espacio de memoria correspondiente al control del PinMux de los pines del modulo I2C1*/
	void __iomem* p3 = ioremap(SOC_CONTROL_REGS+CONTROL_CONF_SPI0_D1,AM335x_REG_BSIZE); //SCL
	void __iomem* p4 = ioremap(SOC_CONTROL_REGS+CONTROL_CONF_SPI0_CS0,AM335x_REG_BSIZE); //SDA
	
	/*Activacion del clkctrl del I2C1*/
	a=ioread32((unsigned int*) p1);
	a&=(~(0x03)); //limpio los 2 LSB
	a|=CM_PER_I2C1_CLKCTRL_MODULEMODE_ENABLE; //Habilito el clock para el modulo I2C
	iowrite32(a,p1); //escribo el registro correspondiente
	
	/*Activacion del L4LS, tambien necesario*/
	a=ioread32((unsigned int*) p2);
	a&=(~(0x03)); //limpio los 2 LSB
	a|=CM_PER_L4LS_CLKCTRL_SW_WKUP; //coloco el registro en estado de wakeup forzado por soft
	iowrite32(a,p2); //escribo el registro correspondiente
	
	/*Confguracion de los pines, los dos van igual*/
	/*Seteo: 1) Pullup 2)Pin como receiver enabled, 3)Slewrate lento, 4) MUX 2, es decir I2C SDA y SCL */
	a= (PIN_PULL_UP | PIN_RX_ENABLED | PIN_SR_SLOW | PIN_MUX_2);
	iowrite32(a,p3);
	iowrite32(a,p4);
	
	//desmapeo los dos registros solicitados antes
	iounmap(p1);
	iounmap(p2);
	iounmap(p3);
	iounmap(p4);
	
	/*Deshabilito el modulo mientras configuro los registros de clock*/
	unsigned int aux = ioread32(i2c_mem+I2C_CON); //resguardo el valor original del registro de control
	aux&=(~ I2C_CON_I2C_EN);//deshabilito el modulo I2C_EN = 0 
	iowrite32(aux,i2c_mem+I2C_CON); //grabo el valor ya modificado
	
	/*Configuro el preescaler para obtener un Clock de "alimentacion" del modulo de 12Mhz aprox*/
	iowrite32 (I2C_PSC_DIVIDER_12MHZ,i2c_mem+I2C_PSC); //escribo un I2C_PSC_DIVIDER = 3, de esta manera dividirá por 4 (48Mhz/12Mhz = 4).
 	if( ioread32(i2c_mem+I2C_PSC) != I2C_PSC_DIVIDER_12MHZ) //leo para verificar que se escribio bien
	{
		printk(KERN_ALERT "Error al escribir el preescaler \n");
		return -1;
	}
	
	/*Configuro el tiempo de pulso en bajo (SCLL) y en alto (SCLH) para obtener una salida a 100kHz*/
	iowrite32(I2C_SCLL_VAL_100KHZ,i2c_mem+I2C_SCLL); // 12Mhz (Clock del modulo) / 0.1Mhz (100khz, clock del i2c) = 120 - 7 =113. El 7 lo pide el micro (ver datasheet) 
	if( ioread32(i2c_mem+I2C_SCLL) != I2C_SCLL_VAL_100KHZ)
	{
		printk(KERN_ALERT "Error al escribir SCLL \n");
		return -1;
	}
	
	iowrite32(I2C_SCLH_VAL_100KHZ,i2c_mem+I2C_SCLH); //igual que en el anterior pero solo se resta 5 = 115 = 0x73
	if( ioread32(i2c_mem+I2C_SCLH) != I2C_SCLH_VAL_100KHZ)
	{
		printk(KERN_ALERT "Error al escribir SCLH \n");
		return -1;
	}
	
	/*Finalmente habilito el módulo*/
	aux = ioread32(i2c_mem+I2C_CON); //resguardo el valor original del registro de control
	aux |= I2C_CON_I2C_EN; //Habilito el modulo I2C_EN = 0
	iowrite32(aux,i2c_mem+I2C_CON); //grabo el valor ya modificado
	
	iowrite32(I2C_IRQ_ARDY,i2c_mem+I2C_IRQSTATUS_RAW); 
	//la primera vez disparo adrede una interrupcion de ardy para entrar en el ciclo!. Luego de las lecturas y escrituras comenzara a entrar solo!
	
	/*Pongo en el log de kernel un mensaje de correcta apertura*/
	printk(KERN_ALERT "Modulo HW I2C1 abierto correctamente");
    return 0;
}

static int i2c_release(struct inode *i, struct file *f)
{
	printk(KERN_ALERT "Se hace el release del i2c \n");
    return 0;
}


long i2c_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{	
	/*Para los objetivos del TP la unica config que me interesa establecer 
	 es la direccion del esclavo, por esto solo admito este comando*/
	if(cmd == I2C_SLAVE)
	{
		/*Escribo la slave addr y verifico que se haya escrito el valor correcto*/
		iowrite32((arg & (0x7F)),i2c_mem+I2C_SA); //escribo la slave address dejando solo los 7 LSB con algo y el resto limpio (ya que usare addr de 7bits)
		if( ioread32(i2c_mem+I2C_SA) != arg)
		{
			printk(KERN_ALERT "Error al escribir SA \n");
			return -1;
		}
		printk(KERN_ALERT "Direccion de esclavo configurarda OK \n");
		return 0; //todo salio ok al escribir SA
	}
	
	printk(KERN_ALERT "Opcion de IOCTL desconocida \n");
	return -1;
}


static ssize_t i2c_read(struct file *file, char *buf, size_t count, loff_t *nose)
{
	//Variable auxiliar para la lectura/escritura de registros
	unsigned int aux=0;
	size_t count_rx = count; //variable interna utilizada para que no intenten escribir en un tamaño mayor que el del buffer
	int qret;
	
	if(count > RX_BUFF_SIZE)//
	{count_rx=RX_BUFF_SIZE;}
	
	rCount=0; //limpio la cuenta de recepcion
	numOfBytes=count_rx; // coloco en la cuenta el número de bytes a recibir 
	
	iowrite32(I2C_IRQ_ARDY,i2c_mem+I2C_IRQENABLE_SET); //habilito la interrupcion por Access Ready
	
	if(wait_event_interruptible(waitqueue_ardy, (accessRdy))) //pongo a dormir que se pueda acceder al modulo i2c nuevamente
	{
		return -ERESTARTSYS; //vino una señal sino devuelve cero!
	}
	accessRdy=0; //pongo en cero el flag de accessRdy. 
	
	iowrite32(count_rx,i2c_mem+I2C_CNT); //seteo la cuenta de recepcion en el valor que corresponda.
	
	iowrite32(0x6FFF,i2c_mem+I2C_IRQSTATUS);  //limpio el registro de estado de interrupciones
	iowrite32(0x6FFF,i2c_mem+I2C_IRQENABLE_CLR); //deshabilito todas las interrupciones
	
	//Seteo el modulo en MASTER TX
	aux=ioread32(i2c_mem+I2C_CON);
	aux|=I2C_CON_MST; //lo coloco en MASTER.
	aux|=I2C_CON_TRX; //lo coloco en TX
	iowrite32(aux,i2c_mem+I2C_CON);
	
	//Lo paso a MASTER RX ya que segun datasheet solo puedo entrar en Master RX a partir de Master TX
	aux=ioread32(i2c_mem+I2C_CON);	
	aux&=(~I2C_CON_TRX); // paso a RX.
	iowrite32(aux,i2c_mem+I2C_CON);	
	
	//Habilito las INTERRUPCIONES relevantes
	iowrite32( ( I2C_IRQ_BF | I2C_IRQ_RRDY ),i2c_mem+I2C_IRQENABLE_SET); //habilito las irq por recepcion lista (RRDY, 3) y por condicion de stop (BF,8)
	
	//Coloco en el bus la condicion de START
	aux=ioread32(i2c_mem+I2C_CON);
	aux|=I2C_CON_STT;
	iowrite32(aux,i2c_mem+I2C_CON);
	
	//pongo a dormir hasta que se hayan leido todos los bytes
	if(wait_event_interruptible(waitqueue_rx, (rCount==numOfBytes))) 
	{
		return -ERESTARTSYS; //vino una señal sino devuelve cero!
	}	
	
	//copio lo leido al buffer de usuario
	if(__copy_to_user(buf,dataR,count_rx)) 
	{
		//si devuelve algo distinto de 0 es que no se pudo copiar todo al buffer de kernel!
		printk(KERN_ALERT "Error NO se pudo copiar la totalidad de los bytes al buffer de usuario\n");
		return -ERESTARTSYS;
	}
	
	 return count_rx; //sino, devuelvo la cantidad de bytes leidos
}
	
static ssize_t i2c_write(struct file *file, const char *buf,size_t count, loff_t *nose)
{
	unsigned int aux=0;
	unsigned int count_tx = count;
	
	tCount=0; //limpio la cuenta de recepcion

	//Valido que el usuario no intente escribir mas que el tamaño del buffer
	if(count > TX_BUFF_SIZE)
	{count_tx = TX_BUFF_SIZE;}
	
	numOfBytes=count_tx; // coloco en la cuenta el número de bytes a recibir
	
	if(__copy_from_user(dataT,buf,count_tx))//copio a dataT lo que me manda el user para ser transmitido.
	{
		//si devuelve algo distinto de 0 es que no se pudo copiar todo al buffer de kernel!
		printk(KERN_ALERT "Error NO se pudo copiar la totalidad de los bytes al buffer de kernel\n");
		return -ERESTARTSYS;
	}
	
	iowrite32(I2C_IRQ_ARDY,i2c_mem+I2C_IRQENABLE_SET); //habilito la interrupcion por Access Ready
	
	if(wait_event_interruptible(waitqueue_ardy, (accessRdy))) //pongo a dormir que se pueda acceder al modulo i2c nuevamente
	{
		return -ERESTARTSYS; //vino una señal sino devuelve cero!
	}
	accessRdy=0; //pongo en cero el flag de accessRdy. 
			
	iowrite32(count_tx,i2c_mem+I2C_CNT); //seteo la cuenta de recepcion en el valor que corresponda.
	
	iowrite32(0x6FFF,i2c_mem+I2C_IRQSTATUS);  //limpio el registro de estado de interrupciones
	iowrite32(0x6FFF,i2c_mem+I2C_IRQENABLE_CLR); //deshabilito todas las interrupciones
	
	//Seteo el modulo en MASTER TX
	aux=ioread32(i2c_mem+I2C_CON);
	aux|=I2C_CON_MST; //lo coloco en MASTER.
	aux|=I2C_CON_TRX; //lo coloco en TX
	iowrite32(aux,i2c_mem+I2C_CON);
	
	//Habilito las INTERRUPCIONES relevantes
	iowrite32(I2C_IRQ_XRDY,i2c_mem+I2C_IRQENABLE_SET); //habilito las irq por trasmision lista (XRDY, 4)
	
	//Coloco en el bus la condicion de START
	aux=ioread32(i2c_mem+I2C_CON);
	aux|=I2C_CON_STT;
	iowrite32(aux,i2c_mem+I2C_CON);
	
	if(wait_event_interruptible(waitqueue_tx, (tCount==numOfBytes))) //pongo a dormir hasta que la condicion evaluada sea true
	{
		return -ERESTARTSYS; //vino una señal sino devuelve cero!
	}
		
	return count_tx;
}

//Estructura file operations del diver i2c
struct file_operations i2c_fops =
{
  .owner= THIS_MODULE,
  .open= i2c_open,
  .unlocked_ioctl= i2c_ioctl,
  .read= i2c_read,
  .write= i2c_write,
  .release= i2c_release,  
};

//Dispositivo de caracteres del driver i2c
static struct cdev i2c_cdev;

//Funcion para asignar permisos de usuario al DRIVER!
static int my_dev_uevent(struct device *dev, struct kobj_uevent_env *env)
{
  add_uevent_var(env, "DEVMODE=%#o", 0666);
  return 0;
}

static int i2c_init( void )
{
/*Pido al kernel direcciones virtuales que mapeen a las direcciones fisicas del modulo I2C1
 NO hago el request_mem_region() ya que esta ocupado por el driver original... */
  if ((	i2c_mem = ioremap(I2C1_BASE_ADDR, I2C1_LENGTH)) == NULL)
    {
        printk(KERN_ERR "Error al mapear el puerto I2C1\n");
        return -1;
    }
	
  /*Ubico una region de device de caracteres para el modulo I2C*/
  if (alloc_chrdev_region( &dev, 0, 1, "i2c_td3" ) < 0)
  {  
    printk( KERN_ALERT "No se puede ubicar la region\n" );
    return -1;
  }

  /*Creo la clase*/
  if ( (cl=class_create( THIS_MODULE, "chardev" )) == NULL )
  {
    printk( KERN_ALERT "No se pudo crear la clase\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  
  // Asignar el callback que pone los permisos en /dev/i2c_td3
  cl -> dev_uevent = my_dev_uevent;
  
  /*Creo el dispositivo en el kernel el dispositivo i2c*/
  if( device_create( cl, NULL, dev, NULL, "i2c_td3" ) == NULL )
  {
    printk( KERN_ALERT "No se puede crear el device driver\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    class_destroy(cl);
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  
  /*Inicializo el dispositivo de caracteres y su correspondiente estructura file operations*/
  cdev_init(&i2c_cdev, &i2c_fops);
  
  i2c_cdev.owner = THIS_MODULE;
  i2c_cdev.ops = &i2c_fops;
  
  /*Lo agrego al kernel*/
  if (cdev_add(&i2c_cdev, dev, 1) == -1)
  {
    printk( KERN_ALERT "No se pudo agregar el device driver e i2c al kernel\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    device_destroy( cl, dev );
    class_destroy( cl );
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  
  /*Como no uso device tree, necesito obtener un puntero al dominio del controlador de interrupciones (INTC).
	Para ello, obtengo la información del dominio a partir de la interrupcion 16 que siempre aparece en el kernel.*/
  struct irq_data *irq_data = irq_get_irq_data(16); 
  
  /*Luego, con este dominio, creo un mapeo a numero de interrupcion de linux, de la interrupcion de HW del INTC correspondiente
    a la linea de interrupcion del modulo I2C!*/
  virq=irq_create_mapping(irq_data->domain,I2C1_IRQ); //mapeo la IRQ de HW a linux

  /*Finalmente, pido al kernel que me de la interrupcion*/
  if(request_irq(virq,(irq_handler_t)i2c_td3_irq_handler,IRQF_TRIGGER_FALLING,"i2c_td3_handler",NULL)!=0)
  {
	  printk( KERN_ALERT "No se pudo obtener la linea de IRQ solicitada!\n" );
	  cdev_del(&i2c_cdev);
	  device_destroy( cl, dev );
	  class_destroy( cl );
      unregister_chrdev_region( dev, 1 );
	  return -1;
  }
  
  //Inicializo las colas de espera de tx ,rx y ardy.
  init_waitqueue_head(&waitqueue_rx);
  init_waitqueue_head(&waitqueue_tx);
  init_waitqueue_head(&waitqueue_ardy);
	  
  printk(KERN_ALERT "Driver I2C_TD3 instalado con numero mayor %d y numero menor %d y se leyo %d\n",
	 MAJOR(dev), MINOR(dev),i2c_mem);
	 	 
  return 0;
}

static void i2c_exit( void )
{
    // Borrar lo asignado para no tener memory leak en kernel
  free_irq(virq,NULL);
  cdev_del(&i2c_cdev);
  device_destroy( cl, dev );
  class_destroy( cl );
  unregister_chrdev_region(dev, 1);
  iounmap(i2c_mem); //remuevo el mapeo
  printk(KERN_ALERT "Driver I2C_TD3 desinstalado.\n");
}

static irq_handler_t  i2c_td3_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs)
{
	unsigned int status = ioread32(i2c_mem+I2C_IRQSTATUS); //leo el estado actual de las interrupciones
	
	iowrite32((status & (~(I2C_IRQ_RRDY | I2C_IRQ_XRDY))),i2c_mem+I2C_IRQSTATUS); //limpio TODAS las interrupciones menos XRDY y RRDY
	
	if(status & I2C_IRQ_RRDY) //interrupcion por RDRY
	{
		dataR[rCount]=(unsigned char)ioread32(i2c_mem+I2C_DATA); //leo lo recibido.
		rCount++;
		iowrite32(I2C_IRQ_RRDY,i2c_mem+I2C_IRQSTATUS); //limpio la interrupción.
		
		if(rCount==numOfBytes) //ya recibí el total!
		{
			iowrite32(I2C_IRQ_RRDY,i2c_mem+I2C_IRQENABLE_CLR); //deshabilito la interrupción de recepción.
			
			unsigned int aux=ioread32(i2c_mem+I2C_CON);
			aux|=I2C_CON_STP;//condicion de STOP
			iowrite32(aux,i2c_mem+I2C_CON);
			
			wake_up_interruptible(&waitqueue_rx);
			
		}
	}
	
	if(status & I2C_IRQ_XRDY) //interrupcion por XRDY
	{
		iowrite32(dataT[tCount],i2c_mem+I2C_DATA);
		tCount++;
		iowrite32(I2C_IRQ_XRDY,i2c_mem+I2C_IRQSTATUS); //limpio el flag de interrupcion
		
		if(tCount==numOfBytes)
		{
			iowrite32(I2C_IRQ_XRDY,i2c_mem+I2C_IRQENABLE_CLR); //deshabilito la interrupcion de transmision
			
			unsigned int aux=ioread32(i2c_mem+I2C_CON);
			aux|=I2C_CON_STP;//condicion de STOP
			iowrite32(aux,i2c_mem+I2C_CON);
			
			wake_up_interruptible(&waitqueue_tx);
		}
	}
	
	if(status & I2C_IRQ_ARDY) //interrupcion por Access RDY
	{
		printk(KERN_ALERT "Pude entrar a la int ardy \n");
		iowrite32(I2C_IRQ_ARDY,i2c_mem+I2C_IRQSTATUS); //limpio el flag de estado
		iowrite32(I2C_IRQ_ARDY,i2c_mem+I2C_IRQENABLE_CLR); //deshabilito la interrupcion de ARDY
		accessRdy=1; //pongo en 1 el flag accessRdy
		wake_up_interruptible(&waitqueue_ardy); //despierto la cola correspondiente
	}
		
	return (irq_handler_t) IRQ_HANDLED;
 
}

module_init(i2c_init);
module_exit(i2c_exit);
