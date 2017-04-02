/*
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 */

/*
  Original source: a Gist from
  https://gist.github.com/austinmarton/2862515

  modified by Brett Gordon

*/

#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <net/if.h>
#include <netinet/ether.h>


#define ETHER_TYPE	0x6809

#define DEFAULT_IF	"eth0"
#define BUF_SIZ		1500
#define DWDATA          buf + 18

uint8_t buf[BUF_SIZ];
struct ifreq if_mac;    /* get mac addr */
struct ifreq if_idx;    /* get index no of device */
uint8_t broadcast[] = { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
uint8_t *myaddr = (uint8_t *)if_mac.ifr_hwaddr.sa_data;
uint8_t *cp = DWDATA;
struct ether_header *eh = (struct ether_header *) buf;
struct sockaddr_ll addr; /* SOCK_RAW still needs this */
int sockfd;
char default_data[]="This is a default string!";

void addrcpy( void *dest, const void *src ){
    memcpy( dest, src, 6);
}

int addrcmp( const void *s1, const void *s2 ){
    return memcmp( s1, s2, 6);
}

void sendb( void *buff, int len ){
    memcpy( cp, buff, len );
    cp += len;
}

void flush( void ){
    int numbytes = cp - buf;
    /* make outgoing destination the incoming source */
    addrcpy( eh->ether_dhost, eh->ether_shost );
    /* setup addr struct */
    addr.sll_ifindex = if_idx.ifr_ifindex;
    addr.sll_halen = ETH_ALEN;
    addrcpy( addr.sll_addr, eh->ether_shost );
    /* and make source = our MAC */
    addrcpy( eh->ether_shost, myaddr );
    /* send a response */
    buf[14] = 0x01;
    /* set dw data length */
    *(uint16_t *)&buf[16] = htons(numbytes - 18);
    /* send to linux */
    numbytes = sendto(sockfd, buf, numbytes, 0,
		      (struct sockaddr *)&addr, sizeof(struct sockaddr_ll) );
    if( numbytes < 0 ) perror("sendto");

    /* Print packet */
    printf("\tData:");
    int i;
    for (i=0; i<numbytes; i++) printf("%02x:", buf[i]);
    printf("\n");
    cp = DWDATA;
}

int main(int argc, char *argv[])
{
	int ret, i;
	int sockopt;
	ssize_t numbytes;
	struct ifreq ifopts;	/* set promiscuous mode */

	char ifName[IFNAMSIZ];

	/* Get interface name */
	if (argc > 1)
		strcpy(ifName, argv[1]);
	else
		strcpy(ifName, DEFAULT_IF);

	/* Open PF_PACKET socket, listening for EtherType ETHER_TYPE */
	if ((sockfd = socket(PF_PACKET, SOCK_RAW, htons(ETHER_TYPE))) == -1) {
		perror("listener: socket");
		return -1;
	}

	/* Get the index of the interface to send on */
	memset(&if_idx, 0, sizeof(struct ifreq));
	strncpy(if_idx.ifr_name, ifName, IFNAMSIZ-1);
	if (ioctl(sockfd, SIOCGIFINDEX, &if_idx) < 0)
	    perror("SIOCGIFINDEX");

	/* Get the MAC address of the interface to send on */
	memset(&if_mac, 0, sizeof(struct ifreq));
	strncpy(if_mac.ifr_name, ifName, IFNAMSIZ-1);
	if (ioctl(sockfd, SIOCGIFHWADDR, &if_mac) < 0)
	    perror("SIOCGIFHWADDR");


	/* Set interface to promiscuous mode - do we need to do this every time? */
	strncpy(ifopts.ifr_name, ifName, IFNAMSIZ-1);
	ioctl(sockfd, SIOCGIFFLAGS, &ifopts);
	ifopts.ifr_flags |= IFF_PROMISC;
	ioctl(sockfd, SIOCSIFFLAGS, &ifopts);
	/* Allow the socket to be reused - incase connection is closed prematurely */
	if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &sockopt, sizeof sockopt) == -1) {
		perror("setsockopt");
		close(sockfd);
		exit(EXIT_FAILURE);
	}
	/* Bind to device */
	if (setsockopt(sockfd, SOL_SOCKET, SO_BINDTODEVICE, ifName, IFNAMSIZ-1) == -1)	{
		perror("SO_BINDTODEVICE");
		close(sockfd);
		exit(EXIT_FAILURE);
	}

repeat:	printf("listener: Waiting to recvfrom...\n");
	numbytes = recvfrom(sockfd, buf, BUF_SIZ, 0, NULL, NULL);
	printf("listener: got packet %lu bytes\n", numbytes);

	/* Check the packet is for me */
	if (
	     addrcmp( eh->ether_dhost, broadcast ) &&
	     addrcmp( eh->ether_dhost, myaddr )
	    ){
	    goto repeat;
	}

	/* Print packet */
	printf("\tData:");
	for (i=0; i<numbytes; i++) printf("%02x:", buf[i]);
	printf("\n");

	sendb( default_data, strlen(default_data) );
	flush();

	/* Print packet */
	printf("\tData:");
	for (i=0; i<numbytes; i++) printf("%02x:", buf[i]);
	printf("\n");

	goto repeat;

	close(sockfd);
	return ret;
}
