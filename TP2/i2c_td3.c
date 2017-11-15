// Hecho por Dario Alpern

// Escribir un caracter al device driver.
// Luego en las siguientes lecturas el device driver
// genera caracteres con codigo ASCII creciente.

// Adicionalmente el driver genera el nodo /dev/letras
// durante la instalacion (insmod) con permisos 0666 sin
// necesidad del comando mknod ni chmod. El nodo se borra
// automaticamente al desinstalar (rmmod) el device driver.

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
#include <linux/irqdomain.h>
#include <linux/interrupt.h> //para poder usar interrupciones!

#define I2C1_BASE_ADDR 0x4802A000
#define I2C1_LENGTH 0x1000

#define I2C_IRQSTATUS_RAW 0x24
#define I2C_IRQSTATUS 0x28
#define I2C_IRQENABLE_SET 0x2C
#define I2C_IRQENABLE_CLR 0x30
#define I2C_CON 0xA4
#define I2C_SA 0xAC
#define I2C_PSC 0xB0
#define I2C_SCLL 0xB4
#define I2C_SCLH 0xB8
#define I2C_CNT 0x98
#define I2C_DATA 0x9C
#define I2C_BUFSTAT 0xC0

#define I2C1_IRQ (71)


#define CM_PER_I2C1_CLKCTRL 0x44E00048
#define CM_PER_L4LS_CLKCTRL 0x44E00000

#define SOC_CONTROL_REGS 0x44E10000
#define CONTROL_CONF_SPI0_D1  0x958
#define CONTROL_CONF_SPI0_CS0   0x95C

#define I2C_SLAVE 0x0703 //define para setear la direccion del esclavo. 

MODULE_LICENSE("Dual BSD/GPL");
MODULE_AUTHOR("de Brito Gonzalo");
MODULE_DESCRIPTION("Driver I2C para BBB");



static dev_t dev;
static struct class *cl; 

static void __iomem* i2c_mem;

static wait_queue_head_t letras_waitqueue;

static irq_handler_t  i2c_td3_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs);
 

static int i2c_open(struct inode *i, struct file *f)
{
	printk(KERN_ALERT "ingreso al open \n");
	unsigned int a=0;
	unsigned int b=0;
	
	void __iomem* p1 = ioremap(CM_PER_I2C1_CLKCTRL,4);
	void __iomem* p2 = ioremap(CM_PER_L4LS_CLKCTRL,4);
	void __iomem* p3 = ioremap(SOC_CONTROL_REGS+CONTROL_CONF_SPI0_D1,4);
	void __iomem* p4 = ioremap(SOC_CONTROL_REGS+CONTROL_CONF_SPI0_CS0,4);
	
	a=ioread32((unsigned int*) p1);
	iowrite32((a | (0x02) & (~(0x01))),p1);
		
	a=ioread32((unsigned int*) p2);
	iowrite32((a | (0x02) & (~(0x01))),p2);
	
	a= ((1<<4) | (1<<5) | (1<<6) | (0x02));
	/*Seteo: 1) Pullup 2)Pin como receiver enabled, 3)Slewrate lento, 4) MUX 2, es decir I2C SDA y SCL */
	iowrite32(a,p3);
	iowrite32(a,p4);
	
	//desmapeo los dos registros solicitados antes
	iounmap(p1);
	iounmap(p2);
	iounmap(p3);
	iounmap(p4);
	
	unsigned int aux = ioread32(i2c_mem+I2C_CON); //resguardo el valor original del registro de control
	aux &= (~(1 << 15)); //deshabilito el modulo I2C_EN = 0
	iowrite32(aux,i2c_mem+I2C_CON); //grabo el valor ya modificado
	
	iowrite32 (0x03,i2c_mem+I2C_PSC); //escribo un 3, de esta manera dividirá por 4 (48Mhz/12Mhz = 4).
 	if( ioread32(i2c_mem+0xb0) != 0x03) //leo para verificar que se escribio bien
	{
		printk(KERN_ALERT "Error al escribir el preescaler \n");
		return -1;
	}
	
	iowrite32(0x71,i2c_mem+I2C_SCLL); // 12Mhz (Clock del modulo) / 0.1Mhz (100khz, clock del i2c) = 120 - 7 =113. El 7 lo pide el micro (ver datasheet) 
	if( ioread32(i2c_mem+I2C_SCLL) != 0x71)
	{
		printk(KERN_ALERT "Error al escribir SCLL \n");
		return -1;
	}
	
	iowrite32(0x73,i2c_mem+I2C_SCLH); //igual que en el anterior pero solo se resta 5 = 115 = 0x73
	if( ioread32(i2c_mem+I2C_SCLH) != 0x73)
	{
		printk(KERN_ALERT "Error al escribir SCLH \n");
		return -1;
	}
	
	aux = ioread32(i2c_mem+I2C_CON); //resguardo el valor original del registro de control
	aux |= (1 << 15); //Habilito el modulo I2C_EN = 0
	iowrite32(aux,i2c_mem+I2C_CON); //grabo el valor ya modificado
	
	
	printk(KERN_ALERT "Modulo HW I2C inicializado correctamente");
    return 0;
}
static int i2c_release(struct inode *i, struct file *f)
{
	printk(KERN_ALERT "Se hace el release del i2c \n");
    return 0;
}


long i2c_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
	printk(KERN_ALERT "Ingreso al IOCTL I2C_TD3\n");
	
	if(cmd == I2C_SLAVE)
	{
		iowrite32((arg & (0x7F)),i2c_mem+I2C_SA); //escribo la slave address dejando solo los 7 LSB con algo y el resto limpio (ya que usare addr de 7bits)
		if( ioread32(i2c_mem+I2C_SCLH) != 0x73)
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
/*static int i2c_ioctl(struct inode *n, struct file *fp, unsigned int a, unsigned long b)
{
	return 0;
}*/

static ssize_t i2c_read(struct file *file, char *buf, size_t count, loff_t *nose)
{
	
  /*ioread32
  char buffer[500];
  int i;
  int totalcount = count;                       // Si la cantidad de bytes a leer
  if (totalcount > sizeof(buffer))              // es muy elevada, truncar a la
  {                                             // longitud del buffer interno.
    totalcount = sizeof(buffer);
  }
  while (siguienteLetra == 'a')                 // Esperar hasta que otro proceso
  {					      // cambie la siguiente letra.
    if (wait_event_interruptible(letras_waitqueue, (siguienteLetra != 'a')))
    {
      return -ERESTARTSYS;          // Vino una senial
    }
  }
  for (i=0; i<totalcount; i++)	              // Por cada caracter pedido desde la
  {					      // aplicacion
    *(buffer+i) = siguienteLetra;         // Generar caracter.
    if (++siguienteLetra > 'Z')           // Cambiar a la siguiente letra.
    {
      siguienteLetra = 'A';
    }
  }
  __copy_to_user(buf, buffer, totalcount);      // Copiar al buffer de la aplicacion.
  
  return totalcount;                            // Indicar cantidad de bytes leidos.*/
  return 1;
}
	
static ssize_t i2c_write(struct file *file, const char *buf,size_t count, loff_t *nose)
{
	printk(KERN_ALERT "Escribi en el driver I2C... aparentemente :S \n");
	
	unsigned aux=0;
	unsigned i=0;
	unsigned char buffer[100];
	
	iowrite32(0x48,i2c_mem+I2C_SA); //seteo la direccion del esclavo
	
	
	aux=ioread32(i2c_mem+I2C_CON);
	aux|=(1<<10); //lo coloco en MASTER.
	aux|=(1<<9); //lo coloco en TX
	iowrite32(aux,i2c_mem+I2C_CON);
		
	aux=ioread32(i2c_mem+I2C_CON);	
	aux&=(~(1<<9)); // paso a RX.
	iowrite32(aux,i2c_mem+I2C_CON);	

	iowrite32(0x02,i2c_mem+I2C_CNT); //seteo la cuenta de recepcion en 2
	
	while(ioread32(i2c_mem+I2C_IRQSTATUS_RAW) & (1<<12)); //se queda aca mientras esta en busy
	
	iowrite32((1<<3),i2c_mem+I2C_IRQENABLE_SET); //seteo la interrupcion por RDRY
	
	aux=ioread32(i2c_mem+I2C_CON);
	aux|=(1<<0);//condicion de start
	iowrite32(aux,i2c_mem+I2C_CON);
	
	
	for(i=0; i<2;i++) //voy a recibir 2 bytes
	{
		printk(KERN_ALERT "El valor leido en la vuelta %d es %x bufstat %x",i,ioread32(i2c_mem+I2C_IRQSTATUS_RAW),ioread32(i2c_mem+I2C_BUFSTAT));
		while(!(ioread32(i2c_mem+I2C_IRQSTATUS_RAW) & (1<<3))); //mientras el RRDY este en 0 lo sigo polleando.
		//printk(KERN_ALERT "Al menos una vez pase el while");
		//iowrite32((1<<7),i2c_mem+I2C_IRQSTATUS_RAW);
		buffer[i]=ioread32(i2c_mem+I2C_DATA); //leo la información
	}
	
	aux=ioread32(i2c_mem+I2C_CON);
	aux|=(1<<1); //seteo el bit de stop
	iowrite32(aux,i2c_mem+I2C_CON);
	
	unsigned int temp=0;
	temp= (buffer[0] << 3)+(buffer[1] >> 5);
	temp= temp/8;
	printk(KERN_ALERT "La temperatura es %u \n",temp);
	
	return temp;
 /*char letraAnterior = siguienteLetra;
  __copy_from_user(&siguienteLetra, buf, 1);        // Obtener caracter de la aplicacion.
  if (letraAnterior == 'a' && siguienteLetra != 'a')
  {
    wake_up_interruptible(&letras_waitqueue); // Despertar proceso que lee.
  }
  return count;                                     // Indicar cantidad de bytes escritos.
*/
}

struct file_operations i2c_fops =
{
  .owner= THIS_MODULE,
  .open= i2c_open,
  .unlocked_ioctl= i2c_ioctl,
  .read= i2c_read,
  .write= i2c_write,
  .release= i2c_release,  
};

static struct cdev i2c_cdev;

static int my_dev_uevent(struct device *dev, struct kobj_uevent_env *env)
{
  add_uevent_var(env, "DEVMODE=%#o", 0666);
  return 0;
}

static int i2c_init( void )
{
	//Puedo prescindir de esta parte... 
  /*if(request_mem_region(I2C1_BASE_ADDR,I2C1_LENGTH,"i2c_td3")==NULL)
  {
	  printk(KERN_ALERT "Region de memoria solicitada NO DISPONIBLE \n");
	  return -1;
  }*/
  
  if ((	i2c_mem = ioremap(I2C1_BASE_ADDR, I2C1_LENGTH)) == NULL)
    {
        printk(KERN_ERR "Error al mapear el puerto I2C1\n");
        return -1;
    }
  
  if (alloc_chrdev_region( &dev, 0, 1, "i2c_td3" ) < 0)
  {  
    printk( KERN_ALERT "No se puede ubicar la region\n" );
    return -1;
  }

  if ( (cl=class_create( THIS_MODULE, "chardev" )) == NULL )
  {
    printk( KERN_ALERT "No se pudo crear la clase\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  
  // Asignar el callback que pone los permisos en /dev/letras
  //cl -> dev_uevent = my_dev_uevent;
  if( device_create( cl, NULL, dev, NULL, "i2c_td3" ) == NULL )
  {
    printk( KERN_ALERT "No se puede crear el device driver\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    class_destroy(cl);
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  cdev_init(&i2c_cdev, &i2c_fops);
  
  i2c_cdev.owner = THIS_MODULE;
  i2c_cdev.ops = &i2c_fops;
  
  if (cdev_add(&i2c_cdev, dev, 1) == -1)
  {
    printk( KERN_ALERT "No se pudo agregar el device driver e i2c al kernel\n" );
    // Borrar lo asignado para no tener memory leak en kernel
    device_destroy( cl, dev );
    class_destroy( cl );
    unregister_chrdev_region( dev, 1 );
    return -1;
  }
  
  struct irq_data *irq_data = irq_get_irq_data(16); //tiro un valor de interrupcion conocida para obtener el dominio

  unsigned int virq=irq_create_mapping(irq_data->domain,I2C1_IRQ); //mapeo la IRQ de HW a linux
  printk( KERN_ALERT "El valor de VIRQ es %d!\n",virq );
  
  if(request_irq(virq,(irq_handler_t)i2c_td3_irq_handler,IRQF_TRIGGER_FALLING,"i2c_td3_handler",NULL)!=0)
  {
	  printk( KERN_ALERT "No se pudo obtener la linea de IRQ solicitada!\n" );
	  cdev_del(&i2c_cdev);
	  device_destroy( cl, dev );
	  class_destroy( cl );
      unregister_chrdev_region( dev, 1 );
	  return -1;
  }
	  
  
	//iowrite32(0x19,i2c_mem+0xb0);
  printk(KERN_ALERT "Driver I2C_TD3 instalado con numero mayor %d y numero menor %d y se leyo %d\n",
	 MAJOR(dev), MINOR(dev),i2c_mem);
	 
	 
  return 0;
}

static void i2c_exit( void )
{
    // Borrar lo asignado para no tener memory leak en kernel
  free_irq(I2C1_IRQ,NULL);
  cdev_del(&i2c_cdev);
  device_destroy( cl, dev );
  class_destroy( cl );
  unregister_chrdev_region(dev, 1);
  iounmap(i2c_mem); //remuevo el mapeo
  //release_mem_region(I2C1_BASE_ADDR,I2C1_LENGTH); //devuelvo la memoria al kernel
  printk(KERN_ALERT "Driver I2C_TD3 desinstalado.\n");
}

static irq_handler_t  i2c_td3_irq_handler(unsigned int irq, void *dev_id, struct pt_regs *regs)
{
	static int veces = 0;
	printk(KERN_ALERT "Se ejecuto la interrupcion %d veces \n",veces);
	veces++;
	iowrite32((1<<3),i2c_mem+I2C_IRQSTATUS);
	if(veces > 5)
	{iowrite32((1<<3),i2c_mem+I2C_IRQENABLE_CLR);} //luego de 5 entradas deshabilito la interrupción
	return (irq_handler_t) IRQ_HANDLED;
 
}

module_init(i2c_init);
module_exit(i2c_exit);
