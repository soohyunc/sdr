/*
 * Copyright (c) 1997,1998 University of Southern California
 * Copyright (c) 1995,1996 University College London
 * Copyright (c) 1994 Tom Pusateri, J.P.Knight
 *
 * All rights reserved.
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
 *      Department at University College London and by the Information
 *      Sciences Institute of the University of Southern California
 * 4. Neither the name of the Universities nor of the Department or Institute
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
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

#include <assert.h>
#include <locale.h>
#include <signal.h>
#ifndef WIN32
#include <unistd.h>
#include <fcntl.h>
#endif
#include <sys/types.h>
#include <sys/stat.h>
#include <setjmp.h>
#include <locale.h>

#ifdef HAVE_ZLIB
#include <zlib.h>
#endif

#include "sdr.h"
#include "sip.h"
#include "prototypes.h"
#include "prototypes_crypt.h"

static struct advert_data *first_ad=NULL;
static struct advert_data *last_ad=NULL;
 
#ifdef AUTH
static int no_of_ads=0;
int find_keyname_by_key(char *key, char *keyname);
#endif

extern Tcl_Interp *interp;
int gui, cli;
int logging;

unsigned long parse_entry();

extern int init_security();

void seedrand()
{
  struct timeval tv;
  gettimeofday(&tv, NULL);
  lblsrandom(tv.tv_usec);
}

void remove_cr(char *str)
{
  if (str[strlen(str)-1]=='\r')
    str[strlen(str)-1]='\0';
}

void hexdump(char *buf, int len) {
  int i, val;
  char *p=buf;
  for(i=0;i<len;i++) {
    val = (int)((*p++)&0xff);
    if (val<16) 
      printf("0%x", val);
    else
      printf("%x", val);
    if (i%2==1) printf(" ");
  }
  printf("\n");
}

int rxsock[MAX_SOCKS];
char *rx_sock_addr[MAX_SOCKS];
int rx_sock_port[MAX_SOCKS];
int no_of_rx_socks=0;
int txsock[MAX_SOCKS];
char *tx_sock_addr[MAX_SOCKS];
int no_of_tx_socks=0;
int sip_udp_rx_sock, sip_tcp_rx_sock, sip_udp_tx_sock, busrxsock;
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
        printf("Problem with packet. Dumping...\n");
        printf("Buffer length: %d\n",buflen);
	printf("Byte %4d: ", 0);
        for (i=0; i<buflen; i++) {
                c=buf[i];
#ifdef HEXDEBUG
		if (!isprint(c))
		    printf(" %02x .", c);
		else
		    printf(" %02x %c", c,c);
#else
		if (!isprint(c) && c != '\n')
		    if (c < 32)
			printf("^%c", c + 64);
		    else
			printf("\\x%02x", c);
		else
		    printf("%c",c);
#endif
		if (c == '\n')
			printf("Byte %4d: ", i + 1);
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

/*--------------------------------------------------------------------------*/
/* load the entries from the cache                                          */
/*--------------------------------------------------------------------------*/
int load_cache_entry(
	ClientData dummy,
	Tcl_Interp* interp,
	int acgc,
	char** argv
)
{
    char buf[MAXADSIZE];
    char *p=NULL, advert[MAXADSIZE];
    char *new_data=NULL;
    char sap_addr[20]="";
    char aid[80]="";
    char *k1=NULL,*k2=NULL;
    char *encbuf=NULL, newbuf[MAXADSIZE];

    int sap_port, len;
    int ttl;
    int edlen;
    int hdr_len, has_encryption=0, has_authentication=0, has_security=0; 
    int newlength=0, auth_len=0, data_len=0,new_len, newlen1, enc_data_len=0;
    int enc_des=0;
    int irand=0;
    int retval = TCL_OK;

    unsigned long  origsrc, src, endtime=0;
    time_t t;

    FILE* enc_fd=NULL;
    struct timeval tv;
    struct stat sbuf;
    struct sap_header *bp=NULL;
    static char debugbuf[MAXADSIZE]="";
    struct auth_header *auth_hdr=NULL;
    struct priv_header *enc_p=NULL;
    struct advert_data *addata=NULL;
    char *data=NULL;

    char tmp_keyid[TMPKEYIDLEN], key[MAXKEYLEN], keyname[MAXKEYLEN];
    char asym_keyid[ASYMKEYIDLEN], enc_asym_keyid[ASYMKEYIDLEN];
    char trust[TRUSTLEN], nrandstr[NRANDSTRLEN];

    char *authtype=NULL, *authstatus=NULL, *authmessage=NULL;
    char *enctype=NULL, *encstatus=NULL, *encmessage=NULL;
    char *encstatus_p=NULL;

    writelog(printf("++ debug ++ > entered load_cache_entry\n");)

/* don't load any PGP encrypted cache files if PGPSTATE isn't set         */
/* Note "symm" is asymmetrically and "crypt" is symmetrically encrypted ! */

    if (strcmp(argv[2], "symm")==0) {
      Tcl_Eval(interp, "pgpstate");
      if (strcmp(interp->result,"1") != 0) {
        writelog(printf("PGPSTATE != 1: Not loading %s\n",argv[1]);)
        retval = 0;
        goto out;
      }
    }

    memset(buf,            0, MAXADSIZE);
    memset(advert,         0, MAXADSIZE);
    memset(tmp_keyid,      0, TMPKEYIDLEN);
    memset(key,            0, MAXKEYLEN);
    memset(keyname,        0, MAXKEYLEN);
    memset(asym_keyid,     0, ASYMKEYIDLEN);
    memset(enc_asym_keyid, 0, ASYMKEYIDLEN);
    memset(nrandstr,       0, NRANDSTRLEN);
    memset(trust,          0, TRUSTLEN);

    new_data = (char *)malloc(MAXADSIZE);

    writelog(printf("loading cache file (%s): %s\n", argv[1], argv[2]);)

/* need the following even if no encryption/authentication used */

    authstatus  = (char *)malloc(AUTHSTATUSLEN);
    authtype    = (char *)malloc(AUTHTYPELEN);
    authmessage = (char *)malloc(AUTHMESSAGELEN);

    encstatus   = (char *)malloc(ENCSTATUSLEN);
    enctype     = (char *)malloc(ENCTYPELEN);
    encmessage  = (char *)malloc(ENCMESSAGELEN);
    encstatus_p = (char *)malloc(ENCSTATUSLEN);

/* load the cache file                                               */
/* strange notation: crypt=symmetric; symm=asymmetric; clear=clear   */

/* trying to load a symmetrically encrypted file                     */

    if (strcmp(argv[2], "crypt")==0) {

      if (strcmp(get_pass_phrase(), "")==0) {
        goto out;
      }
      len=load_crypted_file(argv[1], buf, get_pass_phrase());
      buf[len]='\n';
      buf[len+1]='\0';
      enc_des=1;

    } else {

/* trying to load asymmetrically encrypted file                      */

      if (strcmp(argv[2], "symm")==0) {

        enc_fd=fopen(argv[1],"rb");

        if (enc_fd==NULL) {
          retval = -1;
	  goto out;
        }

        stat(argv[1], &sbuf);
        if (sbuf.st_size > MAXADSIZE) {
          writelog(printf("file %s too big\n",argv[1]);)
          fclose(enc_fd);
          retval = -1;
	  goto out;
        }

        encbuf = (char *)malloc(sbuf.st_size);
        len    = fread(encbuf, 1, sbuf.st_size, enc_fd);
        fclose(enc_fd);
        memcpy(buf, encbuf, sbuf.st_size);
        free(encbuf);

      } else {

/* trying to load clear file - argv[2] is "clear" */

        enc_fd=fopen(argv[1], "r");
        if (enc_fd==NULL) {
          goto out;
        }
        len=fread(buf, 1, MAXADSIZE, enc_fd);
        buf[len]='\0';
        fclose(enc_fd);
      }

    }

/* cache file should be loaded by now        */
/* test the first few characters of the file */

    if (strncmp(buf, "n=", 2) != 0) {
     fprintf(stderr, "sdr:corrupted cache file: %s\n", argv[1]);
     retval = 1;
     goto out;
    }

/* read buffer into variables */

    sscanf(&buf[2], "%lu %lu %lu %s %u %u %s %s %s %s %s %s %s",
      &origsrc, &src, &t, sap_addr, &sap_port, &ttl, trust,
      authtype, enctype,authstatus,encstatus,asym_keyid,enc_asym_keyid);

/* debug */

    writelog(printf("lce: origsrc=%lu src=%lu t=%lu\n",origsrc,src,t);)
    writelog(printf("lce: sap_addr=%s sap_port=%u\n",sap_addr,sap_port);)
    writelog(printf("lce: ttl=%u trust=%s\n",ttl,trust);)
    writelog(printf("lce: authtype=%s authstatus=%s keyid=%s\n",
      authtype,authstatus,asym_keyid);)
    writelog(printf("lce: enctype=%s  encstatus=%s  keyid=%s\n",
      enctype,encstatus,enc_asym_keyid);)

/* check that the buffer is not clear, if it is then set enc and auth off */

      if (strncmp(authtype,"k",1)== 0) {
        sscanf(&buf[2], "%lu %lu %lu %s %u %u %s", &origsrc,
          &src, &t, sap_addr, &sap_port, &ttl, trust);

	strcpy(authstatus, "NOAUTH" );
	strcpy(authtype,   "none"   );
	strcpy(authmessage,"none"   );

	strcpy(encstatus,  "NOENC"  );
	strcpy(enctype,    "none"   );
	strcpy(encmessage, "none"   );

      }

      remove_cr(trust);
      k1=strchr(buf,'\n')+1;
      k2=strchr(k1, '\n')-1;

/* not sure why we would have a cache file with CRLF - cope with it anyway */

      if (strchr(k1, '\r') != NULL) {
        if (strchr(k1, '\r')-1<k2) {
          k2=strchr(k1, '\r')-1;
        }
      }

/* set p to point to line following "n=....\nk=...\n" */

      if (strncmp(k1, "k=", 2)==0) {
	if ((u_int)k2>=(u_int)k1+2) {
	  memcpy(key, k1+2, (u_int)k2-((u_int)k1+1));
	  key[(u_int)k2-((u_int)k1+1)]='\0';
	} else {
          key[0]='\0';
        }
	p=strchr(k1, '\n')+1;
      } else {
	key[0]='\0';
	p=strchr(buf, '\n')+1;
      }

      if (strcmp(trust,"")==0) {
	strcpy(trust, "trusted");
      }

/* len = amount read in from file; buf points to start of this (ie n=...) */
/* p points to line following "n=...\nk=...\n" (ie v=...)                 */
/* So, (p-buf)=length of "n=...\nk=...\n";                                */
/* len-(p-buf)=all file except the first "n=...\nk=...\n"                 */

      edlen = len - abs(p-buf);

/* All previously authenticated announcements must be re-authenticated in */
/* case the cache has been corrupted or illegally modified                */

      if (strcmp(authtype,"none")==0) {
        strcpy(authstatus, "NOAUTH");
        strcpy(authmessage, "none");
      } else {
        strcpy(authstatus, "unchecked");
        strcpy(authmessage, "The signature from the cache file has not been checkedfile. It will be checked when it is received as an announcement.");
      }

      if (strcmp(enctype,"none")==0) {
        strcpy(encstatus, "NOENC");
        strcpy(encmessage, "none");
      } else {
        strcpy(encstatus, "unchecked");
        strcpy(encmessage, "The encryption has not been checked - an unencrypted cache file has been loaded and not updated by a received announcement");
      }

/* An attempt at keeping unused fields empty! */

      if (strcmp(authtype,"none")==0 || strcmp(asym_keyid,"1")== 0) {
        strcpy(asym_keyid,"0");
      }

      if (strcmp(enctype,"none")==0 || strcmp(enc_asym_keyid,"2")==0) {
        strcpy(enc_asym_keyid,"0");
      }

/* if we sent the original or if it has encryption or authentication */

      if ( origsrc==hostaddr || (strcmp(authtype,"none")!=0) || (strcmp(enctype,"none")!=0)) {
	memset(advert, 0, MAXADSIZE);
	memcpy(advert, p, strlen(p)+1);
      }

/* Ensure that we discard the "Z=" component of the cache entry as it was  */
/* not included in the original signature creation                         */ 

/* debugging info - leave in for the moment */

      writelog(printf("lce: calling parse_entry\n");)
      writelog(printf(" advertid=%s length=%d, origsrc=%lu, src=%lu\n",
         aid,strlen(p),origsrc,src);)
      writelog(printf(" sap_addr=%s sap_port=%d, time_t=%d, recvkey=%s\n",
         sap_addr,sap_port,(int)t,key);)
      writelog(printf(" auth type=%s, status=%s, data_len=%d, keyid=%s\n",
         authtype,authstatus,data_len,asym_keyid);)
      writelog(printf(" enc  type=%s, status=%s, data_len=%d, keyid=%s\n",
         enctype,encstatus,enc_data_len,enc_asym_keyid);)
      writelog(printf(" authmessage= %s\n",authmessage);)
      writelog(printf("  encmessage= %s\n",encmessage);)

      endtime = parse_entry(aid, p, edlen,origsrc, src, sap_addr, sap_port, 
                  t, trust, key, authtype, authstatus, &data_len, asym_keyid,
                  enctype, encstatus,&enc_data_len, enc_asym_keyid,
                  authmessage, encmessage);

/* debugging info - leave in for the moment */

      writelog(printf("load_cache_entry: returned from parse_entry\n");)
      writelog(printf(" advertid=%s length=%d, origsrc=%lu, src=%lu\n",
         aid,strlen(p),origsrc,src);)
      writelog(printf(" sap_addr=%s sap_port=%d, time_t=%d, recvkey=%s\n",
         sap_addr,sap_port,(int)t,key);)
      writelog(printf(" auth type=%s, status=%s, data_len=%d, keyid=%s\n",
         authtype,authstatus,data_len,asym_keyid);)
      writelog(printf(" enc  type=%s, status=%s, data_len=%d, keyid=%s\n",
         enctype,encstatus,enc_data_len,enc_asym_keyid);)
      writelog(printf(" authmessage= %s\n",authmessage);)
      writelog(printf("  encmessage= %s\n",encmessage);)

/* malloc advert_data structure */

      addata = (struct advert_data *)malloc(sizeof(struct advert_data));
      addata->sap_hdr  = NULL;
      addata->sapenc_p = NULL;
      addata->authinfo = NULL;
  
/* if the message is unencrypted or DES encryption has been used */

      if ( strncmp(enctype,"none",4)==0 || strncmp(enctype,"des",3)==0 ) {

	if (strcmp(authtype, "none") != 0 ) {

/* we have authentication info */

/* data_len is length of data from "v=0" to "Z= " (not including signature) */
/* ie advert[data_len-3] is the "z"                                         */
/* "(p-buf)+data_len" gives length of whole file except the signature       */
/* so new_len = length of stuff following "Z= "                             */

	  advert[data_len-3]=0;

	  new_len=(len)-abs((p-buf)+data_len);

/* need this for later as new_len gets modified */

	  newlen1 = new_len;

	  if (new_len>MAXADSIZE) {
	    fprintf(stderr,"Sdr error: buffer too large %d\n",new_len);
	    retval = -1;
	    goto out;
	  }

/* the following will copy the stuff following "Z= " to newbuf */ 
/* NB. What follows Z= is the whole SAP packet                 */ 

          memcpy(newbuf,p+data_len,new_len);

	  bp = (struct sap_header *) newbuf;

/* newbuf is now cast into a sap_header */

/* if debugging have a look to see it is sensible */

          writelog(printf("lce: bp: version=%d type=%d enc=%d compress=%d authlen=%d msgid=%d src=%lu\n",bp->version, bp->type, bp->enc, bp->compress, bp->authlen, bp->msgid, bp->src);)

/* due to space restrictions the authlen in the header was divided by 4 */

	  auth_len = bp->authlen*4;

/* skip the sap_header */

          data     = (char*)bp+sizeof(struct sap_header);
	  new_len -= sizeof(struct sap_header);

/* skip the authentication header */

          data    += auth_len;
          new_len -= auth_len;

/* call gen_new_auth_data to create new_data buffer. Basically this copies */
/* the sap packet but sets bp->msgid=0 and skips the authentication header */

          newlength = gen_new_auth_data(newbuf,new_data,bp,auth_len,newlen1);

/* check the authentication */

          if ((bp->authlen !=0 ) && (strcmp(authtype,"none") != 0 ) ) {

/* authentication was present - either PGP or X.509 */

	    auth_hdr=(struct auth_header *)((char *)bp+sizeof(struct sap_header));
            addata->authinfo=(struct auth_info *)malloc(sizeof(struct auth_info));

	    if (strcmp(authtype,"pgp") == 0) {

	      authstatus = check_authentication(auth_hdr, 
			    new_data, newlength, auth_len, tmp_keyid, 
			    authmessage, AUTHMESSAGELEN, addata, authtype);

	      writelog(printf("lce: authstatus = %s\n",authstatus);)
	      writelog(printf("lce: authmessage= %s\n",authmessage);)

	    } else {

/* this is X.509 code and hasn't been checked or tested yet */

	      Tcl_Eval(interp, "x509state");
	      if (strcmp(interp->result,"1") == 0) {
                irand = (lblrandom()&0xffff);
		authstatus= check_x509_authentication(auth_hdr,
                    ((char *)bp+sizeof(struct sap_header)+AUTH_HEADER_LEN), 
                    new_data, newlength, auth_len, tmp_keyid, 
                    irand,authmessage, AUTHMESSAGELEN);
	        store_x509_authentication_in_memory(addata, authtype, irand);
	      } else {
		strncpy(authstatus, "noauth", AUTHSTATUSLEN);
                strncpy(authtype,"none",AUTHTYPELEN);
                strncpy(authmessage,"The session contained an x509 digital signature which has not been checked", AUTHMESSAGELEN);
	      }

	    }

          } else {

/* no authentication was present */

            strncpy(authstatus, "noauth", AUTHSTATUSLEN);

	  }

/* Basically what we're trying to do here is ensure that the authentication  */
/* information in SAP packets that were NOT sent by the host machine are     */
/* stored in the advert_data list.  The difference between this type of data */
/* and that stored when we create our own announcements is that it is not    */
/* attached to a timer and only authentication information (defined by the   */
/* PGP extension to SAP) and the advert id are stored in the structure       */

          if (origsrc != hostaddr) {
            if (first_ad==NULL) {
              first_ad=addata;
              last_ad=addata;
              addata->prev_ad=NULL;
              no_of_ads=1;
            } else {
              last_ad->next_ad=addata;
              addata->prev_ad=last_ad;
              last_ad=addata;
              no_of_ads++;
            }
            addata->end_time=endtime;
            addata->aid=strdup(aid);
          }
        }

/* see if it was one of our ads and send it out again */

        if( (origsrc==hostaddr) && (strcmp(trust,"trusted")==0) ) {

          if (strcmp(key,"")!=0) {

/* if there was a key it must be DES */
/* we have the key but need the keyname for sending */

            if (find_keyname_by_key(key, keyname) != 0) {
              retval = -1;
	      goto out;
            }

            if ( enc_des == 1) {

/* set the encstatus, encmessage and enctype */

             memset(encstatus, 0, ENCSTATUSLEN);
             memset(encmessage,0, ENCMESSAGELEN);
             memset(enctype,   0, ENCTYPELEN);

             strcpy(enctype,"des");
             strncpy(encstatus,"success",ENCSTATUSLEN);
             strncpy(encmessage," DES Encryption: Success  Key: ",ENCMESSAGELEN);
	     if (strlen(encmessage)+strlen(key)+strlen(keyname)+strlen("  Key name:  ") < ENCMESSAGELEN) {
	       strcat(encmessage, key);
	       strcat(encmessage, "  Key name:  ");
	       strcat(encmessage, keyname);
	     }
            }
          }

/* here if either DES or unencrypted */

          queue_ad_for_sending(aid, advert, INTERVAL, endtime, sap_addr, 
            sap_port, (unsigned char)ttl, keyname, authtype, authstatus,
            enctype,encstatus, addata);
        }

      } else {

/* asymmetric encryption was used */

	memset(asym_keyid,    0, ASYMKEYIDLEN);
	memset(enc_asym_keyid,0, ASYMKEYIDLEN);
        memset(encmessage,    0, ENCMESSAGELEN);
        memset(authmessage,   0, AUTHMESSAGELEN);
        memset(nrandstr,      0, NRANDSTRLEN);

/* data_len is length of data from "v=0" to "Z= " (not including signature) */
/* ie advert[data_len-3] is the "z"                                         */
/* "(p-buf)+data_len" gives length of whole file except the signature       */
/* so new_len = length of stuff following "Z= "                             */

	advert[data_len-3] = 0;
        new_len=(len)-abs((p-buf)+data_len);

/* need this for later as new_len gets modified */

        newlen1 = new_len;

	if (new_len> MAXADSIZE) {
	  fprintf(stderr, "Sdr error: buffer too large %d\n",new_len);
	  retval = -1;
	  goto out;
	}

/* the following will copy the stuff following "Z= " to newbuf */
/* NB. What follows Z= is the whole SAP packet                 */

        memcpy(newbuf,p+data_len,new_len);

/* not sure why we need this */

	gettimeofday(&tv, NULL);

/* set bp to point to the newbuf */

	bp = (struct sap_header *) newbuf;

/* make a safe copy */

        memcpy(debugbuf, newbuf, new_len);

/* if debugging have a look to see it is sensible */

        writelog(printf("lce: bp: version=%d type=%d enc=%d compress=%d authlen=%d msgid=%d src=%lu\n",bp->version, bp->type, bp->enc, bp->compress, bp->authlen, bp->msgid, bp->src);)

/*	src = ntohl(bp->src);               */
/*      hfrom = ntohl(from.sin_addr.s_addr); */

/* skip the sap_header */

	data     = (char*)bp+sizeof(struct sap_header);
	new_len -= sizeof(struct sap_header);

/* is there any authentication */

	if ( (bp->authlen != 0) && (strcmp(authtype,"none") != 0 )) {

/* due to space restrictions the authlen in the header was divided by 4 */ 

          auth_len = bp->authlen*4;

          auth_hdr = (struct auth_header *)((char *)bp+sizeof(struct sap_header));
	} else {

/* No authentication - this is a fix for Byte ordering */

	  auth_len = 0;
	  bp->authlen = 0;

	}

/* was there any encryption - surely this is always true at this point ? */

	if (bp->enc==1) {

/* malloc the addata->priv_header and set enc_p to point to the start of */
/* the privacy header in the sap packet                                  */

          addata->sapenc_p = (struct priv_header *)malloc(sizeof(struct priv_header));
          enc_p = (struct priv_header *)((char *)bp+sizeof(struct sap_header)+auth_len+TIMEOUT);
 
/* debug - check the privacy header looks okay */

          writelog(printf(" lce: enc_p->version=%d padding=%d enc_type=%d hdr_len=%d\n",enc_p->version,enc_p->padding,enc_p->enc_type,enc_p->hdr_len) ;)

          if (enc_p->version==1 && 
               (enc_p->enc_type==PGP || enc_p->enc_type==PKCS7) ) {

/* if there is PGP or PKCS7 encryption */

            if ( enc_p->enc_type == PGP) {
              strcpy(enctype, "pgp");
            } else {
              strcpy(enctype,"x509");
            }
	    hdr_len = enc_p->hdr_len * 4;

/* set data to point to start of privacy header */

	    data      += auth_len+TIMEOUT;
	    new_len   -= (auth_len+TIMEOUT);

/* if there is authentication call gen_new_auth_data to create new_data */
/* buffer. Basically this copies the sap packet but sets bp->msgid=0    */
/* and skips the authentication header                                  */

            if (auth_len != 0) {
              newlength=gen_new_auth_data(newbuf,new_data,bp,auth_len,newlen1);
            }

/* check the encryption */

            if (enc_p->enc_type == PGP) {

/* PGP style encryption */

              if ( check_encryption(enc_p, data, new_len, enc_asym_keyid, 
			encmessage, ENCMESSAGELEN, addata, enctype) != 0 ) {
	        strcpy(encstatus_p, "failed");
              } else {
	        strcpy(encstatus_p, "success");
              }

            } else {

/* this is for the X.509 encryption and hasn't been checked */

	      Tcl_Eval(interp, "x509state");
              if (strcmp(interp->result,"1") == 0) {
	        irand = (lblrandom()&0xffff);
		encstatus_p = \
		  check_x509_encryption(enc_p, 
			   ((char *)bp+sizeof ( struct sap_header)+auth_len),
                           data, new_len, hdr_len, enc_asym_keyid, irand,
                           encmessage, ENCMESSAGELEN);
	        store_x509_encryption_in_memory(addata, enctype, irand);
              } else {
	        encstatus_p="failed";
              }
            }

/* set encstatus and cleanup any files if the decryption failed */

            if (strcmp(encstatus_p,"failed") == 0) {	
              memset(encstatus,0,ENCSTATUSLEN);
	      strncpy(encstatus, encstatus_p, ENCSTATUSLEN);
              sprintf(nrandstr, "%d", irand);
	      writelog(printf("lce: encstatus failed. Corrupted data ?\n");)
              Tcl_VarEval(interp, "enc_pgp_cleanup  ",   nrandstr, NULL);
              Tcl_VarEval(interp, "enc_pkcs7_cleanup  ", nrandstr, NULL);
	      retval = -1;
	      goto out;
            } 

            memset(encstatus,0,ENCSTATUSLEN);
	    strncpy(encstatus, encstatus_p, ENCSTATUSLEN);

/* check that the first few bytes of the data look like an SDP payload   */
/* if so then copy it to the "data" buffer and set new_len to be correct */

	    if (strncmp(addata->sapenc_p->txt_data, "v=", 2) ==0) {
              data = (char *)malloc(addata->sapenc_p->txt_len);
              memcpy(data,addata->sapenc_p->txt_data,addata->sapenc_p->txt_len);
	      new_len = addata->sapenc_p->txt_len;
            }

	    has_encryption=1;
	    has_security=1;

	  } else {

/* either bp->version != 1 or enc_type isn't PGP or PKCS7 */

            memset(encstatus,  0, ENCSTATUSLEN);
            memset(enctype,    0, ENCTYPELEN);
            memset(encmessage, 0, ENCMESSAGELEN);
	    strncpy(enctype,    "none",  ENCTYPELEN);
	    strncpy(encstatus,  "noenc", ENCSTATUSLEN);
	    strncpy(encmessage, "none",  ENCMESSAGELEN);

	  }

/* check the authentication */

	  if ( bp->authlen !=0 && (strcmp(authtype,"none") != 0 )) {

/* authentication was present - either PGP or X.509 */

            auth_len = bp->authlen*4;
	    auth_hdr=(struct auth_header *) ((char *)bp + sizeof(struct sap_header));
            addata->authinfo=(struct auth_info *)malloc(sizeof(struct auth_info));

/* check the version and type of the auth_header          */
/* the certificate types are obsolete and will be removed */

	    if ( (auth_hdr->version==1) ) {

              if ( auth_hdr->auth_type == authPGP ) {
                strcpy(authtype, "pgp");
              } else if ( auth_hdr->auth_type == authX509) {
                strcpy(authtype,"x509");
              } else {
	        printf("lce: unknown authtype (%d) in auth header",auth_hdr->auth_type);
                retval = -1;
		goto out;
              }

/* call the appropriate check_authentication routine */

              if (auth_hdr->auth_type==authPGP) {

/* PGP authentication has been used */

                  authstatus = check_authentication(auth_hdr, 
			     new_data, newlength, auth_len, asym_keyid, 
			     authmessage, AUTHMESSAGELEN,
                             addata, authtype);

	        } else {

/* X.509 authentication has been used - this has not been checked */

/* check whether the x509state variable is on - if not then ignore the auth */

                  Tcl_Eval(interp, "x509state");

                  if (strcmp(interp->result,"1") == 0) {

	            irand = (lblrandom()&0xffff);
                    strncpy(authstatus, \
			    check_x509_authentication(auth_hdr, 
				((char *)bp+sizeof (struct sap_header)+2), 
                                new_data, newlength, auth_len, asym_keyid, 
                                irand,authmessage, AUTHMESSAGELEN),
			    AUTHSTATUSLEN);
	            store_x509_authentication_in_memory(addata, authtype, irand);
                  } else { 
	            strncpy(authstatus,"noauth",AUTHSTATUSLEN);
		    strcpy(authmessage,"The session contained an x509 digital signature which has not been checked"); 
                  }

                }

	        has_authentication = 1;
	        has_security       = 1;

              } else {
                writelog(printf("lce: unknown version (%d) in auth header\n",auth_hdr->version);)
                retval = -1;
		goto out;
              }

	    } else {

/* there was no authentication */

              memset(authstatus,  0, AUTHSTATUSLEN);
              memset(authtype,    0, AUTHTYPELEN);
              memset(authmessage, 0, AUTHMESSAGELEN);
	      strncpy(authstatus,  "noauth", AUTHSTATUSLEN);
	      strncpy(authtype,    "none",   AUTHTYPELEN);
	      strncpy(authmessage, "none",   AUTHMESSAGELEN);

	    }

/* This version of sdr can't deal with compressed payloads */

	    if (bp->compress==1) {
	      printf("compresion is set");
	    }
          }

/* add the details to the linked list of adverts */

          if (addata != NULL) {

            if (origsrc != hostaddr) {
              if (first_ad==NULL) {
                first_ad=addata;
                last_ad=addata;
                addata->prev_ad=NULL;
                no_of_ads=1;
              } else {
                last_ad->next_ad=addata;
                addata->prev_ad=last_ad;
                last_ad=addata;
                no_of_ads++;
              }
              addata->aid=(char *)malloc(strlen(aid)+1);
              strcpy(addata->aid, aid);
            }

            endtime = parse_entry(aid, p, strlen(p),  origsrc, src, sap_addr, 
                 sap_port, t, trust, key, authtype, authstatus, &data_len, 
                 asym_keyid, enctype, encstatus,&enc_data_len, 
                 enc_asym_keyid,authmessage,encmessage);
    
            if ((origsrc==hostaddr) && (strcmp(trust,"trusted")==0)) {
              queue_ad_for_sending(aid, advert, INTERVAL, endtime, sap_addr, 
                     sap_port, (unsigned char)ttl, keyname, authtype, 
                     authstatus, enctype, encstatus, addata); 
            }
          } else {
            retval = -1;
	    goto out;
          }
      }

out:
      free(new_data);
      free(authstatus);
      free(authtype);
      free(authmessage);
      free(encstatus);
      free(enctype);
      free(encmessage);
      free(encstatus_p);
      return TCL_OK;
}


/* ---------------------------------------------------------------------- */
/* main                                                                   */
/* ---------------------------------------------------------------------- */
int main(argc, argv)
int argc;
char *argv[];
{
    int i;
    int inChannel;
    struct in_addr in;
    struct hostent *hstent;
    char *p;

    seedrand();
    signal(SIGINT, (void(*))clean_up_and_die);
#ifdef SIGQUIT
    signal(SIGQUIT, (void(*))clean_up_and_die);
#endif
    signal(SIGTERM, (void(*))clean_up_and_die);

    setlocale(LC_NUMERIC, "C");
    putenv("LC_NUMERIC=C");

/*  find our own address  */

    gethostname(hostname, TMPSTRLEN);
    if (hostname[0] == '\0') {
      fprintf(stderr, "gethostname failed!\n");
      exit(1);
    }
    writelog(printf("0. >%s<\n", hostname));
    hstent=(struct hostent*)gethostbyname(hostname);
    if (hstent == (struct hostent*) NULL) {
      fprintf(stderr, "gethostbyname failed (hostname='%s'!\n", hostname);
      exit(1);
    }
    memcpy((char *)&hostaddr,(char *)hstent->h_addr_list[0], hstent->h_length);

/* If the version of the hostname from the lookup contains dots and is       */
/* longer than the hostname given by gethostname, it's probably a better bet */

    if ((strchr(hstent->h_name,'.')!=NULL)&&
      (strlen(hstent->h_name)>strlen(hostname))) 
      strcpy(hostname, hstent->h_name);

    writelog(printf("1. >%s<\n", hostname));

/* If the primary name of the host can't be a FQDN, try any aliases */

    if (strchr(hostname, '.')==NULL) {
      char **a;
      for(a = hstent->h_aliases; *a != 0; a++) {
	if (strchr(*a,'.')!=NULL) {
	  strcpy(hostname, *a);
	  break;
	}
      }
    }
    
    writelog(printf("2. >%s<\n", hostname));
    if (strchr(hostname, '.')==NULL) {

/* OK, none of the aliases worked. Next, we can try to look in */
/* /etc/resolv.conf - if this isn't Unix, this won't work      */

      FILE *dnsconf;
      dnsconf=fopen("/etc/resolv.conf", "r");
      if (dnsconf!=NULL) {
	struct hostent *testhstent;
	char dnsbuf[256], testbuf[256], *cp;
        /* at least the file's there...*/
	while(feof(dnsconf)==0) {
	  fgets(dnsbuf, 255, dnsconf);
	  cp=dnsbuf;
	  /*trim any left whitespace*/
	  while (((cp[0]==' ')||(cp[0]=='\t'))&&(cp-dnsbuf<255)) cp++;
	  if (strncmp(cp, "domain", 6)==0) {
            /* the domain is specified*/
	    cp+=6;
	    /*trim left whitespace*/
	    while (((cp[0]==' ')||(cp[0]=='\t'))&&(cp-dnsbuf<255)) cp++;
	    /*build a name to test*/
	    strcpy(testbuf, hostname);
	    strcat(testbuf, ".");
	    strcat(testbuf, cp);
	    /*remove trailing whitespace*/
	    p = testbuf + strlen(testbuf);
	    while (*p == '\0' || *p == ' ' || *p == '\t'
		    || *p == '\n' || *p == '\r')
	      *p-- = '\0';
	    
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
	fclose(dnsconf);
      }
    }
    writelog(printf("3. >%s<\n", hostname));

/* Anyone got any idea what to do if we still haven't obtained a */
/* fully qualified domain name by this point?                    */

/* If it still doesn't contain any dots, give up and use the address */

    in.s_addr=htonl(hostaddr);
    if (strchr(hostname, '.')==NULL)
      strcpy(hostname,(char *)inet_ntoa(in));

    writelog(printf("4. >%s<\n", hostname));

    hostaddr=ntohl(hostaddr);
    
/* find the user's username */
    strcpy(username, "noname");
#ifndef WIN32
    {
	uid_t uid=getuid();
	struct passwd* pswd=getpwuid(uid);
	if(pswd!=0)
	  strncpy(username, pswd->pw_name, TMPSTRLEN);
    }
#else
    {
	int nmsize = TMPSTRLEN;
	GetUserName(username, &nmsize);
    }
#endif
    strncpy(sipalias, username, MAXALIAS);

    doexit=TRUE;
    debug1=FALSE;
    logging=FALSE;
    gui=GUI;
    cli=FALSE;
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
	if(strncmp(argv[i], "-cli", 7)==0)                      
           {                                                    
             cli=TRUE;
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

    sip_udp_rx_sock=sip_udp_listen(SIP_GROUP, SIP_PORT);
    sip_tcp_rx_sock=sip_tcp_listen(SIP_PORT);

    if (sip_udp_rx_sock!=-1)
      linksocket(sip_udp_rx_sock, TK_READABLE, (Tcl_FileProc*)sip_recv_udp);
    if (sip_tcp_rx_sock!=-1)
      linksocket(sip_tcp_rx_sock, TK_READABLE, (Tcl_FileProc*)sip_recv_tcp);
    else {
      while (sip_tcp_rx_sock==-1) {
	fprintf(stderr, "Failed to open SIP TCP socket\n");
#ifndef WIN32
/* unix time is in seconds windows is in milliseconds */
	sleep(5);
#else
	Sleep (5000);
#endif
	sip_tcp_rx_sock=sip_tcp_listen(SIP_PORT);
      }
      linksocket(sip_tcp_rx_sock, TK_READABLE, (Tcl_FileProc*)sip_recv_tcp);
    }
/* end of sip listen */

/* load the cached sessions */

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
#ifndef WIN32
    /*Set up the file handler for the Command Line Interface*/
    if (cli) {
      init_cli();
      inChannel = fileno(stdin);
      Tcl_CreateFileHandler(inChannel, TCL_READABLE, (Tcl_FileProc*)do_cli, (ClientData) inChannel);
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

/*-----------------------------------------------------------------------*/
/* recv_packets - handle the incoming data                               */
/* in = buf                                                              */
/*-----------------------------------------------------------------------*/
void recv_packets(ClientData fd)
{
    struct advert_data *advert=NULL, *addata=NULL;
    struct sap_header *bp;
    struct sockaddr_in from;
    struct timeval tv;
    struct priv_header *enc_p=NULL;
    struct auth_header *auth_hdr=NULL;

    unsigned char aid[AIDLEN];
    unsigned char *data=NULL;
    unsigned char *debugbuf=NULL;
    unsigned char *buf=NULL;

    char enc_asym_keyid[ASYMKEYIDLEN], *encstatus_p=NULL, *enctype=NULL;
    char encstatus[ENCSTATUSLEN];
    char asym_keyid[ASYMKEYIDLEN],authtype[AUTHTYPELEN];
    char authstatus[AUTHSTATUSLEN];
    char authmessage[AUTHMESSAGELEN], *encmessage=NULL;
    char keyname[MAXKEYLEN];
    char recvkey[MAXKEYLEN];
    char *tmpauthptr=NULL;
    unsigned char new_data[MAXADSIZE];

    int fromlen;
    int length=0, orglength=0;
    int has_security=0;
    int hdr_len=0, enctmp=0, has_encryption=0;
    int auth_len=0, authtmp=0, found=0, has_authentication=0;
    int newlength=0;
    int irand;

    unsigned long src, hfrom;
    unsigned long endtime;

    int ix = rfd2sock[PTOI(fd)];

    writelog(printf("entered recv_packets\n");)

    fromlen=sizeof(struct sockaddr);

/* set up keyids */

    strcpy(asym_keyid,"notset");
    strcpy(enc_asym_keyid,"notset");
    
/* receive the data */

    buf = (char *)malloc(MAXADSIZE);
    if ((length = recvfrom(rxsock[ix], (char *) buf, MAXADSIZE, 0,
		       (struct sockaddr *)&from, (int *)&fromlen)) < 0) {
      perror("recv error");
      free(buf);
      return;
    }

/* some sneaky bugger is trying to splat the stack?  */

    if (length==MAXADSIZE) {
      if (debug1==TRUE)
	fprintf(stderr, "Warning: 2K announcement truncated\n");
    }
    gettimeofday(&tv, NULL);

/* cast buf into sap_header bp */

    bp = (struct sap_header *) buf;

/* if debugging have a look at the header */

    writelog(printf("recv_packets: bp: version=%d type=%d enc=%d compress=%d authlen=%d msgid=%d src=%lu\n",bp->version, bp->type, bp->enc, bp->compress, bp->authlen, bp->msgid, ntohl(bp->src));)

/* save a copy of the original buffer */

    debugbuf = (char *)malloc(length);
    memcpy(debugbuf, buf, length);
    orglength = length;

/* determine the addresses */

    src     = ntohl(bp->src);
    hfrom   = ntohl(from.sin_addr.s_addr);

/* set data to point after the originating source field */

    data    = (char *)((char *)bp+sizeof(struct sap_header));
    length -= sizeof(struct sap_header);

/* sanity check */

    if (length < 30) {
      if (debug1==TRUE) 
	fprintf(stderr,"unacceptably short announcement received and ignored\n");
      goto out;
    }

/* Ignore announcements with later SAP versions than we can cope with */

    if (bp->version > 1) {
      if (debug1==TRUE) 
	fprintf(stderr,"announcement with version>1 received and ignored\n");
      goto out;
    }

/* Due to lack of space the authlen in the header was length/4 - recalculate */

    auth_len = bp->authlen*4;

/* create the advert_data structure to store details in the linked list */

    addata = (struct advert_data *)malloc(sizeof(struct advert_data));
    addata->sap_hdr  = NULL;
    addata->sapenc_p = NULL;
    addata->authinfo = NULL;
    addata->encrypt  = 0;

/* is the announcement encrypted ? */
/* need these even if it isn't     */

    enctype     = (char *)malloc(ENCTYPELEN);
    encmessage  = (char *)malloc(ENCMESSAGELEN);
    encstatus_p = (char *)malloc(8);

    if ( bp->enc == 1 ) {

/* create the privacy header part of the advert_data structure */

      addata->sapenc_p=(struct priv_header *)malloc(sizeof(struct priv_header));

/* set privacy header pointer to point to the received privacy header */

      enc_p = (struct priv_header *) ((char *)bp+sizeof(struct sap_header)
                 +auth_len+TIMEOUT);

/* if debugging have a look at the privacy header we received */

      writelog(printf("recv_pkts: enc_p->version=%d padding=%d enc_type=%d hdr_len=%d\n",enc_p->version,enc_p->padding,enc_p->enc_type,enc_p->hdr_len) ;)

/* check the version of the privacy header */

      if (enc_p->version != 1) {
        writelog(printf("recv_pkts: error: enc_p->version = %d\n",enc_p->version);)
        goto bad;
      }

/* skip timeout */

      data    += auth_len+TIMEOUT;
      length  -= auth_len+TIMEOUT;

/* look at the encryption type and check we can decrypt the message */

      switch (enc_p->enc_type) {

        case PGP:

          strcpy(enctype,"pgp");
          strcpy(recvkey,"");

/* don't try to decrypt it if PGPSTATE isn't set */

          Tcl_Eval(interp, "pgpstate");
          if (strcmp(interp->result,"1") == 0) {
            if (check_encryption(enc_p,data,length,enc_asym_keyid,encmessage,ENCMESSAGELEN,addata, enctype) != 0) {
              strcpy(encstatus_p,"failed");
              writelog(printf("recv_pkts: PGP decryption failed\n");)
              goto bad;
            } else {
              strcpy(encstatus_p,"success");
              has_encryption = 1;
              has_security   = 1;
            }
          } else {
            encstatus_p="failed";
            return;
          }
          break;

        case PKCS7:

/* This is X.509 code and hasn't been checked */

          memcpy(enctype,"x509",4);
          strcpy(recvkey,"");
          Tcl_Eval(interp, "x509state");
          if (strcmp(interp->result,"1") == 0) {
            encstatus_p=check_x509_encryption(enc_p,
                          ((char *)bp+sizeof (struct sap_header)+auth_len+4),
                          data, length, hdr_len, enc_asym_keyid, irand,
                          encmessage, ENCMESSAGELEN);
            store_x509_encryption_in_memory(addata, enctype, irand);
            has_encryption = 1;
            has_security   = 1;
          } else {
            encstatus_p="failed";
            writelog(printf("recv_pkts: PKCS7 decryption failed\n");)
            goto bad;
          }
          break;

        case DES:

          strcpy(enctype,"des");
          if (decrypt_announcement( data, &length, recvkey) != 0) {
            writelog(printf("recv_pkts: DES decryption failed\n");)
            strcpy(encstatus_p,"failed");
            goto bad;
          } else {
            strcpy(encstatus_p,"success");
            addata->encrypt = 1;
            has_encryption  = 2;
            has_security    = 1;
            strncpy(encmessage,"\n\n  Encryption: \tSymmetric (DES)\n  Status: \t\tSuccess\n", ENCMESSAGELEN);
            if (find_keyname_by_key(recvkey, keyname) == 0) {
              strcat(encmessage, "  Key name:\t");
              strcat(encmessage, keyname);
              strcat(encmessage, "\n");
            }
            if (strlen(encmessage)+strlen(recvkey) < ENCMESSAGELEN) {
              strcat(encmessage, "  Key:\t\t");
              strcat(encmessage, recvkey);
            }
          }
          break;

          default:
            writelog(printf("recv_pkts: error: unknown enc_type = %d\n",enc_p->enc_type);)
            goto bad;

        }

/* check that we have a sensible return from the decryption */

        if ( (encstatus_p==NULL) || (strcmp(encstatus_p,"failed")==0)) {
          fprintf(stderr, "recv_pkts: encstatus_p NULL or failed\n");
          goto bad;
        }

        strcpy(encstatus,encstatus_p);

/* check that txt_data has been set up for PGP/PKCS7 and set data and length */
/* to be the decrypted data - this is done by decrypt_announcement for DES   */

        if (enc_p->enc_type == PGP || enc_p->enc_type == PKCS7) {
          assert(addata->sapenc_p->txt_data != NULL);
          if (strncmp(addata->sapenc_p->txt_data, "v=", 2)==0) {
            memcpy(data,addata->sapenc_p->txt_data,addata->sapenc_p->txt_len);
            length = addata->sapenc_p->txt_len;
          } else {
            writelog(printf("recv_pkts: decrypted buffer not v=...");)
            goto bad;
          }
        }

      } else {

/* here when bp->enc == 0 ie packet was not encrypted */

/* skip the authentication header */

        data   += auth_len;
        length -= auth_len;

/* set the encryption variables to appropriate values */

        strcpy(recvkey,"");
        strcpy(enctype,"none" );
        strcpy(encstatus_p,"noenc");
        strcpy(encmessage,"none" );
        has_encryption = 0;

      }

/* The packet should have been decrypted and data and length should now be */
/* the decrypted payload values. Now see if announcement is authenticated  */

    if ( auth_len != 0) {

      auth_hdr = (struct auth_header *)((char *)bp+sizeof(struct sap_header));

/* if debugging have a look at the authentication header */

      writelog(printf("recv_packets: auth_hdr : version = %d, padding = %d, auth_type = %d, siglen = %d\n",auth_hdr->version, auth_hdr->padding, auth_hdr->auth_type, auth_hdr->siglen);)

/* fill new_data with original packet but set msg_id=0 and remove the */
/* auth_hdr because of signature. Dunno why set msgid=0               */

      newlength = gen_new_auth_data(debugbuf,new_data,bp,auth_len,orglength);

/* check the version of the authentication header */

      if (auth_hdr->version != 1) {
        writelog(printf("recv_pkts: error: unknown auth_hdr->version = %d\n",auth_hdr->version);)
        goto bad;
      }

/* check on the type of authentication used              */
/* The certificate ones are obsolete and will be removed */

       if (auth_hdr->auth_type == authPGP) {
         strcpy(authtype, "pgp");
       } else if (auth_hdr->auth_type == authX509) {
         strcpy(authtype, "x509");
       } else {
         writelog(printf("recv_pkts: bad auth_type=%d\n",auth_hdr->auth_type);)
         goto bad;
       }

/* set up the addata->authinfo */

      addata->authinfo = (struct auth_info *)malloc(sizeof(struct auth_info));

/* check authentication */

      if (auth_hdr->auth_type==authPGP) {

/* PGP authentication used */

        tmpauthptr = check_authentication(auth_hdr,
                             new_data, newlength, auth_len, asym_keyid,
                             authmessage, AUTHMESSAGELEN, addata, authtype);
        strcpy(authstatus,tmpauthptr);

        writelog(printf("recv_pkts: authstatus  = %s\n",authstatus);)
        writelog(printf("recv_pkts: authmessage = %s\n",authmessage);)

        has_authentication = 1;
        has_security       = 1;

      } else if (auth_hdr->auth_type==authX509 || auth_hdr->auth_type==authX509C) {

/* PKCS7 authentication used - this hasn't been checked */

        Tcl_Eval(interp, "x509state");

        if (strcmp(interp->result,"1") == 0) {
          irand = (lblrandom()&0xffff);
          strncpy(authstatus, 
                  check_x509_authentication(auth_hdr,
                    ((char *)bp+sizeof (struct sap_header)+2),
                    new_data, newlength, auth_len, asym_keyid,
                    irand,authmessage,AUTHMESSAGELEN), 
                  AUTHSTATUSLEN);
          store_x509_authentication_in_memory(addata, authtype, irand);
          has_authentication = 1;
          has_security       = 1;

        } else {

/* PKCS7 used but "x509state" environment variable is not set so ignore it */

          strncpy(authstatus, "noauth", AUTHSTATUSLEN);
          strncpy(authtype,"none",AUTHTYPELEN);
          strncpy(authmessage,"The session contained an x509 digital signature, the signature has not been checked", AUTHMESSAGELEN);
        }
      }

    } else {

/* no authentication has been used */

      strcpy(authstatus,  "noauth");
      strcpy(authtype,    "none");
      strcpy(authmessage, "none");
    }

/* should now have finished decryption and authentication so back to normal */

/* If you goof up the bit packing a normal advert can look compressed.      */
/* If version = 0, ignore the compressed flag because it was not defined in */
/* version 0, and assume that it's a badly packed "version = 1".            */

      if (bp->compress==1) {
	if (bp->version == 0) {
	    writelog(printf("recv_pkts: compress=1 & vers == 0, process anyway\n"));
	    bp->compress = 0;
	} else {
#ifdef HAVE_ZLIB
	    z_stream zs;
	    char *newdata;
	    int mallsize = MAXADSIZE;
	    int res;
	    int gzip = 0;

	    writelog(printf("uncompressing announcement\n"));
	    /*
	     * zlib has hooks for reading and writing gzip-format files,
	     * but does not have hooks for gzip format in memory-to-memory.
	     * Therefore, we duplicate most of the functionality of
	     * zlib's gzio.c here.
	     *
	     * If the magic number doesn't match the gzip format (RFC 1952),
	     * see if the header checksum matches for zlib format (RFC 1950).
	     */
	    if (*data == 0x1f && *(data + 1) == 0x8b) {
		int flags;

		gzip = 1;
		if (*(data + 2) != 0x08) {
		    writelog(printf("got gzip but unsupported compression type\n"));
		    goto bad;
		}
		flags = *(data + 3);
		if ((flags & 0xe0) != 0) {
		    writelog(printf("got gzip but reserved flags set\n"));
		    goto bad;
		}
		/* Skip fixed header: magic thru OS */
		data += 10;
		length -= 10;
		if ((flags & 0x04) != 0) {
		    int xlen;

		    xlen = *data + (*(data + 1) << 8);
		    data += xlen;
		    length -= xlen;
		    if (length <= 0) {
			writelog(printf("gzip: EXTRA too long\n"));
			goto bad;
		    }
		}
		if ((flags & 0x08) != 0) {
		    while (*data && length > 0) {
			data++;
			length--;
		    }
		    data++;
		    length--;
		    if (length <= 0) {
			writelog(printf("gzip: NAME too long\n"));
			goto bad;
		    }
		}
		if ((flags & 0x10) != 0) {
		    while (*data && length > 0) {
			data++;
			length--;
		    }
		    data++;
		    length--;
		    if (length <= 0) {
			writelog(printf("gzip: COMMENT too long\n"));
			goto bad;
		    }
		}
		if ((flags & 0x02) != 0) {
		    /* check header CRC? */
		    data += 2;
		    length -= 2;
		    if (length <= 0) {
			writelog(printf("gzip: not enough data for HCRC\n"));
			goto bad;
		    }
		}
		length -= 8;	/* Skip CRC32 and orig. length at end */
	    } else if ((((*data << 8) + *(data + 1)) % 31) != 0) {
		/* Fails zlib header check; must be garbage. */
		writelog(printf("unknown compression type\n"));
	    }
	    writelog(printf("working on %s-compressed announcement\n",
				gzip ? "gzip (RFC1952)" : "zlib (RFC1950)"));

	    zs.next_in = data;
	    zs.avail_in = length;
	    zs.total_in = 0;

	    newdata = (char *)malloc(mallsize);

	    zs.next_out = newdata;
	    zs.avail_out = mallsize;
	    zs.total_out = 0;

	    zs.zalloc = Z_NULL;
	    zs.zfree = Z_NULL;
	    zs.opaque = Z_NULL;

	    if (inflateInit2(&zs, gzip ? -MAX_WBITS : MAX_WBITS) != Z_OK) {
		writelog(printf("inflateInit: %s\n", zs.msg ? zs.msg : "no zlib error reported"));
		free(newdata);
		goto bad;
	    }

	    /*
	     * If we didn't supply enough ouptut buffer, inflate()
	     * will return Z_OK with zero zs.avail_out .  Then we
	     * realloc the buffer and keep trying.
	     */
	    /*XXX Z_SYNC_FLUSH?  Z_FINISH? */
	    while ((res = inflate(&zs, Z_NO_FLUSH)) != Z_STREAM_END) {
		if (res == Z_OK && zs.avail_out == 0) {
		    mallsize *= 2;
		    if (mallsize > 10*MAXADSIZE) {	/*XXX*/
			writelog(printf("compressed ad inflates too big\n"));
			free(newdata);
			goto bad;
		    }
		    newdata = realloc(newdata, mallsize);
		    zs.avail_out = mallsize - zs.total_out;
		    zs.next_out = newdata + zs.total_out;
		} else {
		    writelog(printf("inflate returns %d %s\n", res, zs.msg ? zs.msg : "no zlib error reported"));
		    inflateEnd(&zs);
		    free(newdata);
		    goto bad;
		}
	    }
	    if (gzip) {
		unsigned long origcrc;
		unsigned long origlen;

		/*
		 * We subtracted 8 from the length above, so now we're
		 * sure there are 8 bytes available.
		 */
		data += length;
		origcrc = (*data + (*(data + 1) << 8) + (*(data + 2) << 16) +
				(*(data + 3) << 24));
		if (origcrc != crc32(0, newdata, zs.total_out)) {
		    writelog(printf("gzip CRC32 mismatch - orig=%x, calc=%x\n",
			origcrc, crc32(0, newdata, zs.avail_out)));
		    free(newdata);
		    goto bad;
		}
		data += 4;
		origlen = (*data + (*(data + 1) << 8) + (*(data + 2) << 16) +
				(*(data + 3) << 24));
		if (origlen != zs.total_out) {
		    writelog(printf("gzip orig. length mismatch\n"));
		    free(newdata);
		    goto bad;
		}
	    }
	    free(buf);	/*XXX*/
	    buf = data = newdata;	/*XXX*/
	    length = zs.total_out;
	    inflateEnd(&zs);
#else
	    writelog(printf("compressed announcement & vers != 0!\n"));
	    goto bad;
#endif
	}
      }

/* debugging info - leave in for the moment */

      writelog(printf("recv_packets: calling parse_entry\n");)
      writelog(printf(" no advertid yet length=%d, src=%lu, hfrom=%lu\n",
         length,src,hfrom);)
      writelog(printf(" sap_addr=%s sap_port=%d, time_t=%d, recvkey=%s\n",
         rx_sock_addr[ix],rx_sock_port[ix],(int)tv.tv_sec,recvkey);)
      writelog(printf(" auth type=%s, status=%s, keyid=%s\n",
         authtype,authstatus,asym_keyid);)
      writelog(printf(" enc  type=%s, status=%s, keyid=%s\n",
         enctype,encstatus_p,enc_asym_keyid);)
      writelog(printf(" authmessage= %s\n",authmessage);)
      writelog(printf("  encmessage= %s\n",encmessage);)
 
/* if someone else is repeating our announcements, be careful not to       */
/* re-announce their modified version ourselves                            */

      strcpy(aid, "BAD");
      if (src == hfrom || src != hostaddr) {
        writelog(printf("calling parse_entry with trust = trusted\n");)
	endtime=parse_entry(aid, data, length, src, hfrom,
	    rx_sock_addr[ix], rx_sock_port[ix],
	    tv.tv_sec, "trusted", recvkey, authtype, authstatus,
	    &authtmp, asym_keyid,enctype,encstatus_p,&enctmp,
            enc_asym_keyid,authmessage,encmessage) ;
	} else {
          writelog(printf("calling parse_entry with trust = untrusted\n");)
	  endtime=parse_entry(aid, data, length, src, hfrom,
	    rx_sock_addr[ix], rx_sock_port[ix],
	    tv.tv_sec, "untrusted", recvkey, authtype, authstatus,
	    &authtmp, asym_keyid,enctype,encstatus_p,&enctmp,
            enc_asym_keyid,encmessage,authmessage);
	}

/* debugging info - leave in for the moment */

      writelog(printf("recv_packets: returned from parse_entry\n");)
      writelog(printf(" advertid=%s length=%d, src=%lu, hfrom=%lu\n",
         aid,length,src,hfrom);)
      writelog(printf(" sap_addr=%s sap_port=%d, time_t=%d, recvkey=%s\n",
         rx_sock_addr[ix],rx_sock_port[ix],(int)tv.tv_sec,recvkey);)
      writelog(printf(" auth type=%s, status=%s, keyid=%s\n",
         authtype,authstatus,asym_keyid);)
      writelog(printf(" enc  type=%s, status=%s, keyid=%s\n",
         enctype,encstatus_p,enc_asym_keyid);)
      writelog(printf(" authmessage= %s\n",authmessage);)
      writelog(printf("  encmessage= %s\n",encmessage);)

/* Store received authentication data in the linked list                */
/* overwrite existing data if this is a repeated/modified announcement  */

	if (hfrom !=hostaddr && (has_security==1 )) {
	  if (first_ad!=NULL) {
	    advert=first_ad;
	    do
	    {
	       if (strcmp(advert->aid, aid)==0) {
	 	found=1;
	       } else {
	         advert=advert->next_ad;
	       }
	     } while ((advert!=last_ad->next_ad) && !found);
           }
	 }
	
	 if (!found) {
           if ( addata != NULL ) {
	     addata->aid=strdup(aid);
             addata->end_time = endtime;
	     addata->sap_hdr = malloc(sizeof(struct sap_header));
             memcpy(addata->sap_hdr, bp, sizeof(struct sap_header));
	     addata->next_ad = NULL;
	     if(first_ad==NULL) {
	       first_ad=addata;
	       last_ad=addata;
	       addata->prev_ad=NULL;
	       no_of_ads=1;
	     } else {
	       last_ad->next_ad=addata;
	       addata->prev_ad=last_ad;
	       last_ad=addata;
	       no_of_ads++;
	     }
	   } 
	 } else {

/* This is a repeated announcement */

/* Free up the old copy of the authentication info and replace it with the */
/* new copy from the packet                                                */

	   if (advert->authinfo!=NULL) {
	     free(advert->authinfo->signature);
	     free(advert->authinfo);
	   }
	   writelog(printf("RP: advert->authinfo freed (%x)\n", (unsigned int)(advert->authinfo)); )
	   advert->authinfo = addata->authinfo;
	   writelog(printf("RP: advert->authinfo set to addata->authinfo: %x\n",
		  (unsigned int)addata->authinfo);)
	   if (advert->sapenc_p!=NULL) {
	     free(advert->sapenc_p->enc_data);
	     free(advert->sapenc_p->txt_data);
	     free(advert->sapenc_p);
	   }
	   advert->sapenc_p=addata->sapenc_p;
	   free(addata);
	 }

/* free some variables */

out:
      free(buf);
      free(debugbuf);
      free(enctype);
      free(encmessage);
      free(encstatus_p);
      return;
bad:
      if (addata->sapenc_p)
	free(addata->sapenc_p);
      if (addata->authinfo)
	free(addata->authinfo);
      if (addata->sap_hdr)
	free(addata->sap_hdr);
      free(addata);
      goto out;
}

static void set_time(const char* var, int i, time_t t)
{
	char buf[256]="";

	sprintf(buf,
          "set %s(%d) [clock format %u -format {%%d %%b %%Y %%H:%%M %%Z}]",
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

/*-----------------------------------------------------------------------*/
/* parse_entry - parse the SDP payload or cache entry etc                */
/*-----------------------------------------------------------------------*/
unsigned long parse_entry(char *advertid, char *data, int length,
        unsigned long src, unsigned long hfrom,
        char *sap_addr, int sap_port, time_t t, char *trust,
        char *recvkey, char *authtype, char *authstatus, int *data_len,
        char *asym_keyid, char *enctype, char *encstatus, int *enc_data_len,
        char *enc_asym_keyid,char *authmessage,char *encmessage)
{
    int i;
    static char namestr[MAXADSIZE]="";
    char *cur, *end, *attr, *unknown, *version, *session=NULL, *desc=NULL, 
         *orig=NULL, *chan[MAXMEDIA], *media[MAXMEDIA], *times[MAXTIMES], 
         *rpt[MAXTIMES][MAXRPTS], *uri, *phone[MAXPHONE], *email[MAXPHONE], 
         *bw[MAXBW], *key[MAXKEY], *data2;
    int mediactr, tctr, pctr, ectr, bctr, kctr, uctr;
    char vars[MAXMEDIA][TMPSTRLEN];
    char debug=0;
    char *tag, *mediakey[MAXMEDIA], *fullkey=NULL;
    char tmpstr[TMPSTRLEN]="", fmt[TMPSTRLEN]="", proto[TMPSTRLEN]="",
         heardfrom[TMPSTRLEN]="", origsrc[TMPSTRLEN]="", creator[TMPSTRLEN]="",
         sessvers[TMPSTRLEN]="", sessid[TMPSTRLEN]="", portstr[TMPSTRLEN]="",
         createaddr[TMPSTRLEN]="", in[TMPSTRLEN]="", ip[TMPSTRLEN]="";
    char *p;
    int ttl, mediattl, medialayers, code, port, origlen, nports;
    unsigned int time1[MAXTIMES], time2[MAXTIMES], rctr[MAXTIMES], timemax;
    struct in_addr source;
    struct in_addr maddr;
    struct timeval tv;

    writelog(printf("parse_entry: > entered parse_entry\n");)

/* Have a quick look at what got passed in if debugging */

/* make sure we have a termination character at the end of the data */
/* - isn't this handled in a few lines anyway ?                     */


    strcpy(data+length,"\0");

/* clear keys */

     for (i=0; i < MAXKEY; i++) {
      key[i]=NULL;
    }

    for (i=0; i < MAXMEDIA; i++) {
      mediakey[i]=NULL;
    }

/* check the termination character for the data is okay */
 
    if (data[length-1]!='\n') {
      if (debug1) {
	fprintf(stderr, "Announcement doesn't end in LF - will try to fix \n");
      }
      if (data[length-1]=='\0') {
/* someone sent the end of string character - illegal but we'll accept it*/
	if (debug1) {
	  fprintf(stderr, "Illegal end-of-string character - removed!\n");
        }
	if (data[length-2]=='\n') {
	    length--;
	} else {
	    data[length-1]='\n';
	}
      } else {
/* someone simply missed off the NL at end of the announcement also illegal */
/* but again we'll be liberal in what we accept                             */
	data[length]='\n';
	length++;
      }
    }

/* malloc some space for debugging and keep a note of the original length */

    if (debug1) {
      data2=(char *)malloc(length);
      memcpy(data2, data, length);
    } else {
      data2=data;
    }
    origlen = length;

/* Now we can start to look at the data                                   */
/* check we have a version field at the start and that it is 0            */

    if (strncmp(data, "v=", 2)!=0) {
      if (length==0) {
        goto errorleap;
      }
      if (debug1) {
        fprintf(stderr, "doesn't start with v=\n");
      }
      dump(data2, origlen);
      goto errorleap;
    } else {
      version=data+2;
      if ((strncmp(version, "0\n", 2)!=0)&&(strncmp(version, "0\r", 2)!=0)) {
        goto errorleap;
      }
      length-=2;
    }

    if(((end=strchr(version, 0x0a)) == NULL)||(debug == 1)) {
      if (debug1)
	fprintf(stderr, "No end to version\n");
      dump(data2, origlen);
      goto errorleap;
    }

    *end++ = '\0';
    length -= end-version;
    source.s_addr=htonl(hfrom);
    strncpy(heardfrom, (char *)inet_ntoa(source), 16);
    source.s_addr=htonl(src);
    strncpy(origsrc, (char *)inet_ntoa(source), 16);

/* loop through the rest of the data looking at the various SDP fields */

    i = 0;
    mediactr=0;  tctr=0;  pctr=0;  ectr=0;  bctr=0;  kctr=0;
    session=0;
    uctr=0; chan[0]=NULL; chan[1]=NULL; timemax=0;
    vars[0][0]='\0';

    while (length > 0) 
      {
                cur = end;
		if (*(cur + 1) != '=') {
		    if (debug1)
			printf("no = at byte %d\n", end-data);
		    dump(data2, origlen);
		    goto errorleap;
		}
                switch (*cur) {
		case 's':
		        /* session description */
		        session = end+2;
                        if ((end=strchr(session, 0x0a)) == NULL) {
			  if (debug1) 
			  {
			    printf("Error decoding session\n");
			    printf("Failure at byte %d\n", session-data);
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
			    printf("Failure at byte %d\n", desc-data);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(desc);
                        length -= end-cur;
                        break;

                case 'u':
                        /* session URI */
                        uri = end+2;
			uctr++;
                        if ((end=strchr(uri, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding URI\n");
			    printf("Failure at byte %d\n", uri-data);
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
			    printf("Failure at byte %d\n", orig-data);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(orig);
                        length -= end-cur;
                        break;
                case 'e':
                        /* print email */
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
			    printf("Failure at byte %d\n", email[ectr]-data);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(email[ectr++]);
                        length -= end-cur;
                        break;
                case 'p':
                        /* print phone */
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
			    printf("Error decoding phone\n");
			    printf("Failure at byte %d\n", phone[pctr]-data);
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
			    printf("Failure at byte %d\n", chan[mediactr]-data);
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
			    printf("Failure at byte %d\n", bw[bctr-1]-data);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(bw[bctr++]);
                        length -= end-cur;
                        break;
                case 't':
                        /* print time */
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
                        /* print repeat */
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
                        /* print keys */
                        if (kctr<MAXKEY)
                          {
                            key[++kctr] = end+2;
                          } else {
			    if (debug1==TRUE)
			      fprintf(stderr, "Too many keys\n");
			    goto errorleap;
			  }
                        if ((end=strchr(key[kctr], 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding key\n");
			    printf("Failure at byte %d\n", key[kctr]-data);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
                        remove_cr(key[kctr]);

/* have something like "clear:key" "base64:key" etc in key[kctr] */
 
                        fullkey = key[kctr];

/* see if we understand the tag - only handle "clear" at the moment */ 

                        tag = strtok(fullkey,":");
                        if (tag == NULL) {
                          if (debug1==TRUE) {
                              fprintf(stderr, "No keytag found with key\n");
                          }
                          goto errorleap;
                        } else {
                          if (strcmp(tag,"clear")==0) {
                            fullkey = fullkey + strlen(fullkey) + 1;
                          } else {
                            if (debug1==TRUE) {
                              fprintf(stderr, "Can't handle %s keytag\n",tag);
                            }
                            goto errorleap;
                          }
                        }
 
                        mediakey[mediactr] = malloc(MAXKEYLEN);
                        if (strlen(fullkey) > MAXKEYLEN ) {
                          if (debug1) {
                            printf("Mediakey too long - it has been truncated\n");
                          }
                          strncpy(mediakey[mediactr],fullkey,MAXKEYLEN-1);
			  mediakey[mediactr][MAXKEYLEN-1] = '\0';
                        } else {
                          strcpy(mediakey[mediactr],fullkey);
                        }

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
			    printf("Failure at byte %d\n", media[mediactr]-data);
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
                        /* print attribute */
                        attr = end+2;
                        if ((end=strchr(attr, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding attribute\n");
			    printf("Failure at byte %d\n", attr-data);
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
			      printf("Failure at byte %d\n", unknown-data);
			    }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
			remove_cr(unknown);
                        length -= end-cur;
			break;
                case 'Z':
		case 'z':	/*XXX transitional - must be removed */
                        /* signature - not in packet stream! */
			if (data_len)
			  *data_len = (int)( (end+3) - data );
                        length = 0;
                        break;

                default:
                        /* unknown */
                        unknown = end;
                        if ((end=strchr(unknown, 0x0a)) == NULL) {
			  if (debug1)
			  {
			    printf("Error decoding unknown\n");
			    printf("Failure at byte %d\n", unknown-data);
			  }
			  dump(data2, origlen);
			  goto errorleap;
                        }
                        *end++ = '\0';
                        length -= end-cur;
			if (debug1)
			  printf("Warning: unknown option - >%s<\n", unknown);
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

/* ensure that Tcl's error recovery hasn't left any unwanted state around */

    code = Tcl_GlobalEval(interp, "reset_media");
    if (code != TCL_OK) {
      if (debug1==TRUE) {
       fprintf(stderr, "%s\n", interp->result);
      }
    }

/* set up some TCL variables from what we have here                      */

    Tcl_SetVar(interp, "asym_cur_keyid",     asym_keyid,     TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "sess_auth_type",     authtype,       TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "sess_auth_status",   authstatus,     TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "sess_auth_message",  authmessage,    TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "enc_asym_cur_keyid", enc_asym_keyid, TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "sess_enc_type",      enctype,        TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "sess_enc_status",    encstatus,      TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "sess_enc_message",   encmessage,     TCL_GLOBAL_ONLY);

    Tcl_SetVar(interp, "trust",              trust,          TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "recvkey",            recvkey,        TCL_GLOBAL_ONLY);

    splat_tcl_special_chars(session);
    Tcl_SetVar(interp, "session", session, TCL_GLOBAL_ONLY);

    splat_tcl_special_chars(desc);
    Tcl_SetVar(interp, "desc", desc, TCL_GLOBAL_ONLY);

/* look at the chan */

    if (chan[0]==NULL) chan[0]=chan[1];

    if (chan[0]==NULL) {
      if (debug1==TRUE) {
	fprintf(stderr, "No channel field received!\n");
      }
      goto errorleap;
    }

    if(strlen(chan[0])>TMPSTRLEN) {
      if (debug1==TRUE) {
	fprintf(stderr, "Unacceptably long channel field received\n");
      }
      chan[0][TMPSTRLEN-1]='\0';
    }

    if (chan[0]!=NULL) {
	sscanf(chan[0], "%s %s %s", in, ip, tmpstr);
	ttl=extract_ttl(tmpstr);
        if (check_net_type(in,ip,tmpstr)<0)
          goto errorleap;
    } else {
	tmpstr[0]='\0';
	ttl=0;
    }

/* look at the timing information */

    for(i=0;i<tctr;i++) {
	char var[20];
	sscanf(times[i], "%u %u", &time1[i], &time2[i]);
	gettimeofday(&tv, NULL);
	if(time1[i]!=0) {
	    unsigned int r;
	    time1[i]-=0x83aa7e80;
	    if (time2[i])
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
	    for(r=0;r<rctr[i];r++) {
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
	  } else {
	    if(i!=0) {
		if (debug1==TRUE)
		  fprintf(stderr, "Illegal infinite session with multiple time fields\n");
		goto errorleap;
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

/* look at the originator field */

    splat_tcl_special_chars(orig);
    if (strlen(orig)>TMPSTRLEN) {
      if (debug1==TRUE)
	fprintf(stderr, "Unacceptably long originator field received\n");
      dump(data2, origlen);
      orig[TMPSTRLEN-1]='\0';
    };
    if (sscanf(orig, "%s %s %s %s %s %s", creator, sessid, sessvers, in, ip, 
	   createaddr) != 6) {
      if (debug1)
	fprintf(stderr, "o= line doesn't have 6 fields\n");
      dump(data2, origlen);
      goto errorleap;
    }
    if (check_net_type(in,ip,createaddr)<0)
      goto errorleap;
    for (p = sessid; *p; p++)
      if (!isdigit(*p)) {
	if (debug1)
	  fprintf(stderr, "non-digit in session ID\n");
	dump(data2, origlen);
	goto errorleap;
      }
    for (p = sessvers; *p; p++)
      if (!isdigit(*p)) {
	if (debug1)
	  fprintf(stderr, "non-digit in session version\n");
	dump(data2, origlen);
	goto errorleap;
      }


    Tcl_SetVar(interp, "creator",    creator,    TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "sessvers",   sessvers,   TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "sessid",     sessid,     TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "createaddr", createaddr, TCL_GLOBAL_ONLY);

/* The PGP Key ID is about as unique as it gets.  So good idea to use it */
/*  for creating the Advert ID.  If a modified session arrives and is    */
/*  authenticated with a different key/not at all, then it will be       */
/*  displayed and stored as a separate session announcement.             */
 
    if (strcmp(authtype,"none" )!=0) {
      strncat(namestr, asym_keyid, 8);
    }

    if (strcmp(enctype,"none")!=0) {
      strncat(namestr, enc_asym_keyid, 8);
    }
         
/* Add some more stuff to the namestr (hashed to create the advertid) */

    sprintf(namestr, "%s%s%s", creator, sessid, createaddr);

/* Create a hash of originator data as advert ID */

    Tcl_VarEval(interp, "get_aid ", namestr, NULL);
    sprintf(namestr, "%s", interp->result);

    if (advertid!=NULL)
      strcpy(advertid, namestr);

    Tcl_SetVar(interp, "advertid",  namestr,   TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "source",    origsrc,   TCL_GLOBAL_ONLY);
    Tcl_SetVar(interp, "heardfrom", heardfrom, TCL_GLOBAL_ONLY);

    sprintf(namestr,
       "set timeheard [clock format %u -format {%%d %%b %%Y %%H:%%M %%Z}]",
	    (unsigned int)t);
    Tcl_GlobalEval(interp, namestr);

/* look at the URI */

    if(uctr>0)
      {
       if (uri!=NULL) {
	splat_tcl_special_chars(uri);
	Tcl_SetVar(interp, "uri", uri, TCL_GLOBAL_ONLY);
       } else {
          Tcl_SetVar(interp, "uri", "", TCL_GLOBAL_ONLY);
        }
      }

/* look at the phone information */

    for(i=0;i<pctr;i++)
      {
        sprintf(namestr,"phone(%d)", i);
	splat_tcl_special_chars(phone[i]);
        Tcl_SetVar(interp, namestr, phone[i], TCL_GLOBAL_ONLY);
      }

/* look at the email information */

    for(i=0;i<ectr;i++)
      {
        sprintf(namestr,"email(%d)", i);
	splat_tcl_special_chars(email[i]);
        Tcl_SetVar(interp, namestr, email[i], TCL_GLOBAL_ONLY);
      }

/* look at the bandwidth */

    for(i=0;i<bctr;i++)
      {
        sprintf(namestr,"bw(%d)", i);
        Tcl_SetVar(interp, namestr, bw[i], TCL_GLOBAL_ONLY);
      }

/* look at the overall media key                                         */
/* tricky one here - have to be careful in the TCL 'cause we can't splat */
/* Tcl special characters here! - at least we will issue a warning       */

    if (kctr>0) {
      warn_tcl_special_chars(key[1]);                              
      Tcl_SetVar(interp, "key", key[1], TCL_GLOBAL_ONLY);
    }

/* look at the session variables */

    splat_tcl_special_chars(vars[0]);
    Tcl_SetVar(interp, "sessvars", vars[0],  TCL_GLOBAL_ONLY);

    for (i=1; i<=mediactr; i++) {

/* this check is to ensure we don't overfill anything in the following scanf */

      if(strlen(media[i])>TMPSTRLEN) {
	if (debug1==TRUE)
	  fprintf(stderr, "Unacceptably long media field received\n");
        dump(data2, origlen);
	media[i][TMPSTRLEN-1]='\0';
      }
      if (sscanf(media[i], "%s %s %s %s", tmpstr, portstr, proto, fmt) != 4) {
	if (debug1==TRUE)
	  fprintf(stderr, "Media description #%d doesn't have 4 fields\n", i);
        dump(data2, origlen);
	goto errorleap;
      }
      nports = 1;
      sscanf(portstr, "%d/%d", &port, &nports);
      Tcl_SetVar(interp, "media", tmpstr, TCL_GLOBAL_ONLY);

      splat_tcl_special_chars(vars[i]);
      Tcl_SetVar(interp, "vars", vars[i],  TCL_GLOBAL_ONLY);

      sprintf(namestr, "%d", port);
      Tcl_SetVar(interp, "port", namestr, TCL_GLOBAL_ONLY);
      sprintf(namestr, "%d", nports);
      Tcl_SetVar(interp, "nports", namestr, TCL_GLOBAL_ONLY);

      splat_tcl_special_chars(proto);
      Tcl_SetVar(interp, "proto", proto, TCL_GLOBAL_ONLY);

      splat_tcl_special_chars(fmt);
      Tcl_SetVar(interp, "fmt", fmt, TCL_GLOBAL_ONLY);

      if(strlen(chan[i])>100) {
	if (debug1==TRUE)
	  fprintf(stderr, "Unacceptably long channel field received\n");
        dump(data2, origlen);
	chan[i][100]='\0';
      }
      sscanf(chan[i], "%s %s %s", in, ip, tmpstr);

      medialayers = extract_layers(tmpstr);
      mediattl    = extract_ttl(tmpstr);
      if (check_net_type(in,ip,tmpstr)<0) {
        dump(data2, origlen);
        goto errorleap;
      }
      if (mediattl>ttl) ttl=mediattl;
      sprintf(namestr, "%d", mediattl);
      Tcl_SetVar(interp, "mediattl", namestr, TCL_GLOBAL_ONLY);
      sprintf(namestr, "%d", medialayers);
      Tcl_SetVar(interp, "medialayers", namestr, TCL_GLOBAL_ONLY);
      Tcl_SetVar(interp, "mediaaddr", tmpstr, TCL_GLOBAL_ONLY);

/* look at the individual media stream keys */

      if ((kctr>0) && (mediakey[i] != NULL) ) {
        warn_tcl_special_chars(mediakey[i]);
        Tcl_SetVar(interp, "mediakey", mediakey[i], TCL_GLOBAL_ONLY);
	free(mediakey[i]);
      } else {
        Tcl_SetVar(interp, "mediakey", "", TCL_GLOBAL_ONLY);
      }

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

/* add the session to the displayed list */

#ifdef WIN32
    Tcl_GlobalEval(interp,".f2.sb configure -command {}");
    code = Tcl_GlobalEval(interp, "add_to_list");
    Tcl_GlobalEval(interp,"after 500 {.f2.sb configure -command {.f2.lb yview}}");
#else
    code = Tcl_GlobalEval(interp, "add_to_list");
#endif

    if (code != TCL_OK) {
	if (debug1==TRUE)
	  fprintf(stderr, "add_to_list failed for session %s:\n%s\n",
			 session, interp->result);
      }
    if (debug1)
	free(data2);
    return timemax;
errorleap:
    if (debug1)
	free(data2);
    return 0;
}

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

int check_net_type(char *in, char *ip, char *addr)
{
  int j1, j2, j3, j4;
  char c;

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
  if (addr != NULL &&
      (sscanf(addr, "%d.%d.%d.%d%c", &j1, &j2, &j3, &j4, &c) != 4 ||
       inet_addr(addr) == -1)) {
    int isok = 0;
    char *p;

    /* It's not a valid numeric address.
     * RFC2327 says that the other possibility is a FQDN, defined as
     *   4*(alpha-numeric|"-"|".")
     * Instead, we just ensure that it has an alpha in it.
     * ("Be generous in what you accept.")
     */
    for (p = addr; *p; p++) {
      if (isalpha(*p)) {
	isok = 1;
	break;
      }
    }
    if (!isok) {
      if (debug1)
	fprintf(stderr, "sdr: illegal IP address %s\n", addr);
      return -1;
    }
  }
  return 0;
}

/*------------------------------------------------------------------------*/
/* timed_send_advert                                                      */
/*                                                                        */
/*------------------------------------------------------------------------*/
int timed_send_advert(ClientData cd)
{
  struct advert_data *addata;
  struct timeval tv;
  struct priv_header *sapenc_p;
  unsigned int interval;
  unsigned int jitter;
  u_int auth_len=0;
  u_int hdr_len=0;

  writelog(printf(" -- entered timed_send_advert --\n");)

/* set up the basic info */

  gettimeofday(&tv, NULL);
  addata=(struct advert_data *)cd;

/* authentication information */

  if (addata->authinfo != NULL ){

    auth_len=addata->authinfo->sig_len+AUTH_HEADER_LEN+addata->authinfo->pad_len;
  } else {
    auth_len = 0;
  }

/* encryption information */

  if  (addata->sapenc_p !=NULL) {
    sapenc_p = addata->sapenc_p;
    if ( addata->sapenc_p->enc_type != DES) {
      hdr_len = (sapenc_p->encd_len+2+sapenc_p->pad_len) ;
      addata->sapenc_p->hdr_len = hdr_len / 4 ;
    }
  } else {
    sapenc_p =NULL;
    hdr_len = 0;
  }
 
/* Now call send_advert                                     */
/* If the session has timed out, don't re-announce it       */

  writelog(printf("timed_send_advert calling send_advert\n");)

  if (((unsigned long)tv.tv_sec<=addata->end_time)||(addata->end_time==0)) {
    send_advert(addata->data, addata->tx_sock, addata->ttl,
		addata->encrypt, addata->length,
		auth_len, addata->authinfo, 
                hdr_len, sapenc_p, &(addata->sap_hdr));
    interval = addata->interval;
    jitter = (unsigned)lblrandom() % interval;
    addata->timer_token=Tcl_CreateTimerHandler(interval + jitter,
                (Tk_TimerProc*)timed_send_advert,
                (ClientData)addata);
  }

  return TCL_OK;
}
/*------------------------------------------------------------------------*/
/* send the advert out                                                    */
/*                                                                        */
/*------------------------------------------------------------------------*/
int send_advert(char *adstr, int tx_sock, unsigned char ttl,
                int encrypt, u_int len, u_int auth_len,
                struct auth_info *authinfo , u_int hdr_len,
                struct priv_header *sapenc_p, 
		struct sap_header **sap_hdr)
{
  struct auth_header *auth_hdr=NULL;
  struct sap_header  *bp=NULL;
  struct priv_header *enc_p=NULL;

  char *buf=NULL;

  int datalength=0;
  int packetlength=0;
  int code;

#ifdef WIN32
  int wttl;
#endif

#ifdef LOCAL_ONLY
  ttl=1;
#endif

  writelog(printf(" -- entered send_advert --\n");)

  datalength = len;

/* calculate packetlength - asymm,symm (+4(2[generic enc_hdr]+2[pad]),clear  */
/* len = data; auth_len = auth_hdr_len; hdr_len = priv_hdr len               */

  writelog(printf("send_advert: len=%d auth_len=%d hdr_len=%d\n",len,auth_len,hdr_len);)

  if (hdr_len != 0) {

/* think hdr_len is everything from start of priv_hdr so no need for +len ? */
/*  packetlength = sizeof(struct sap_header)+auth_len+TIMEOUT+hdr_len+len;  */
    packetlength = sizeof(struct sap_header)+auth_len+TIMEOUT+hdr_len;

  } else if (encrypt !=0 ) {
    packetlength = sizeof(struct sap_header)+auth_len+TIMEOUT+4+len;
  } else {
    packetlength = sizeof(struct sap_header)+auth_len+len;
  }

/* malloc the space */

  buf = (char *)malloc(packetlength);

/* call build_packet to fill out sap_hdr, auth_hdr and priv_hdr             */

  len += build_packet(buf,adstr,len,encrypt,auth_len,hdr_len,authinfo,sapenc_p);

/* store the SAP header we used so we can write it to the cache later       */
/* not sure why we want to do this                                          */

  if (*sap_hdr==NULL) {
    *sap_hdr=(struct sap_header *)malloc(sizeof(struct sap_header));
  }
  memcpy(*sap_hdr, buf, sizeof(struct sap_header));

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

/* if debugging look at what we are going to send just before we send it */

      writelog(printf(" *** SENDING ***\n");)

      bp= (struct sap_header *)((char *)buf);
      writelog(printf(" sap_hdr: version=%d type=%d enc=%d compress=%d authlen=%d msgid=%d src=%lu\n",bp->version, bp->type, bp->enc, bp->compress, bp->authlen, bp->msgid, bp->src);)

      if (auth_len != 0) {
        auth_hdr= (struct auth_header *)((char *)buf+sizeof(struct sap_header));
        writelog(printf("auth_hdr: version = %d, padding = %d, auth_type = %d, siglen = %d\n",auth_hdr->version, auth_hdr->padding, auth_hdr->auth_type,auth_hdr->siglen);)
      }

      if (hdr_len != 0) {
        enc_p = (struct priv_header *)((char *)buf+sizeof(struct sap_header)+auth_len+TIMEOUT);
        writelog(printf("priv_hdr: version=%d padding=%d enc_type=%d hdr_len=%d \n",enc_p->version,enc_p->padding,enc_p->enc_type,enc_p->hdr_len) ;)
      }

      writelog(printf(" ***************\n");)

/* send the data out - len should be the full length after build_packet */

  code = send(tx_sock, buf, len, 0);

/* if debugging check the announcement is sent */

  if (code == -1) {
    writelog(printf(" \nFailed to send announcement: errno = %d\n\n",errno);)
  }

/* free up some space */

  free(buf);

  return 0;
}

/*------------------------------------------------------------------------*/
/*                                                                        */
/*  queue the ad for sending - all the info should already be in the      */
/* advert_data structure if auth or encryption is being used              */
/*                                                                        */
/*------------------------------------------------------------------------*/
int queue_ad_for_sending(char *aid, char *adstr, int interval,
        long end_time, char *txaddress, int txport,
        unsigned char ttl, char *keyname, 
        char *auth_type, char *auth_status,
        char *enc_type,  char *enc_status,
        struct advert_data *addata )
{
  struct priv_header *sapenc_p;
  static int no_of_ads=0;
  int i, auth_len=0;
  int hdr_len=0;
 
  writelog(printf("entered queue_ad_for_sending\n");)

/* If the announcement is to contain authentication information then the   */
/* advert_data entry will already have been created (in 'createsession')   */
/* The privacy header won't have been set up for the purely symmetric case */
 
  if (addata == NULL) {
    addata = (struct advert_data *)malloc(sizeof(struct advert_data));
    addata->sap_hdr  = NULL;
    addata->authinfo = NULL;
    addata->sapenc_p = NULL;
  } 
  sapenc_p = addata->sapenc_p;

/* start filling in the advert_data structure */

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

  addata->aid  = (char *)malloc(strlen(aid)+1);
  strcpy(addata->aid, aid);

  addata->interval    = interval;
  addata->end_time    = end_time;
  addata->next_ad     = NULL;
  addata->ttl         = ttl;
  addata->timer_token = Tcl_CreateTimerHandler(interval, 
                          (Tk_TimerProc*)timed_send_advert,(ClientData)addata);

/* Handle authentication                                              */
/* NB: AUTH_HEADER_LEN=2 not 1 as Goli put sig_length in as well      */
/* this will be changed at some time as it doesn't agre with the spec */
/* also the certificate types are obsolete and will be removed        */

  if ((strcmp(auth_type,"pgp")==0) && (strcmp(auth_status,"failed")!=0)) {

    auth_len = addata->authinfo->sig_len + AUTH_HEADER_LEN + 
                   addata->authinfo->pad_len;

  } else if ((strcmp(auth_type,"x509")==0)&&(strcmp(auth_status,"failed")!=0)) {

    auth_len = addata->authinfo->sig_len + AUTH_HEADER_LEN + 
                   addata->authinfo->pad_len;

  } else {

/* Either have no authentication type or the authentication failed */

    auth_len = 0;
    if (addata->authinfo != NULL) {
      if (addata->authinfo->signature != NULL) {
        free(addata->authinfo->signature);
      }
      if (addata->authinfo != NULL) {
        free(addata->authinfo);
      }
    }
    addata->authinfo = NULL;
  }

/* Handle encryption */
/* doesn't ui_createsession call store_data_to_announce via gen_new_data ? */
/* asymm; the generic privacy header IS two bytes                          */

  if ((strcmp(enc_type,"pgp")==0)&&(strcmp(enc_status,"failed")!=0)) {

    hdr_len        = sapenc_p->encd_len+ENC_HEADER_LEN+sapenc_p->pad_len;
    addata->length = sapenc_p->encd_len+sapenc_p->pad_len;
    addata->data   = malloc( addata->length);
    memcpy(addata->data, sapenc_p->enc_data, addata->length);

  } else if ((strcmp(enc_type,"x509")==0)&&(strcmp(enc_status,"failed")!=0) ) {

    hdr_len        = sapenc_p->encd_len+ENC_HEADER_LEN+sapenc_p->pad_len;
    addata->length = sapenc_p->encd_len+sapenc_p->pad_len;
    addata->data   = malloc( addata->length);
    memcpy(addata->data, sapenc_p->enc_data, addata->length);

  } else {

/* store_data_to_announce sets everything up for symm and clear etc */

    hdr_len = 0;
    if (sapenc_p)
      free(sapenc_p);
    addata->sapenc_p = sapenc_p = NULL;
    if (store_data_to_announce(addata, adstr, keyname)==-1) {
      free(addata->aid);
      free(addata);
      return -1;
    }

  }

/* set up the linked list entry */

  if (first_ad==NULL) {
      first_ad=addata;
      last_ad=addata;
      addata->prev_ad=NULL;
      no_of_ads=1;
  } else {
      last_ad->next_ad=addata;
      addata->prev_ad=last_ad;
      last_ad=addata;
      no_of_ads++;
  }

/* send the advert */

  writelog(printf("queue_ad_for_sending calling send_advert\n");)

  send_advert(addata->data, addata->tx_sock, ttl, addata->encrypt,
	      addata->length, auth_len, addata->authinfo,hdr_len, 
	      sapenc_p, &(addata->sap_hdr));

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

/* --------------------------------------------------------------------- */
/* get_advert_info - get the info from the linked list                   */
/* --------------------------------------------------------------------- */
struct advert_data *get_advert_info(char *advertid)
{
  struct advert_data *addata=first_ad;

  writelog(printf(" entered get_advert_info (advertid = %s)\n",advertid);)

  if (first_ad != NULL) {
    do {
      if (strcmp(addata->aid, advertid)==0) {
	return (addata);
      }
      addata=addata->next_ad;
    } while (addata!=last_ad->next_ad);
  }

  return NULL;
}

#ifdef WIN32
/* Quick fix as the routine below won't compile on windows even though it is */
/* never called - code to call it is in plugins.tcl                          */
int run_program(char *args) {
  writelog(printf(" -- entered run_program on Windows --\n");)
  writelog(printf("  **** You should not be here ! ****\n");)
  return 0;
}
#else
int run_program(char *args) {
  pid_t pid;
  int i;
  char *ptr1, *ptr2, *nargv[40];
  pid = fork();
  if (pid>0)
    return pid;
  if (pid<0) {
    perror("fork");
    return -1;
  }
  /*if we're here, we're the child*/
  /*we need to clear up all the files the parent had open - if we don't 
    do this we might have problems restarting sdr unless all the apps
    have been closed.  That's the problem with TCL exec that prevents
    us using it.*/
  close(sip_udp_rx_sock); 
  close(sip_tcp_rx_sock); 
  for(i=0;i<no_of_rx_socks;i++)
    close(rxsock[i]);
  for(i=0;i<no_of_tx_socks;i++)
    close(txsock[i]);
  /*OK, now we're ready to exec the child process*/
  i=0;
  ptr1=args;
  while(ptr1!=NULL) {
    while(*ptr1==' ')
      *ptr1++='\0';
    if (*ptr1=='\0') break;
    nargv[i++]=ptr1;
    ptr2=strchr(ptr1, ' ');
    /*cope with quoted strings*/
    if (*ptr1=='"') {
      ptr2=strchr(ptr1+1,'"');
      if (ptr2!=NULL) ptr2++;
    }
    ptr1=ptr2;
    if (i==38) {
      /*XXX*/
      fprintf(stderr, "too many args to command to be run!\n");
      break;
    }
  }
  nargv[i]=NULL;
#ifdef DEBUG
  for(k=0;k<i;k++)
    printf(">%s<\n",nargv[k]);
#endif
  execvp(nargv[0], nargv);

  /*what, still here?*/
  /*something went wrong with the exec...*/
  fprintf(stderr, "Failed to execute ");
  for(i=0;nargv[i]!=NULL;i++)
    fprintf(stderr, "%s ", nargv[i]);
  fprintf(stderr, "\n");
  perror(nargv[0]);
  exit(0);
}
#endif

