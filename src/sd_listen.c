/*
 * Copyright (c) 1995,1996 University College London
 * Copyright (c) 1994 Tom Pusateri, J.P.Knight
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by the Computer Science
 *      Department at University College London
 * 4. Neither the name of the University nor of the Department may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE UNIVERSITY OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */


/*
 * A few parts of this code were originally written by
 * Tom Pusateri (pusateri@cs.duke.edu)
 * J.P.Knight@lut.ac.uk
 * as part of sd_listen.c
 *
 * not that much of the original remains now...  MJH
 */


#define MULTICAST
/*#define DEBUG*/

#include <locale.h>
#include <signal.h>
#ifndef WIN32
#include <fcntl.h>
#endif
#include <sys/types.h>
#include <sys/stat.h>
#include <setjmp.h>
#include <locale.h>

#include "sdr.h"
#include "prototypes.h"
#include "prototypes_crypt.h"

#define MAXMEDIA 10
#define MAXPHONE 10
#define MAXBW 10
#define MAXKEY 10
#define MAXTIMES 10
#define MAXRPTS 10
#define MAXVARS 20
#define MAX_SOCKS 20
#define TMPSTRLEN 1024

extern Tcl_Interp *interp;
int gui;
int logging;

unsigned long parse_entry();
#ifdef LISTEN_FOR_SD
unsigned long sd_parse_entry();
#endif

extern int init_security();

void seedrand()
{
  struct timeval tv;
  gettimeofday(&tv, NULL);
  srandom(tv.tv_usec);
}

void remove_cr(char *str)
{
  if (str[strlen(str)-1]=='\r')
    str[strlen(str)-1]='\0';
}

int rxsock[MAX_SOCKS];
char *rx_sock_addr[MAX_SOCKS];
int rx_sock_port[MAX_SOCKS];
int no_of_rx_socks=0;
int txsock[MAX_SOCKS];
char *tx_sock_addr[MAX_SOCKS];
int no_of_tx_socks=0;
int siprxsock, siptxsock, busrxsock;
unsigned long hostaddr;
char hostname[TMPSTRLEN];
char username[TMPSTRLEN];
char sipalias[MAXALIAS];
#ifdef WIN32
unsigned int ttl=1;
unsigned char rfd2sock[512];
#else
unsigned char ttl=1;
unsigned char rfd2sock[64];
#endif
int doexit=FALSE;
int ui_visible=TRUE;
int debug1=FALSE;
jmp_buf env;

void dump(buf, buflen)
char *buf;
int buflen;
{
  if (debug1)
  {
        int i;
        unsigned char c;
        printf("Unexpected packet. Dumping...\n");
        printf("Buffer length: %d\n",buflen);
        for (i=0; i<buflen; i++) {
                c=buf[i];
#ifdef HEXDEBUG
                printf(" %02x %c", c,c);
#else
		printf("%c",c);
#endif
        }
        printf("<<<\n");
  }
}


int sd_listen(char *address, int port, int rx_sock[], int *no_of_socks, int fatal) 
{    
    struct sockaddr_in name;
    struct ip_mreq imr;
    unsigned int group;
    int s, i, one=1, zero=0;

    if (no_of_socks!=NULL)
      {
	for(i=0;i<*no_of_socks;i++)
	  if (strcmp(address, rx_sock_addr[i])==0) {return(*no_of_socks);}
      }
    else
      {
	no_of_socks=&zero;
      }

    if (*no_of_socks == MAX_SOCKS)
      return (*no_of_socks);	/*XXX Is there an appropriate error return?*/

    group = inet_addr(address);
    if((s=socket( AF_INET, SOCK_DGRAM, 0 )) < 0) {
        perror("socket");
        exit(1);
    }
    if (s >= sizeof(rfd2sock)) {
	fprintf(stderr, "socket fd too large (%d)\n", s);
	exit(1);
    }
    rx_sock[*no_of_socks] = s;
    rfd2sock[s] = *no_of_socks;
    if (debug1==TRUE)
      {
	printf("Binding socket %d to address/port %s/%d\n", s, address, port);
      }
#ifndef WIN32
    fcntl(s, F_SETFD, 1);
#endif

    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (char *)&one, sizeof(one));
#ifdef SO_REUSEPORT
    setsockopt(s, SOL_SOCKET, SO_REUSEPORT, (char *)&one, sizeof(one));
#endif

    name.sin_family = AF_INET;
#ifndef CANT_MCAST_BIND
    name.sin_addr.s_addr = group;
#else
    name.sin_addr.s_addr = INADDR_ANY;
#endif
    name.sin_port = htons(port);
    if (bind(s, (struct sockaddr *)&name, sizeof(name))) {
	if (fatal) {
	    perror("bind");
	    fprintf(stderr, "Address: %x, Port: %d\n",
		    group, port);
	    exit(1);
	} else {
	    close(s);
	    return (*no_of_socks);
	}
    }

    imr.imr_multiaddr.s_addr = group;
    imr.imr_interface.s_addr = INADDR_ANY;
    if (setsockopt(s, IPPROTO_IP, IP_ADD_MEMBERSHIP,
		   (char *)&imr, sizeof(struct ip_mreq)) < 0 ) {
        perror("setsockopt - IP_ADD_MEMBERSHIP");
        exit(1);
    }
    rx_sock_addr[*no_of_socks]=malloc(strlen(address)+1);
    strcpy(rx_sock_addr[*no_of_socks], address);
    rx_sock_port[*no_of_socks]=port;
    (*no_of_socks)++;
    return(*no_of_socks);
}

int sd_tx(char *address, int port, int *txsock, int *no_of_socks) 
{
    struct sockaddr_in name;
    unsigned int group;
    int i, zero=0;
#ifdef WIN32
    int one=1;
#endif

    if (no_of_socks!=NULL)
      {
	for(i=0;i<*no_of_socks;i++)
	  if (strcmp(address, tx_sock_addr[i])==0) {return(*no_of_socks);}
	tx_sock_addr[*no_of_socks]=malloc(strlen(address)+1);
	strcpy(tx_sock_addr[*no_of_socks],address);
      }
    else
      {
	no_of_socks=&zero;
      }

    group = inet_addr(address);
    if((txsock[*no_of_socks]=socket( AF_INET, SOCK_DGRAM, 0 )) < 0) {
        perror("socket");
        exit(1);
    }
    if (debug1==TRUE)
      {
	printf("Connecting socket %d to address/port %s/%d\n",
		txsock[*no_of_socks], address, port);
      }

#ifndef WIN32
    fcntl(txsock[*no_of_socks], F_SETFD, 1);
#else
    setsockopt(txsock[*no_of_socks], SOL_SOCKET, SO_REUSEADDR,
               (char *)&one, sizeof(one));

    memset((char*)&name, 0, sizeof(name));
    name.sin_family = AF_INET;
    name.sin_port = 0;
    name.sin_addr.s_addr = INADDR_ANY;
    if (bind(txsock[*no_of_socks], (struct sockaddr *)&name, sizeof(name))) {
        perror("bind");
        exit(1);
    }
#endif
    name.sin_family = AF_INET;
    name.sin_addr.s_addr = group;
    name.sin_port = htons(port);
    if (connect(txsock[*no_of_socks], (struct sockaddr *)&name, sizeof(struct sockaddr_in))<0)
      {
	perror("connect");
	fprintf(stderr, "Dest Address problem\n");
	exit(-1);
      }
    if (setsockopt(txsock[*no_of_socks], IPPROTO_IP, IP_MULTICAST_TTL, (char *)&ttl, 
		   sizeof(ttl))<0)
      {
	perror("setsockopt ttl");
	fprintf(stderr, "ttl: %d\n", ttl);
	exit(-1);
      }
    (*no_of_socks)++;
    return(*no_of_socks);
}

int load_cache_entry(
	ClientData dummy,
	Tcl_Interp* interp,
	int acgc,
	char** argv
)
{
    char buf[MAXADSIZE], *p, advert[MAXADSIZE];
    char sap_addr[20], trust[20];
    int sap_port, len;
    unsigned long  origsrc, src, endtime;
    char aid[80];
    char key[MAXKEYLEN], keyname[MAXKEYLEN];
    time_t t;
    int ttl;
    char *k1,*k2;
    
    strcpy(key,(const char *)"");
    strcpy(keyname,(const char *)"");

#ifdef DEBUG
    printf("loading cache file (%s): %s\n", argv[1], argv[2]);
#endif
    len=aux_load_file(buf, argv[1], argv[2]);
    if (len==0) return TCL_OK;

    if(strncmp(buf, "n=", 2)==0)
      {
	sscanf(&buf[2], "%lu %lu %lu %s %u %u %s", &origsrc, 
	       &src, &t, sap_addr, &sap_port, &ttl, trust);
	remove_cr(trust);
	k1=strchr(buf,'\n')+1;
	k2=strchr(k1, '\n')-1;
	/*not sure why we would have a cache file with a CRLF, but cope with 
	  it anyway*/
	if (strchr(k1, '\r')-1<k2) k2=strchr(k1, '\r')-1;

	if (strncmp(k1, "k=", 2)==0)
	  {
	    if ((u_int)k2>=(u_int)k1+2)
	      {
		memcpy(key, k1+2, (u_int)k2-((u_int)k1+1));
		key[(u_int)k2-((u_int)k1+1)]='\0';
	      }
	    else
	      {
		key[0]='\0';
	      }
	    p=strchr(k1, '\n')+1;
	  }
	else
	  {
	    key[0]='\0';
	    p=strchr(buf, '\n')+1;
	  }
	if(strcmp(trust,"")==0)
	  {
	    strcpy(trust, "trusted");
	  }
	if(origsrc==hostaddr) 
	  {
	    memset(advert, 0, MAXADSIZE);
	    memcpy(advert, p, strlen(p)+1);
	  }
	endtime=parse_entry(aid, p, strlen(p),  origsrc, 
			    src, sap_addr, sap_port, t, trust, key);

	if ((origsrc==hostaddr)&&(strcmp(trust,"trusted")==0)) {

/* We have the key but need the keyname for queue_ad_for_sending */
          if (strcmp(key,"")!=0) {
            if (find_keyname_by_key(key, keyname) != 0) {
#ifdef DEBUG
              printf("failed to find keyname for key %s\n",key);
#endif
              return -1;
            }
          } 
	  queue_ad_for_sending(aid, advert, INTERVAL, 
               endtime,sap_addr,sap_port,(unsigned char)ttl, keyname);
	}
      } else {
	fprintf(stderr, "sdr:corrupted cache file: %s\n", argv[1]);
      }
    return TCL_OK;
}


int main(argc, argv)
int argc;
char *argv[];
{
    int i;
    struct in_addr in;
    struct hostent *hstent;

    seedrand();
    signal(SIGINT, (void(*))clean_up_and_die);
#ifdef SIGQUIT
    signal(SIGQUIT, (void(*))clean_up_and_die);
#endif
    signal(SIGTERM, (void(*))clean_up_and_die);

    setlocale(LC_NUMERIC, "C");
    putenv("LC_NUMERIC=C");
    /*find our own address*/
    gethostname(hostname, TMPSTRLEN);
    if (hostname[0] == '\0') {
      fprintf(stderr, "gethostname failed!\n");
      exit(1);
    }
    hstent=(struct hostent*)gethostbyname(hostname);
    if (hstent == (struct hostent*) NULL) {
      fprintf(stderr, "gethostbyname failed (hostname='%s'!\n", hostname);
      exit(1);
    }
    memcpy((char *)&hostaddr, (char *)hstent->h_addr_list[0], hstent->h_length);

    /*If the version of the hostname from the lookup contains dots and
      is longer that the hostname given us by gethostname, it's
      probably a better bet*/
    if ((strchr(hstent->h_name,'.')!=NULL)&&
      (strlen(hstent->h_name)>strlen(hostname))) 
      strcpy(hostname, hstent->h_name);

    /*If the primary name of the host can't be a FQDN, try any aliases*/
    if (strchr(hostname, '.')==NULL) {
      char **a;
      for(a = hstent->h_aliases; *a != 0; a++)
      {
	if (strchr(*a,'.')!=NULL)
	{
	  strcpy(hostname, *a);
	  break;
	}
      }
    }
    
    if (strchr(hostname, '.')==NULL) {
      /*OK, none of the aliases worked. Next, we can try to look in
        /etc/resolv.conf - if this isn't Unix, this won't work*/
      FILE *dnsconf;
      dnsconf=fopen("/etc/resolv.conf", "r");
      if (dnsconf!=NULL)
      {
	struct hostent *testhstent;
	char dnsbuf[256], testbuf[256], *cp;
	/*at least the file's there...*/
	while(feof(dnsconf)==0)
	{
	  fgets(dnsbuf, 255, dnsconf);
	  cp=dnsbuf;
	  /*trim any left whitespace*/
	  while (((cp[0]==' ')||(cp[0]=='\t'))&&(cp-dnsbuf<255)) cp++;
	  if (strncmp(cp, "domain", 6)==0)
	  {
	    /*the domain is specified*/
	    cp+=6;
	    /*trim left whitespace*/
	    while (((cp[0]==' ')||(cp[0]=='\t'))&&(cp-dnsbuf<255)) cp++;
	    /*build a name to test*/
	    strcpy(testbuf, hostname);
	    strcat(testbuf, ".");
	    strcat(testbuf, cp);
	    /*remove trailing whitespace*/
	    if (strchr(testbuf, ' ')!=NULL)
	      *strchr(testbuf, ' ')='\0';
	    if (strchr(testbuf, '\t')!=NULL)
	      *strchr(testbuf, '\t')='\0';
	    
	    /*now we've got a possible name, we need to check this really
	      is our host*/
	    testhstent=(struct hostent*)gethostbyname(hostname);
	    if (testhstent != (struct hostent*) NULL) {
	      char **a;
	      for(a = testhstent->h_addr_list; *a != 0; a++)
	      {
		if(memcmp((char *)&hostaddr, 
			  (char *)testhstent->h_addr_list[0], 
			  testhstent->h_length)==0)
		{
		  /*success - the name we resolved gave the address we
		    already had*/
		  strcpy(hostname, testbuf);
		  break;
		}
	      }
	    }
	    if (strchr(hostname, '.')!=NULL) break;
	  }
	}
      }
    }

    /*Anyone got any idea what to do if we still haven't obtained a
      fully qualified domain name by this point?*/

    /*If it still doesn't contain any dots, give up and use the address*/
    in.s_addr=htonl(hostaddr);
    if (strchr(hostname, '.')==NULL)
      strcpy(hostname,(char *)inet_ntoa(in));

    hostaddr=ntohl(hostaddr);
    
    /*find the user's username*/
    strcpy(username, "noname");
#ifndef WIN32
    {
	uid_t uid=getuid();
	struct passwd* pswd=getpwuid(uid);
	if(pswd!=0)
	  strcpy(username, pswd->pw_name);
    }
#else
    {
	int nmsize = sizeof(username);
	GetUserName(username, &nmsize);
    }
#endif
    strcpy(sipalias, username);

    doexit=TRUE;
    debug1=FALSE;
    logging=FALSE;
    gui=GUI;
    for(i=1;i<argc;i++)
      {
	if(strncmp(argv[i], "-s", 3)==0)
	   {
	     doexit=FALSE;
	   }
	if(strncmp(argv[i], "-d1", 3)==0)
	   {
	     debug1=TRUE;
	   }
	if(strncmp(argv[i], "-no_gui", 7)==0)
	   {
	     gui=NO_GUI;
	     doexit=FALSE;
	   }
	if(strncmp(argv[i], "-log", 7)==0)
	   {
	     logging=TRUE;
	   }
      }


    setlocale(LC_ALL, "");
    ui_init(&argc, argv);
    initnames();


    if (gui==GUI) 
      Tcl_SetVar(interp, "gui", "GUI", TCL_GLOBAL_ONLY);
    else
      Tcl_SetVar(interp, "gui", "NO_GUI", TCL_GLOBAL_ONLY);

    if (logging==TRUE) 
      Tcl_SetVar(interp, "log", "TRUE", TCL_GLOBAL_ONLY);
    else
      Tcl_SetVar(interp, "log", "FALSE", TCL_GLOBAL_ONLY);

    if (debug1)
      Tcl_SetVar(interp, "debug1", "1", TCL_GLOBAL_ONLY);
    else
      Tcl_SetVar(interp, "debug1", "0", TCL_GLOBAL_ONLY);

#ifndef WIN32
/*Set up local conference bus to talk to local clients*/
    busrxsock=bus_listen();
    if (busrxsock!=-1)
      linksocket(busrxsock, TK_READABLE, (Tcl_FileProc*)bus_recv);
/*Alert other sdr's on this machine to the fact we're here*/
    bus_send_new_app();
#endif
/*Set up Initial Rx Socket*/
    sd_listen(SAP_GROUP, SAP_PORT, rxsock, &no_of_rx_socks, 1);

#ifdef LISTEN_FOR_SD
/*Set up compatibility Rx socket*/
    {
      int old_rx = no_of_rx_socks;

      sd_listen(OLD_SAP_GROUP, OLD_SAP_PORT, rxsock, &no_of_rx_socks, 0);
      if (old_rx == no_of_rx_socks)
	printf("warning: bind failed for SD address, so no SD compatibility\n");
    }
#endif

/*Set up Tx Socket*/
    sd_tx(SAP_GROUP, SAP_PORT, txsock, &no_of_tx_socks);
    init_bitmaps();
    ui_create_interface();

    init_security();

    /*
     * Add a filehandler for the network receive socket
     * (must be after ui_create_interface, or we don't have all the config)
     */
    for(i=0;i<no_of_rx_socks; i++)
      {
	linksocket(rxsock[i], TK_READABLE, (Tcl_FileProc*)recv_packets);
      }
/*Set up SIP socket*/
    siprxsock=sip_listen(SIP_GROUP, SIP_PORT);
#ifdef NOTDEF
    siptxsock=sip_tx_init(SIP_GROUP, SIP_PORT, (char)1);
#endif
    if (siprxsock!=-1)
      linksocket(siprxsock, TK_READABLE, (Tcl_FileProc*)sip_recv);

    Tcl_CreateCommand(interp, "load_cache_entry", load_cache_entry, 0, 0);
    Tcl_Eval(interp, "load_from_cache");

    /*register our location with a SIP server (if desired)*/
    sip_register();

#ifndef WIN32
    if (doexit==FALSE) 
      {
	XSetIOErrorHandler(xremove_interface);
	if (setjmp(env)==0) {}
#ifdef SIGRELSE
	sigrelse(SIGPIPE);
#endif
	signal(SIGPIPE, SIG_IGN);
      }
#endif
    while ((doexit==FALSE)||(Tk_GetNumMainWindows() > 0)) 
      {
	if ((ui_visible==TRUE) &&(Tk_GetNumMainWindows() > 0)) 
	  {
	    /*Normal mode of operation - with a GUI*/
	    Tcl_DoOneEvent(TCL_ALL_EVENTS);
	    ui_visible=TRUE;
	  }
	else
	  {
	    /*Silent mode of operation - no GUI, but still announce
	      and cache sessions*/
	    Tcl_DoOneEvent(TCL_FILE_EVENTS|TCL_TIMER_EVENTS);
	    ui_visible=FALSE;
	  }
      }
    Tcl_Eval(interp, "write_cache");
    clean_up_and_die();
    return(0);
}

int xremove_interface(Display *pdisp)
{
  static int done=0;
  if (done==1) return 0;
  done=1;
  remove_interface();
#ifdef SIGRELSE
  sigrelse(SIGPIPE);
#endif
#ifdef SIGPIPE
  signal(SIGPIPE, SIG_IGN);
#endif
  longjmp(env, 1);
  return 0;
}
void remove_interface()
{
  ui_visible=FALSE;
/*  Tcl_Eval(interp, "write_cache");*/
/*  signal(SIGPIPE, remove_interface);*/
}
void rebuild_interface()
{
  /*go from silect mode to normal mode*/

#ifdef SIGUSR1
  /*reset the signal handlers*/
  signal(SIGUSR1, rebuild_interface);
#endif
#ifdef NOTDEF
  signal(SIGPIPE, remove_interface);
#endif

  if (Tk_GetNumMainWindows() > 0)
    {
      /*don't try and built a UI if we already have one!*/
      return;
    }
  if(Tk_Init(interp)!=TCL_OK)
    {
      /*if we failed, stay in silent mode so we keep sessions announced*/
      fprintf(stderr, "Sdr: %s\n", interp->result);
      return;
    }
  /*rebind all the Tk stuff*/
  ui_create_interface();
  /*rebuild out interface*/
  if (Tcl_GlobalEval(interp, "build_interface first")!=TCL_OK)
    {
      fprintf(stderr, "Sdr: %s\n", interp->result);
      return;
    }
  /*persuade it to show all the sessions again*/
  if (Tcl_GlobalEval(interp, "reshow_sessions [set showwhich]")!=TCL_OK)
    {
      fprintf(stderr, "Sdr: %s\n", interp->result);
      return;
    }
}

#ifdef LISTEN_FOR_SD
void read_sd_cache()
{
    char buf[MAXADSIZE];
    char *homedir, *entry;
    char cachename[256];
    FILE *cache;

    homedir=(char *)getenv("HOME");
    sprintf(cachename, "%s/.sd_cache", homedir);
    entry=buf;
    strcpy(entry, "");
    if ((cache=fopen(cachename, "r")) == NULL) {
	return;
    }
    while(!feof(cache))
      {
	char cachedata[MAXADSIZE];
	unsigned long origsrc, src;
	time_t t;

	while(!feof(cache)&&(strncmp(cachedata, "n=", 2)!=0))
	  fgets(cachedata, MAXADSIZE, cache);
	entry=buf;
	if(!feof(cache)) 
	  {
	    fgets(entry, MAXADSIZE, cache);
	    sscanf(&cachedata[2], "%lu %lu %lu", &origsrc, &src, &t);
	  }
	while(!feof(cache)&&(strncmp(entry, "n=", 2)!=0))
	  {
	    strcat(entry, "\n");
	    entry+=strlen(entry)-1;
	    fgets(entry, MAXADSIZE, cache);
	  }
	if(strncmp(entry, "n=", 2)==0) 
	  {
	    strcpy(cachedata, entry);
	    entry[0]='\0';
	  }
	if(feof(cache)) entry[strlen(entry)-1]='\0';
	sd_parse_entry(NULL, buf, strlen(buf), origsrc, src, 
		       OLD_SAP_GROUP, OLD_SAP_PORT, t, "untrusted");
      }
  }
#endif

void recv_packets(ClientData fd)
{
    int length;
    struct sap_header *bp;
    static char buf[MAXADSIZE];
    static char debugbuf[MAXADSIZE];
    struct sockaddr_in from;
    int fromlen;
    struct timeval tv;
    unsigned long src, hfrom;
    char *data;
    int ix = rfd2sock[PTOI(fd)];

    fromlen=sizeof(struct sockaddr);
    
    if ((length = recvfrom(rxsock[ix], (char *) buf, MAXADSIZE, 0,
		       (struct sockaddr *)&from, (int *)&fromlen)) < 0) {
      perror("recv error");
      return;
    }
    if (length==MAXADSIZE) {
      /*some sneaky bugger is trying to splat the stack?*/
      if (debug1==TRUE)
	fprintf(stderr, "Warning: 2K announcement truncated\n");
    }
    gettimeofday(&tv, NULL);

    /* print session */
    bp = (struct sap_header *) buf;
    memcpy(debugbuf, buf, length);
    src = ntohl(bp->src);
    hfrom = ntohl(from.sin_addr.s_addr);

    data=(char*)bp+sizeof(struct sap_header);
    length-=sizeof(struct sap_header);
    /*sanity check*/
    if (length<30) {
      if (debug1==TRUE) 
	fprintf(stderr, 
		"unacceptably short announcement received and ignored\n");
      return;
    }

    /*Ignore announcements with later SAP versions than we can cope with*/
    if (bp->version>1) {
      if (debug1==TRUE) 
	fprintf(stderr, 
		"announcement with version>1 received and ignored\n");
      return;
    }

    /* Skip the authentication header if there is one */
    /* - We'll check this in a later version          */

    if (bp->authlen > 0) 
    {
      length -= (bp->authlen * 4);
        data += (bp->authlen * 4);
    }

    /*sanity check*/
    if (length<30) {
      if (debug1==TRUE) 
	fprintf(stderr, 
		"unacceptably short announcement received and ignored\n");
      return;
    }

    /*This version of sdr can't deal with compressed payloads*/
    if (bp->compress==1) {
      if (debug1==TRUE) 
	fprintf(stderr, 
		"compressed announcement received from %s\n",
		inet_ntoa(from.sin_addr));
#ifdef NOTDEF
      return;
#endif
    }

    if (debug1==TRUE)
      printf("SAP packet received from %s\n", inet_ntoa(from.sin_addr));

    /*parse_announcement*/
    parse_announcement(bp->enc, data, length, 
		       src, hfrom, rx_sock_addr[ix],
		       rx_sock_port[ix], tv.tv_sec);
}

static void set_time(const char* var, int i, time_t t)
{
	char buf[256];

	sprintf(buf,
          "set %s(%d) [clock format %u -format {%%d %%b %%y %%H:%%M %%Z}]",
	      var, i, (unsigned int)t);
	Tcl_GlobalEval(interp, buf);
}

/*Have to be careful when parsing the data in case someone is trying to get
  us to execute some code.  Two main things to check:
   - no Tcl commands in the incoming data can be passed to the Tcl interp
     (OK, so we shouldn't execute them there anyway, but it's safer to
     prevent it here - too easy to make mistakes in the Tcl)
   - we don't ever copy a string without rangechecking it first (particularly
     with sscanf(.."%s"..) )
*/
unsigned long parse_entry(char *advertid, char *data, int length, 
	    unsigned long src, unsigned long hfrom,
	    char *sap_addr, int sap_port, time_t t, char *trust, char *recvkey)
{
    int i;
    static char namestr[MAXADSIZE];
    char *cur, *end, *attr, *unknown, *version, *session=NULL, *desc=NULL, *orig=NULL, *chan[MAXMEDIA], 
         *media[MAXMEDIA], *times[MAXTIMES], *rpt[MAXTIMES][MAXRPTS], *uri,
         *phone[MAXPHONE], *email[MAXPHONE], *bw[MAXBW],
         *key[MAXKEY], *data2;
    int mediactr, tctr, pctr, ectr, bctr, kctr, uctr;
    char vars[MAXMEDIA][TMPSTRLEN];
    char debug=0;

    char tmpstr[TMPSTRLEN], fmt[TMPSTRLEN], proto[TMPSTRLEN],
         heardfrom[TMPSTRLEN], origsrc[TMPSTRLEN], creator[TMPSTRLEN],
         modtime[TMPSTRLEN], createtime[TMPSTRLEN], createaddr[TMPSTRLEN],
         in[TMPSTRLEN], ip[TMPSTRLEN];
    int ttl, mediattl, medialayers, code;
    int port, origlen;
    unsigned int time1[MAXTIMES], time2[MAXTIMES], rctr[MAXTIMES], timemax;
    struct in_addr source;
    struct in_addr maddr;
    struct timeval tv;

    if (data[length-1]!='\n')
    {
      if (debug1)
	fprintf(stderr, "Announcement doesn't end in LF - will try to fix it up\n");
      if (data[length-1]=='\0') 
      {
	/*someone sent the end of string character - illegal but we'll
	  accept it*/
	if (debug1)
	  fprintf(stderr, "Illegal end-of-string character present - removed!\n");
	data[length-1]='\n';
      } 
      else 
      {
	/*someone simply missed off the NL at end of the announcement*/
	/*also illegal, but again we'll be liberal in what we accept*/
	data[length]='\n';
	length++;
      }
    }

    if (debug1)
    {
      data2=(char *)malloc(length);
      memcpy(data2, data, length);
    } else {
      data2=data;
    }
    origlen=length;


    if(strncmp(data, "v=", 2)!=0)
      {
#ifdef LISTEN_FOR_SD
	if (sap_port == OLD_SAP_PORT)
	  return sd_parse_entry(advertid, data, length, src, hfrom, sap_addr,
					sap_port, t, "untrusted");
#endif

	if (length==0) return((unsigned long)-1);
	if (debug1)
	  fprintf(stderr, "No session name field\n");
	dump(data2, origlen);
	goto errorleap;
      }
    else
      {
	version=data+2;
	if ((strncmp(version, "0\n", 2)!=0)&&(strncmp(version, "0\r", 2)!=0))
	  {
	    goto errorleap;
	  }
	length-=2;
      }
    if(((end=strchr(version, 0x0a)) == NULL)||(debug == 1)) {
      if (debug1)
	fprintf(stderr, "No end to version name\n");
      dump(data2, origlen);
      goto errorleap;
    }
    *end++ = '\0';
    length -= end-version;
    source.s_addr=htonl(hfrom);
    strncpy(heardfrom, (char *)inet_ntoa(source), 16);
    source.s_addr=htonl(src);
    strncpy(origsrc, (char *)inet_ntoa(source), 16);


    i = 0;
    mediactr=0;  tctr=0;  pctr=0;  ectr=0;  bctr=0;  kctr=0;
    uctr=0; chan[0]=NULL; chan[1]=NULL; timemax=0;
    vars[0][0]='\0';
    while (length > 0) 
      {
                cur = end;
                switch (*cur) {
		case 's':
		        /* session description */
		        session = end+2;
                        if ((end=strchr(session, 0x0a)) == NULL) {
			  if (debug1) 
			  {
			    printf("Error decoding session\n");
			    printf("Failure at byte %ld\n", (long)session-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(session);
                        length -= end-cur;
                        break;

                case 'i':
                        /* print description */
                        desc = end+2;
                        if ((end=strchr(desc, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding description\n");
			    printf("Failure at byte %ld\n", (long)desc-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(desc);
                        length -= end-cur;
                        break;

                case 'u':
                        /* print description */
                        uri = end+2;
			uctr++;
                        if ((end=strchr(uri, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding URI\n");
			    printf("Failure at byte %ld\n", (long)desc-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(uri);
                        length -= end-cur;
                        break;
                case 'o':
                        /* print originator */
                        orig = end+2;
                        if ((end=strchr(orig, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding originator\n");
			    printf("Failure at byte %ld\n", (long)orig-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(orig);
                        length -= end-cur;
                        break;
                case 'e':
                        /* print originator */
			if (ectr<MAXPHONE)
			  {
			    email[ectr] = end+2;
			  }
			else
			  {
			    fprintf(stderr, "Too many email fields\n");
			    goto errorleap;
			  }
                        if ((end=strchr(email[ectr], 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding email address\n");
			    printf("Failure at byte %ld\n", (long)orig-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(email[ectr++]);
                        length -= end-cur;
                        break;
                case 'p':
                        /* print originator */
			if (pctr<MAXPHONE)
			  {
			    phone[pctr] = end+2;
			  }
			else
			  {
			    if (debug1==TRUE)
			      fprintf(stderr, "Too many phones (!)\n");
			    goto errorleap;
			  }
                        if ((end=strchr(phone[pctr], 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding originator\n");
			    printf("Failure at byte %ld\n", (long)orig-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(phone[pctr++]);
                        length -= end-cur;
                        break;

                case 'c':
                        /* print channel */
			chan[mediactr] = end+2;
                        if ((end=strchr(chan[mediactr], 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding channel\n");
			    printf("Failure at byte %ld\n", (long)chan[mediactr]-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(chan[mediactr]);
                        length -= end-cur;
                        break;
                case 'b':
                        /* print bandwidth */
			if (bctr<MAXBW)
			  {
			    bw[bctr] = end+2;
			  }
			else
			  {
			    if (debug1==TRUE)
			      fprintf(stderr, "Too many bandwidth fields\n");
			    goto errorleap;
			  }
                        if ((end=strchr(bw[bctr], 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding bandwidth\n");
			    printf("Failure at byte %ld\n", (long)bw[bctr-1]-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(bw[bctr++]);
                        length -= end-cur;
                        break;
                case 't':
                        /* print channel */
			if (tctr<MAXTIMES)
			  {
			    times[tctr] = end+2;
			  }
			else
			  {
			    if (debug1==TRUE)
			      fprintf(stderr, "Too many times\n");
			    goto errorleap;
			  }
			rctr[tctr]=0;
                        if ((end=strchr(times[tctr], 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding time\n");
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(times[tctr++]);
                        length -= end-cur;
                        break;
                case 'r':
                        /* print channel */
			if (rctr[tctr-1] < MAXRPTS)
			  {
			    rpt[tctr-1][rctr[tctr-1]] = end+2;
			  }
			else
			  {
			    if (debug1==TRUE)
			      fprintf(stderr, "Too many repeats\n");
			    goto errorleap;
			  }
                        if ((end=strchr(end+2, 0x0a)) == NULL) {
			  if (debug1)
                                printf("Error decoding time\n");
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(rpt[tctr-1][rctr[tctr-1]++]);
                        length -= end-cur;
                        break;
                case 'k':
                        /* print channel */
			if (kctr<MAXKEY)
			  {
			    key[kctr] = end+2;
			  }
			else
			  {
			    if (debug1==TRUE)
			      fprintf(stderr, "Too many keys\n");
			    goto errorleap;
			  }
                        if ((end=strchr(key[kctr], 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding key\n");
			    printf("Failure at byte %ld\n", (long)chan-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(key[kctr]++);
                        length -= end-cur;
                        break;
                case 'm':
                        /* print media */
			if (mediactr<MAXMEDIA)
			  {
			    media[++mediactr] = end+2;
			  }
			else
			  {
			    if (debug1==TRUE)
			      fprintf(stderr, "Sdr: too many media\n");
			    goto errorleap;
			  }
                        if ((end=strchr(media[mediactr], 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding media\n");
			    printf("Failure at byte %ld\n", (long)media[mediactr]-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
			strcpy(vars[mediactr], "");
			chan[mediactr]=chan[0];
                        *end++ = '\0';
			remove_cr(media[mediactr]);
                        length -= end-cur;
                        break;
                case 'a':
                        /* print format */
                        attr = end+2;
                        if ((end=strchr(attr, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding attribute\n");
			    printf("Failure at byte %ld\n", (long)attr-(long)version);
			    printf("Remaining text: %s<<<\n", attr-2);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(attr);
                        length -= end-cur;
			if ((strlen(vars[mediactr])+1+strlen(attr)) < TMPSTRLEN)
			  {
			    if (strcmp(vars[mediactr], "")!=0) strcat(vars[mediactr], "\n");
			    strcat(vars[mediactr], attr);
			  }
			else
			  {
			    if (debug1==TRUE)
			      fprintf(stderr, "sdr: too many attributes to fit in available space\n");
			  }
                        break;
		case 'n':
			/*sd cache extra data - not in packet stream!*/
			unknown = end+2;
			if (debug1==TRUE)
			  printf("decoding cache data!\n");
                        if ((end=strchr(unknown, 0x0a)) == NULL) {
			  if (debug1==TRUE)
			    {
			      printf("Error decoding cache data\n");
			      printf("Failure at byte %ld\n", (long)unknown-(long)version);
			    }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(unknown);
                        length -= end-cur;
			break;
                default:
                        /* unknown */
                        unknown = end+2;
			if (debug1)
			  printf("Warqning: unknown option - >%s<\n", end);
                        if ((end=strchr(unknown, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding unknown\n");
			    printf("Failure at byte %ld\n", (long)unknown-(long)version);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
                        length -= end-cur;
                        break;
                }
                i++;
	      }
    if (session==NULL) {
      if (debug1)
	printf("No session name field\n");
      dump(data2, origlen);
      goto errorleap;
    }

    if (orig==NULL) {
      if (debug1)
	printf("No originator field\n");
      dump(data2, origlen);
      goto errorleap;
    }

    if (desc==NULL) {
      if (debug1)
	printf("No description field\n");
      dump(data2, origlen);
      goto errorleap;
    }

    code = Tcl_GlobalEval(interp, "reset_media");
    if (code != TCL_OK)
      {
	if (debug1==TRUE)
	  fprintf(stderr, "%s\n", interp->result);
      }
    Tcl_SetVar(interp, "trust", trust, TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "recvkey", recvkey, TCL_GLOBAL_ONLY);
    splat_tcl_special_chars(session);
    Tcl_SetVar(interp, "session", session, TCL_GLOBAL_ONLY);
    splat_tcl_special_chars(desc);
    Tcl_SetVar(interp, "desc", desc, TCL_GLOBAL_ONLY);
    if (chan[0]==NULL) chan[0]=chan[1];
    if (chan[0]==NULL) {
      if (debug1==TRUE)
	fprintf(stderr, "No channel field received!\n");
      return((unsigned long)-1);
    }
    if(strlen(chan[0])>TMPSTRLEN) {
      if (debug1==TRUE)
	fprintf(stderr, "Unacceptably long channel field received\n");
      chan[0][TMPSTRLEN-1]='\0';
    }
    if (chan[0]!=NULL)
      {
	sscanf(chan[0], "%s %s %s", in, ip, tmpstr);
        if (check_net_type(in,ip)<0) return (unsigned long)-1;
	ttl=extract_ttl(tmpstr);
      }
    else
      {
	tmpstr[0]='\0';
	ttl=0;
      }
    for(i=0;i<tctr;i++)
      {
	char var[20];
	sscanf(times[i], "%u %u", &time1[i], &time2[i]);
	gettimeofday(&tv, NULL);
	if(time1[i]!=0)
	  {
	    unsigned int r;
	    time1[i]-=0x83aa7e80;
	    time2[i]-=0x83aa7e80;
	    if (time2[i]>timemax) timemax=time2[i];
	    /*Don't bother to do anything if it's already timed out*/
	    /*	if(time2[i]<tv.tv_sec) return 0;*/
	    set_time("tfrom", i, time1[i]);
	    set_time("tto", i, time2[i]);
	    sprintf(var, "starttime(%d)", i);
	    sprintf(namestr, "%u", time1[i]);
	    Tcl_SetVar(interp, var, namestr, TCL_GLOBAL_ONLY);
	    sprintf(var, "endtime(%d)", i);
	    sprintf(namestr, "%u", time2[i]);
	    Tcl_SetVar(interp, var, namestr, TCL_GLOBAL_ONLY);
	    maddr.s_addr=inet_addr(tmpstr);
	    store_address(&maddr, time2[i]);
	    for(r=0;r<rctr[i];r++)
	      {
#ifdef NOTDEF
		unsigned int interval, duration;
		char *offset;
		sscanf(rpt[i][r], "%u %u", &interval, &duration);
		offset=strchr(strchr(rpt[i][r], ' ')+1, ' ')+1;
		force_numeric(offset);
		sprintf(var, "interval(%d,%d)", i, r);
		sprintf(namestr, "%u", interval);
		Tcl_SetVar(interp, var, namestr, TCL_GLOBAL_ONLY);
		sprintf(var, "duration(%d,%d)", i, r);
		sprintf(namestr, "%u", duration);
		Tcl_SetVar(interp, var, namestr, TCL_GLOBAL_ONLY);
		sprintf(var, "offset(%d,%d)", i, r);
		Tcl_SetVar(interp, var, offset, TCL_GLOBAL_ONLY);
#endif
		sprintf(var, "repeat(%d,%d)", i, r);
		Tcl_SetVar(interp, var, rpt[i][r],  TCL_GLOBAL_ONLY);
	      }
	    sprintf(var, "rctr(%d)", i);
	    sprintf(namestr, "%d", rctr[i]);
	    Tcl_SetVar(interp, var, namestr, TCL_GLOBAL_ONLY);
	  }
	else
	  {
	    if(i!=0)
	      {
		if (debug1==TRUE)
		  fprintf(stderr, "Illegal infinite session with multiple time fields\n");
		return (unsigned long)-1;
	      }
	    strcpy(var, "tfrom(0)");
	    if(Tcl_SetVar(interp, var, "0", TCL_GLOBAL_ONLY)==NULL)
	      {
		Tcl_AddErrorInfo(interp, "\n");
		if (debug1==TRUE)
		  fprintf(stderr, interp->result);
	      }
	     strcpy(var, "tto(0)");
	    if(Tcl_SetVar(interp, var, "0", TCL_GLOBAL_ONLY)==NULL)
	      {
		Tcl_AddErrorInfo(interp, "\n");
		if (debug1==TRUE)
		  fprintf(stderr, interp->result);
	      }
	    strcpy(var, "rctr(0)");
	    Tcl_SetVar(interp, var, "0", TCL_GLOBAL_ONLY);
	    strcpy(var, "starttime(0)");
	    Tcl_SetVar(interp, var, "0", TCL_GLOBAL_ONLY);
	    strcpy(var, "endtime(0)");
	    Tcl_SetVar(interp, var, "0", TCL_GLOBAL_ONLY);
            maddr.s_addr=inet_addr(tmpstr);
            store_address(&maddr, 0);
	  }
      }
    Tcl_SetVar(interp, "multicast", tmpstr, TCL_GLOBAL_ONLY);

    /*Originator field*/
    splat_tcl_special_chars(orig);
    if (strlen(orig)>TMPSTRLEN) {
      if (debug1==TRUE)
	fprintf(stderr, "Unacceptably long originator field received\n");
      orig[TMPSTRLEN-1]='\0';
    };
    sscanf(orig, "%s %s %s %s %s %s", creator, createtime, modtime, in, ip, 
	   createaddr);
    if (check_net_type(in,ip)<0) return (unsigned long)-1;
    Tcl_SetVar(interp, "creator", creator, TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "modtime", modtime, TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "createtime", createtime, TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "createaddr", createaddr, TCL_GLOBAL_ONLY);


    sprintf(namestr, "%s%s%s", creator, createtime, createaddr);

    /*Create a hash of originator data as advert ID*/
    Tcl_VarEval(interp, "get_aid ", namestr, NULL);
    sprintf(namestr, "%s", interp->result);

    if (advertid!=NULL)
      strcpy(advertid, namestr);
    Tcl_SetVar(interp, "advertid", namestr, TCL_GLOBAL_ONLY);

    Tcl_SetVar(interp, "source", origsrc, TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "heardfrom", heardfrom,  TCL_GLOBAL_ONLY);
    sprintf(namestr,
       "set timeheard [clock format %u -format {%%d %%b %%y %%H:%%M %%Z}]",
	    (unsigned int)t);
    Tcl_GlobalEval(interp, namestr);

    if(uctr>0)
      {
	splat_tcl_special_chars(uri);
	Tcl_SetVar(interp, "uri", uri, TCL_GLOBAL_ONLY);
      }
    for(i=0;i<pctr;i++)
      {
        sprintf(namestr,"phone(%d)", i);
	splat_tcl_special_chars(phone[i]);
        Tcl_SetVar(interp, namestr, phone[i], TCL_GLOBAL_ONLY);
      }
    for(i=0;i<ectr;i++)
      {
        sprintf(namestr,"email(%d)", i);
	splat_tcl_special_chars(email[i]);
        Tcl_SetVar(interp, namestr, email[i], TCL_GLOBAL_ONLY);
      }
    for(i=0;i<bctr;i++)
      {
        sprintf(namestr,"bw(%d)", i);
        Tcl_SetVar(interp, namestr, bw[i], TCL_GLOBAL_ONLY);
      }
    if(kctr>0)
      {
	/*tricky one here - have to be careful in the TCL 'cause we can't
          splat Tcl special characters here! - at least issue a warning*/
	warn_tcl_special_chars(key[0]);
	Tcl_SetVar(interp, "key", key[0], TCL_GLOBAL_ONLY);
      }
    splat_tcl_special_chars(vars[0]);
    Tcl_SetVar(interp, "sessvars", vars[0],  TCL_GLOBAL_ONLY);
    for (i=1; i<=mediactr; i++) {
      /*this check is to ensure we don't overfill anything in the following
        scanf*/
      if(strlen(media[i])>TMPSTRLEN) {
	if (debug1==TRUE)
	  fprintf(stderr, "Unacceptably long media field received\n");
	media[i][TMPSTRLEN-1]='\0';
      }
      sscanf(media[i], "%s %d %s %s", tmpstr, &port, proto, fmt);
      Tcl_SetVar(interp, "media", tmpstr, TCL_GLOBAL_ONLY);
      splat_tcl_special_chars(vars[i]);
      Tcl_SetVar(interp, "vars", vars[i],  TCL_GLOBAL_ONLY);
      sprintf(namestr, "%d", port);
      Tcl_SetVar(interp, "port", namestr, TCL_GLOBAL_ONLY);
      splat_tcl_special_chars(proto);
      Tcl_SetVar(interp, "proto", proto, TCL_GLOBAL_ONLY);
      splat_tcl_special_chars(fmt);
      Tcl_SetVar(interp, "fmt", fmt, TCL_GLOBAL_ONLY);
      if(strlen(chan[i])>100) {
	if (debug1==TRUE)
	  fprintf(stderr, "Unacceptably long channel field received\n");
	chan[i][100]='\0';
      }
      sscanf(chan[i], "%s %s %s", in, ip, tmpstr);
      if (check_net_type(in,ip)<0) return (unsigned long)-1;
      medialayers=extract_layers(tmpstr);
      mediattl=extract_ttl(tmpstr);
      if (mediattl>ttl) ttl=mediattl;
      sprintf(namestr, "%d", mediattl);
      Tcl_SetVar(interp, "mediattl", namestr, TCL_GLOBAL_ONLY);
      sprintf(namestr, "%d", medialayers);
      Tcl_SetVar(interp, "medialayers", namestr, TCL_GLOBAL_ONLY);
      Tcl_SetVar(interp, "mediaaddr", tmpstr, TCL_GLOBAL_ONLY);

      code = Tcl_GlobalEval(interp, "set_media");
      if (code != TCL_OK)
	{
	  if (debug1==TRUE)
	    fprintf(stderr, "set_media[%d] for session %s:\n%s\n", i, session,
			    interp->result);
	}
    }

    sprintf(namestr, "%d", ttl);
    Tcl_SetVar(interp, "recvttl", namestr, TCL_GLOBAL_ONLY);

    Tcl_SetVar(interp, "recvsap_addr", sap_addr, TCL_GLOBAL_ONLY);
    sprintf(namestr, "%d", sap_port);
    Tcl_SetVar(interp, "recvsap_port", namestr, TCL_GLOBAL_ONLY);

    code = Tcl_GlobalEval(interp, "add_to_list");
    if (code != TCL_OK) 
      {
	if (debug1==TRUE)
	  fprintf(stderr, "add_to_list failed for session %s:\n%s\n",
			 session, interp->result);
      }
    return timemax;
errorleap:
    return 0;
}


#ifdef LISTEN_FOR_SD
unsigned long sd_parse_entry(char *advertid, char *data, int length, 
	    unsigned long src, unsigned long hfrom,
	    char *sap_addr, int sap_port, time_t t, char *trust)
{
    char heardfrom[256], origsrc[256];
    int i;
    int origlen;
    char namestr[2048];
    char tmpstr[2048];
    char mcaddr[256];
    char *cur, *end, *session, *attr, *unknown, *desc, *orig;
    char *chan, *media[MAXMEDIA];
    char *format[MAXMEDIA];
    char vars[MAXMEDIA][MAXVARS];
    char username[255];
    struct in_addr source;
    struct in_addr maddr;
    struct tm *tms;
    int ttl, port1, port2, mediactr, code;
    unsigned int aid, time1, time2;

    if (strncmp(data, "s=", 2) != 0)
      {
	if (length==0) return(-1);
	if (debug1)
	  fprintf(stderr, "No session name field\n");
	dump(data, length);
	goto errorleap;
      }
    else
      {
	session = data + 2;
	length -= 2;
      }
    if ((end = strchr(session, 0x0a)) == NULL) {
      if (debug1)
	fprintf(stderr, "No end to session name\n");
      dump(data, length);
      goto errorleap;
    }
    *end++ = '\0';
    origlen = length;
    length -= end-session;

    source.s_addr=htonl(hfrom);
    strncpy(heardfrom, (char *)inet_ntoa(source), 16);
    source.s_addr=htonl(src);
    strncpy(origsrc, (char *)inet_ntoa(source), 16);

    i = 0;
    mediactr = 0;
    while (length > 0) 
      {
                cur = end;
                switch (*cur) {

                case 'i':
                        /* print description */
                        desc = end+2;
                        if ((end=strchr(desc, 0x0a)) == NULL) {
			  if (debug1) 
			  {
			    printf("Error decoding description\n");
			    printf("Failure at byte %ld\n", (long)desc-(long)data);
			  }
			  dump(data, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
                        length -= end-cur;
                        break;

                case 'o':
                        /* print originator */
                        orig = end+2;
                        if ((end=strchr(orig, 0x0a)) == NULL) {
			  if (debug1) 
			  {
			    printf("Error decoding originator\n");
			    printf("Failure at byte %ld\n", (long)orig-(long)data);
			  }
			  dump(data, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
                        length -= end-cur;
                        break;

                case 'c':
                        /* print channel */
			chan = end+2;
                        if ((end=strchr(chan, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding channel\n");
			    printf("Failure at byte %ld\n", (long)chan-(long)data);
			  }
			  dump(data, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
                        length -= end-cur;
                        break;
                case 'm':
                        /* print media */
			if (mediactr == MAXMEDIA) {
				/* print error ??? */
				break;
			}
                        media[++mediactr] = end+2;
			format[mediactr] = NULL;
                        if ((end=strchr(media[mediactr], 0x0a)) == NULL) {
			  if (debug1) 
			  {
			    printf("Error decoding media\n");
			    printf("Failure at byte %ld\n", (long)media[mediactr]-(long)data);
			  }
			  dump(data, origlen);
			  goto errorleap;
                        }
			strcpy(vars[mediactr], "");
                        *end++ = '\0';
                        length -= end-cur;
                        break;
                case 'a':
                        /* print format */
                        attr = end+2;
                        if ((end=strchr(attr, 0x0a)) == NULL) {
			  if (debug1) 
			  {
			    printf("Error decoding attribute\n");
			    printf("Failure at byte %ld\n", (long)attr-(long)data);
			  }
			  dump(data, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
                        length -= end-cur;
			if (strncmp(attr,"fmt:",4)==0)
			  {
			    format[mediactr]=attr+4;
			  }
			else {
			  if (strcmp(vars[mediactr], "")!=0) strcat(vars[mediactr], " ");
			  strcat(vars[mediactr], attr);
			}
                        break;
		case 'n':
			/*sd cache extra data - not in packet stream!*/
			unknown = end+2;
			printf("decoding cache data!\n");
                        if ((end=strchr(unknown, 0x0a)) == NULL) {
                                printf("Error decoding cache data\n");
				printf("Failure at byte %ld\n", (long)unknown-(long)data);
                                dump(data, origlen);
                                goto errorleap;
                        }
                        *end++ = '\0';
                        length -= end-cur;
#ifdef NOTDEF
			sscanf(unknown, "%u %u %u", &u1, &u2, &u3);
			printf("%u %u %u\n", u1, u2, u3);
			cftime(namestr, "%d %b %y %H:%M %Z", &u3);
			t=u3;
			printf("%s\n", namestr);
			source.s_addr=u2;
			printf("Heard from: %s\n", inet_ntoa(htonl(source)));
			strcpy(heardfrom, (char *)inet_ntoa(htonl(source)));
			source.s_addr=u1;
			printf("Original src: %s\n", inet_ntoa(htonl(source)));
			strcpy(origsrc, (char *)inet_ntoa(htonl(source)));
#endif
			break;
                default:
                        /* unknown */
                        unknown = end+2;
			if (debug1)
			  printf("Warning: unknown option - >%s<\n", end);
                        if ((end=strchr(unknown, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding unknown\n");
			    printf("Failure at byte %ld\n", (long)unknown-(long)data);
			  }
			  dump(data, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
                        length -= end-cur;
                        break;
                }
                i++;
	      }

    code = Tcl_GlobalEval(interp, "reset_media");
    if (code != TCL_OK)
      {
	if (debug1==TRUE)
	  fprintf(stderr, "%s\n", interp->result);
      }

    /*Create a hash of originator and session name as advert ID*/
    sprintf(namestr, "%s%s", orig, session);
    aid=0;
    for(i=0;i<=4;i++)
      namestr[strlen(namestr)+i]='\0';
    for(i=0;i<=strlen(namestr)/4;i++)
      {
        unsigned int tmp;
        memcpy((char *)&tmp,&namestr[i*4],4);
#ifdef NOTDEF
        printf("%c%c%c%c-%x,",
               namestr[i*4],
               namestr[1+i*4],
               namestr[2+i*4],
               namestr[3+i*4],
               tmp);
#endif
        aid=(aid<<1|aid>>31)^tmp;
#ifdef NOTDEF
printf("%08x",tmp);
#endif
      }
#ifdef NOTDEF
printf("\nnamestr = %s, aid = %ul\n", namestr, aid);
#endif

    Tcl_SetVar(interp, "trust", trust, TCL_GLOBAL_ONLY);
    splat_tcl_special_chars(session);
    Tcl_SetVar(interp, "session", session, TCL_GLOBAL_ONLY);
    splat_tcl_special_chars(desc);
    Tcl_SetVar(interp, "desc", desc, TCL_GLOBAL_ONLY);

    sscanf(chan, "%s %d %u %u", mcaddr, &ttl, &time1, &time2);
    if (time1 != 0)
      {
	time1 -= 0x7c558180;
	time2 -= 0x7c558180;
	set_time("tfrom", 0, time1);
	set_time("tto", 0, time2);
	Tcl_SetVar2(interp, "tto", "0", namestr, TCL_GLOBAL_ONLY);
	sprintf(namestr, "%u", time1);
	Tcl_SetVar2(interp, "starttime", "0", namestr, TCL_GLOBAL_ONLY);
	sprintf(namestr, "%u", time2);
	Tcl_SetVar2(interp, "endtime", "0", namestr, TCL_GLOBAL_ONLY);
	maddr.s_addr = inet_addr(mcaddr);
	store_address(&maddr, time2);
	Tcl_SetVar2(interp, "rctr", "0", "0", TCL_GLOBAL_ONLY);
      }
    else
      {
	Tcl_SetVar2(interp, "tfrom", "0", "0", TCL_GLOBAL_ONLY);
	Tcl_SetVar2(interp, "tto", "0", "0", TCL_GLOBAL_ONLY);
	Tcl_SetVar2(interp, "starttime", "0", "0", TCL_GLOBAL_ONLY);
	Tcl_SetVar2(interp, "endtime", "0", "0", TCL_GLOBAL_ONLY);
	maddr.s_addr = inet_addr(mcaddr);
	store_address(&maddr, 0);
	Tcl_SetVar2(interp, "rctr", "0", "0", TCL_GLOBAL_ONLY);
      }
    Tcl_SetVar(interp, "multicast", mcaddr, TCL_GLOBAL_ONLY);

    splat_tcl_special_chars(orig);
    strncpy(username, orig, sizeof(username));
    if(strchr(username,'@')!=NULL)
      {
        *strchr(username,'@')='\0';
      }
    while(strchr(username,' ')!=0)
      {
        *strchr(username,' ')='_';
      }
    if(strcmp(username, "")==0)
      {
        strcpy(username, "unknown");
      }
    Tcl_SetVar(interp, "creator", username, TCL_GLOBAL_ONLY);
    sprintf(tmpstr, "%u", aid);
    Tcl_SetVar(interp, "createtime", tmpstr, TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "modtime", "0", TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "createaddr", origsrc, TCL_GLOBAL_ONLY);

    sprintf(namestr, "%s%s%s", username, tmpstr, origsrc);
    /*Create a hash of originator data as advert ID*/
    aid=0;
    for(i=0;i<=4;i++)
      namestr[strlen(namestr)+i]='\0';
    for(i=0;i<=strlen(namestr)/4;i++)
      {
	unsigned int tmp;
	memcpy((char *)&tmp,&namestr[i*4],4);
	aid=(aid<<1|aid>>31)^tmp;
      }
    sprintf(namestr, "%x", aid);
    if (advertid!=NULL)
      strcpy(advertid, namestr);
    Tcl_SetVar(interp, "advertid", namestr, TCL_GLOBAL_ONLY);

    Tcl_SetVar(interp, "source", origsrc, TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "heardfrom", heardfrom,  TCL_GLOBAL_ONLY);
    sprintf(namestr,
	    "set timeheard [clock format %u -format {%%d %%b %%y %%H:%%M %%Z}]",
	    t);
    Tcl_GlobalEval(interp, namestr);
    Tcl_SetVar2(interp, "phone", "0", "unknown +0 0", TCL_GLOBAL_ONLY);
    sprintf(namestr, "heard from sd <%s>", orig);
    Tcl_SetVar2(interp, "email", "0", namestr, TCL_GLOBAL_ONLY);

    for (i = 1; i <= mediactr; i++)
      {
	sscanf(media[i], "%s %d %d", namestr, &port1, &port2);
	if (strcmp(namestr, "audio") == 0)
	  {
	    Tcl_SetVar(interp, "media", namestr, TCL_GLOBAL_ONLY);
	    if (port2 != 0)
	      {
		sprintf(namestr, "id:%u", port2);
		if (*vars[i] != '\0') strcat(vars[i], " ");
		strcat(vars[i], namestr);
	      }
	    splat_tcl_special_chars(vars[i]);
	    Tcl_SetVar(interp, "vars", vars[i], TCL_GLOBAL_ONLY);
	    sprintf(namestr, "%d", port1);
	    Tcl_SetVar(interp, "port", namestr, TCL_GLOBAL_ONLY);
	    strcpy(tmpstr, "vat");
	    Tcl_SetVar(interp, "proto", tmpstr, TCL_GLOBAL_ONLY);
	    if (format[i] == NULL)
	      {
		strcpy(tmpstr, "pcm");
		Tcl_SetVar(interp, "fmt", tmpstr, TCL_GLOBAL_ONLY);
	      }
	    else
	      {
		splat_tcl_special_chars(format[i]);
		Tcl_SetVar(interp, "fmt", format[i], TCL_GLOBAL_ONLY);
	      }
	  }
	else if (strcmp(namestr, "video") == 0)
	  {
	    Tcl_SetVar(interp, "media", namestr, TCL_GLOBAL_ONLY);
	    splat_tcl_special_chars(vars[i]);
	    Tcl_SetVar(interp, "vars", vars[i], TCL_GLOBAL_ONLY);
	    sprintf(namestr, "%d", port1);
	    Tcl_SetVar(interp, "port", namestr, TCL_GLOBAL_ONLY);
	    strcpy(tmpstr, "rtp");
	    Tcl_SetVar(interp, "proto", tmpstr, TCL_GLOBAL_ONLY);
	    if (format[i] == NULL)
	      {
		strcpy(tmpstr, "nv");
		Tcl_SetVar(interp, "fmt", tmpstr, TCL_GLOBAL_ONLY);
	      }
	    else
	      {
		splat_tcl_special_chars(format[i]);
		Tcl_SetVar(interp, "fmt", format[i], TCL_GLOBAL_ONLY);
	      }
	  }
	else if (strcmp(namestr, "whiteboard") == 0)
	  {
	    Tcl_SetVar(interp, "media", namestr, TCL_GLOBAL_ONLY);
	    splat_tcl_special_chars(vars[i]);
	    Tcl_SetVar(interp, "vars", vars[i], TCL_GLOBAL_ONLY);
	    sprintf(namestr, "%d", port1);
	    Tcl_SetVar(interp, "port", namestr, TCL_GLOBAL_ONLY);
	    strcpy(tmpstr, "udp");
	    Tcl_SetVar(interp, "proto", tmpstr, TCL_GLOBAL_ONLY);
	    if (format[i] == NULL)
	      {
		strcpy(tmpstr, "wb");
		Tcl_SetVar(interp, "fmt", tmpstr, TCL_GLOBAL_ONLY);
	      }
	    else
	      {
		splat_tcl_special_chars(format[i]);
		Tcl_SetVar(interp, "fmt", format[i], TCL_GLOBAL_ONLY);
	      }
	  }
	else
	  {
	    continue;
	  }
      sprintf(namestr, "%d", ttl);
      Tcl_SetVar(interp, "mediattl", namestr, TCL_GLOBAL_ONLY);
      Tcl_SetVar(interp, "mediaaddr", mcaddr, TCL_GLOBAL_ONLY);

      code = Tcl_GlobalEval(interp, "set_media");
      if (code != TCL_OK)
	{
	  if (debug1==TRUE)
	    fprintf(stderr, "sd-gw, set_media[%d] for session %s:\n%s\n", i,
		    session, interp->result);
	}
    }

    sprintf(namestr, "%d", ttl);
    Tcl_SetVar(interp, "recvttl", namestr, TCL_GLOBAL_ONLY);

    Tcl_SetVar(interp, "recvsap_addr", sap_addr, TCL_GLOBAL_ONLY);
    sprintf(namestr, "%d", sap_port);
    Tcl_SetVar(interp, "recvsap_port", namestr, TCL_GLOBAL_ONLY);

    code = Tcl_GlobalEval(interp, "add_to_list");
    if (code != TCL_OK) 
      {
	if (debug1==TRUE)
	  fprintf(stderr, "sd-gw, add_to_list failed for session %s:\n%s\n",
		  session, interp->result);
      }
    return time2;
errorleap:
    return 0;
}
#endif

int extract_ttl(char *addrstr)
{
  char *ttlstr;
  ttlstr=strchr(addrstr, '/');
  if (ttlstr==NULL) return 0;
  *ttlstr='\0';
  return(atoi(ttlstr+1));
}

int extract_layers(char *addrstr)
{
  char *layersstr;
  layersstr=strchr(addrstr, '/');
  if (layersstr==NULL) return 1;
  layersstr=strchr(layersstr+1, '/');
  if (layersstr==NULL) return 1;
  *layersstr='\0';
  return(atoi(layersstr+1));
}

int check_net_type(char *in, char *ip)
{
  if (strncmp(in, "IN", 2)!=0)
    {
      if (debug1==TRUE)
	fprintf(stderr, "sdr: expected network type IN, got %s\n", in);
      return -1;
    }
  if (strncmp(ip, "IP4", 3)!=0)
    {
      if (debug1==TRUE)
	fprintf(stderr, "sdr: expected address type IP4, got %s\n", ip);
      return -1;
    }
  return 0;
}

int timed_send_advert(ClientData cd)
{
  struct advert_data *addata;
  struct timeval tv;
  unsigned int interval;
  unsigned int jitter;
 
  gettimeofday(&tv, NULL);
  addata=(struct advert_data *)cd;

  /*If the session has timed out, don't re-announce it*/
  if(((unsigned long)tv.tv_sec<=addata->end_time)||(addata->end_time==0))
    {
      send_advert(addata->data, addata->tx_sock, addata->ttl, 
		  addata->encrypt, addata->length);
      interval = addata->interval;
      jitter = (unsigned)random() % interval;
      addata->timer_token=Tcl_CreateTimerHandler(interval + jitter,
                          (Tk_TimerProc*)timed_send_advert,
                          (ClientData)addata);
    }
  return TCL_OK;
}

int send_advert(char *adstr, int tx_sock, unsigned char ttl, 
		int encrypt, u_int len)
{
  char *buf;
#ifdef WIN32
  int wttl;
#endif

#ifdef LOCAL_ONLY
  ttl=1;
#endif

  buf=(char *)malloc(sizeof(struct sap_header)+len+4);
  len+=build_packet(buf, adstr, len, encrypt);

#ifdef WIN32
  wttl = ttl;
  if (setsockopt(tx_sock, IPPROTO_IP, IP_MULTICAST_TTL, (char *)&wttl, 
		 sizeof(wttl))<0)
#else
    if (setsockopt(tx_sock, IPPROTO_IP, IP_MULTICAST_TTL, (char *)&ttl, 
		   sizeof(ttl))<0)
#endif
      {
	perror("setsockopt ttl");
	fprintf(stderr, "ttl: %d\n", ttl);
	free(buf);
	return 0;
      }
  if (debug1==TRUE)
    {
      printf("-----\nsending ad to sock %d, ttl %d\n", tx_sock, ttl);
      printf(adstr);
    }
  send(tx_sock, buf, sizeof(struct sap_header)+len, 0);
  free(buf);
  return 0;
}

static struct advert_data *first_ad=NULL;
static struct advert_data *last_ad=NULL;

int queue_ad_for_sending(char *aid, char *adstr, int interval, long end_time, char *txaddress, int txport, unsigned char ttl, char *keyname)
{
  static int no_of_ads=0;
  int i;
  struct advert_data *addata;

  addata=(struct advert_data *)malloc(sizeof(struct advert_data));
  addata->tx_sock=0;
  for(i=0;i<no_of_tx_socks;i++) 
    {
      if (strcmp(tx_sock_addr[i], txaddress)==0)
	{
	  addata->tx_sock=txsock[i];
	  break;
	}
    }
  if (addata->tx_sock==0) {
    sd_tx(txaddress, txport, txsock, &no_of_tx_socks);
    addata->tx_sock=txsock[no_of_tx_socks-1];
  }
  addata->aid=(char *)malloc(strlen(aid)+1);
  addata->interval=interval;
  addata->end_time=end_time;
  addata->next_ad=NULL;
  addata->ttl=ttl;
  addata->timer_token=Tcl_CreateTimerHandler(interval,
                          (Tk_TimerProc*)timed_send_advert,
			  (ClientData)addata);
  strcpy(addata->aid, aid);
  addata->length=strlen(adstr);
  
  if (store_data_to_announce(addata, adstr, keyname)==-1)
    {
      free(addata->aid);
      free(addata);
      return -1;
    }

  if(first_ad==NULL)
    {
      first_ad=addata;
      last_ad=addata;
      addata->prev_ad=NULL;
      no_of_ads=1;
    }
  else
    {
      last_ad->next_ad=addata;
      addata->prev_ad=last_ad;
      last_ad=addata;
      no_of_ads++;
    }
  send_advert(addata->data, addata->tx_sock, ttl, addata->encrypt, 
	      addata->length);
  return 0;
}

int stop_session_ad(char *aid)
{
  struct advert_data *addata;
  addata=first_ad;

  /*we don't really want to have to store this data multiple times,
    so time to do a little searching.  Doesn't happen often, so not
    a big deal*/

  while(addata!=NULL) {

    /*check whether the advert id matches*/
    if(strcmp(aid, addata->aid)==0)
      {
#ifdef DEBUG
	  printf("Found matching aid: %s\n", aid);
#endif
      }
    else
      {
#ifdef DEBUG
	printf("Aid %s failed to match %s\n", aid, addata->aid);
#endif
        addata=addata->next_ad;
        continue;
      }
    
    /*delete the announcement from the list*/
    if(addata->next_ad==NULL)
      {
	/*it's the last ad in the list*/
	if(addata->prev_ad!=NULL)
	  {
	    /*but not the first*/
	    addata->prev_ad->next_ad=NULL;
	    last_ad=addata->prev_ad;
	  }
	else
	  {
	    /*it is the first*/
	    first_ad=NULL;
	    last_ad=NULL;
	  }
      }
    else if(addata->prev_ad==NULL)
      {
	/*it's the first ad*/
	if(addata->next_ad!=NULL)
	  {
	    /*but not the last*/
	    addata->next_ad->prev_ad=NULL;
	    first_ad=addata->next_ad;
	  }
	else
	  {
	    /*shouldn't need this*/
	    first_ad=NULL;
	    last_ad=NULL;
	  }
      } else {
	/*it's in the middle*/
	addata->prev_ad->next_ad=addata->next_ad;
	addata->next_ad->prev_ad=addata->prev_ad;
      } 
    
    /*Cancel it's timer event*/
    Tcl_DeleteTimerHandler(addata->timer_token);

    /*free it's memory*/
    free(addata->aid);
    free(addata->data);
    free(addata);
#ifdef DEBUG
    printf("Announcement deleted\n");
#endif
    return 0;
  }
  return 1;
}

void clean_up_and_die()
{
  int i;
#ifdef DEBUG
  printf("sdr exiting\n");
#endif
  for(i=0;i<no_of_rx_socks;i++)
    close(rxsock[i]);
  for(i=0;i<no_of_tx_socks;i++)
    close(txsock[i]);
  exit(0);
}

void force_numeric(char *str)
{
  /*security - splat any none numeric characters before passing this to Tcl*/
  unsigned int i;
  for(i=0;i<strlen(str);i++)
    {
      if ((str[i]<48)||(str[i]>57)) {
	str[i]=' ';
      }
    }
}

void splat_tcl_special_chars(char *str) 
{
  /*security - don't want someone passing Tcl commands in an announcement*/
  /*splat any special characters Tcl might use for execution, etc*/
  unsigned int i;
  if (str==NULL) return;
  for(i=0;i<strlen(str);i++)
    {
      if ((str[i]=='[')||(str[i]==']')||(str[i]=='$')) 
	{
	  str[i]=' ';
	}
    }
}

void warn_tcl_special_chars(char *str) 
{
  /*security - don't want someone passing Tcl commands in an announcement*/
  unsigned int i;
  if (str==NULL) return;
  for(i=0;i<strlen(str);i++)
    {
      if ((str[i]=='[')||(str[i]==']')||(str[i]=='$')) 
	{
	  if (debug1==TRUE)
	    fprintf(stderr, "WARNING: received key containing Tcl special chars\n");
	}
    }
}
