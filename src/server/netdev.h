/* Interface from NIC device to the LWWire server */

/* Read next frame, and return address to buffer and length of that buffer */ 
int dev_read(unsigned char **bufptr);

/* Write bytes to buffer */
void dev_write(unsigned char *buf, int len);

/* Initialize device */
int dev_init( char *devname );

void dev_flush( void );

