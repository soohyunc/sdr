/*
 * Copyright (c) 1996 University College London
 *               1997 Unicersity of Southern California
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

#include "sdr.h"
#include "sip.h"

#ifndef WIN32
#include <arpa/nameser.h>
#include <resolv.h>
#include <sys/uio.h>
#endif

#include "dns.h"
#include "prototypes.h"
#include <tcl.h>

//#define DEBUG

#define MAXINVITES 20

#ifdef WIN32
#define MAX_FD 512
#else
#define MAX_FD 64
#endif

int sip_parse_recvd_data(char *buf, int length, int sipfd, char *srcaddr);
void debug_tcp_conns();

extern int sip_udp_rx_sock;
extern int sip_tcp_rx_sock;
extern int sip_udp_tx_sock;
extern connection sip_tcp_conns[];
extern char username[];
extern char hostname[];
extern char sipalias[];
extern unsigned long hostaddr;
extern Tcl_Interp *interp;

char *sipdata=NULL;
int sipblocks=0;
int sipdatalen=0;

#include "mdebug.h"

void debug_tcp_conns() { 
#ifdef NOTDEF
    int i;
    for(i=0;i<MAX_CONNECTIONS;i++) {
	if (sip_tcp_conns[i].used==1) {
	    fprintf (stderr,"%d: fd: %d addr:%s host:%s port:%d\n",
		   i,
		   sip_tcp_conns[i].fd,
		   sip_tcp_conns[i].addr,
		   sip_tcp_conns[i].host,
		   sip_tcp_conns[i].port);
	}
    }
#endif
}

int sip_send_udp(char *dst, int ttl, int port, char *msg)
{
    struct sockaddr_in sin;
    
    MDEBUG(SIP, ("sip_send_udp to %s/%d/%d\n%s", dst, port, ttl, msg));

    sin.sin_addr.s_addr=inet_addr(dst);
    if (sin.sin_addr.s_addr==-1)
	sin.sin_addr=look_up_address(dst);
    if (sin.sin_addr.s_addr==0)	{
	fprintf(stderr, "address lookup failed\n");
	return -1;
    }

    MDEBUG(SIP, ("sip_send_udp to %s (%s)\n", inet_ntoa(sin.sin_addr), dst));
    
    sin.sin_port=htons(port);
    sin.sin_family=AF_INET;
    if (ttl>0) {
	return(sip_send(msg, strlen(msg), &sin, ttl));
    } else {
	return(sip_send(msg, strlen(msg), &sin, 0));
    }
}

int sip_send(char *msg, int len, struct sockaddr_in *dst, unsigned char ttl)
{
    /* Note: I'd love to use sendto rather than this socket cache, but
     * I need to keep the PCB around so I can detect a port unreachable
     * coming back when there's no server.  Of course this doesn't work
     * on all platforms...
     */
    static int no_of_socks=0;
    static long slist[MAXINVITES];
    static int sockets[MAXINVITES];
    int code=0;
    int freesock=-1, usedsock=-1, sock, i, one=1;
#ifdef WIN32
    int wttl;
    struct sockaddr_in name;
#endif
    if (no_of_socks==0)	{
	for(i=0;i<MAXINVITES;i++)
	    sockets[i]=-1;
	freesock=0;
    } else {
	for(i=0;i<MAXINVITES;i++) {
	    if((freesock==-1)&&(sockets[i]==-1))
		freesock=i;
	    if((sockets[i]!=-1)&&(slist[i]==dst->sin_addr.s_addr)) {
		usedsock=i;
		break;
	    }
	}
    }

    if(usedsock!=-1) {
	sock=usedsock;
    } else {
	MDEBUG(SIP, ("new socket\n"));
	sock=freesock;
	sockets[sock]=socket( AF_INET, SOCK_DGRAM, 0 );
	no_of_socks++;
	slist[sock]=dst->sin_addr.s_addr;
	if (sockets[sock]==-1) {
	    perror("couldn't get SIP socket");
	    return -1;
	}
	
	
#ifndef WIN32
	fcntl(sockets[sock], F_SETFD, 1);
#else

	setsockopt(sockets[sock], SOL_SOCKET, SO_REUSEADDR,
		   (char *)&one, sizeof(one));
	
	memset((char*)&name, 0, sizeof(name));
	name.sin_family = AF_INET;
	name.sin_port = 0;
	name.sin_addr.s_addr = INADDR_ANY;
	if (bind(sockets[sock], (struct sockaddr *)&name, sizeof(name))) {
	    perror("bind");
	    exit(1);
	}
#endif
	
	if (connect(sockets[sock], 
		    (struct sockaddr *) dst, sizeof(struct sockaddr_in))<0) {
	    perror("connect");
	    fprintf (stderr,"Dest Address problem\n");
#ifdef DEBUG
	    fprintf(stderr, "Dest Address problem\n");
#endif
	    return(-1);
	}
	if (setsockopt(sockets[sock], SOL_SOCKET, SO_REUSEADDR,
		       (char *)&one, sizeof(one)) < 0) {
	    perror("SO_REUSEADDR");
	}
  }

    MDEBUG(SIP, ("sip send\n"));

    if (ttl > 0) {
#ifdef WIN32
	wttl = ttl;
	if (setsockopt(sockets[sock], IPPROTO_IP, IP_MULTICAST_TTL, 
		       (char *)&wttl, sizeof(wttl))<0)
#else
	    if (setsockopt(sockets[sock], IPPROTO_IP, IP_MULTICAST_TTL, 
			   (char *)&ttl, sizeof(ttl))<0)
#endif
		{
		    fprintf(stderr, "ttl: %d\n", ttl);
		    perror("setsockopt ttl");
#ifdef NOTDEF
		    return(-1);
#endif
		}
    }
    code=send(sockets[sock], msg, len, 0);
    if (code==-1) {
#ifdef DEBUG
	fprintf(stderr, "send: %d: ", errno);
	perror("");
#endif
	return(errno);
    }
    return(0);
}

struct in_addr look_up_address(char *hostname)
{
    static struct in_addr addr;
    struct hostent *hostaddr;
    static char str[256];
    int i;
    int dotted_decimal=1;
    for(i=0;i<strlen(hostname);i++) {
	if ((!isdigit(hostname[i]))&&(hostname[i]!='.')) {
	    dotted_decimal=0;
	    break;
	}
    }
    if (dotted_decimal==0) {
	hostaddr=gethostbyname(hostname);
	if(hostaddr!=NULL)  {
	    memcpy((char *)&(addr.s_addr), hostaddr->h_addr_list[0], 4);
	} else 
#ifndef WIN32

	{
	  char buf[200];
	  char ans[1000];
	  int ctr;
	  char *tstr, *resstr;
	  struct dnshdr *dnsa;
	  int len;
	  addr.s_addr=0;
	  len=res_mkquery(QUERY, hostname, C_IN, T_MX, NULL, NULL, NULL, buf, 200);
	  if (len==-1) perror("res_mkquery");
	  len=res_send(buf, len, ans, 2000);
	  if (len==-1) perror("res_send");
	  ans[0]=htonl(ans[0]);
	  ans[1]=htonl(ans[1]);
	  ans[2]=htonl(ans[2]);
	  dnsa=(struct dnshdr*)&ans[0];
/*	  printf("id:%d, opcode:%d, rcode:%d, qdcount:%d, ancount:%d, nscount:%d, arcount:%d\n", dnsa->id, dnsa->opcode, dnsa->rcode, dnsa->qdcount, dnsa->ancount, dnsa->nscount, dnsa->arcount);*/


	    if(dnsa->rcode!=0) {
		addr.s_addr=(unsigned long)0;
		return(addr);
	    }
	    
	    /*query*/
	    ctr=ans[sizeof(struct dnshdr)];
	    tstr=(char *)(&ans[sizeof(struct dnshdr)]);
	    for(i=0;i<dnsa->qdcount;i++) {
		ctr=tstr[0];
		tstr++;
		while(ctr!=0){
		    int tmp;
		    memcpy(str, tstr, ctr);
		    str[ctr]='\0';
		    tmp=ctr;
		    ctr=tstr[ctr];
		    tstr+=(tmp+1);
		}
		tstr+=4;
	    }
	    
	    for(i=0;i<dnsa->ancount;i++) {
		/*domain part of answer*/
		ctr=tstr[0];
		tstr++;
		if ((ctr&192)!=192) {
		    while(ctr!=0) {
			int tmp;
			memcpy(str, tstr, ctr);
			str[ctr]='\0';
			tmp=ctr;
			ctr=tstr[ctr];
			tstr+=(tmp+1);
		    }
		} else {
		    /*it's compressed*/
		    tstr+=1;
		}
		tstr+=12;
		ctr=tstr[0];
		tstr++;
		resstr=str;
		while(ctr!=0) {
		    int tmp;
		    if((ctr&192)!=192) {
			memcpy(resstr, tstr, ctr);
			resstr[ctr]='.';
			resstr+=ctr+1;
			/* printf("query:%s\n", str);*/
			tmp=ctr;
			ctr=tstr[ctr];
			tstr+=(tmp+1);
			if(ctr==0) *(resstr-1)='\0';
		    } else {
			/*it's compressed*/
		        if(*tstr==0) tstr+=2;
			resstr += dn_expand(ans, ans+len, tstr-1, resstr, 
					    200-strlen(resstr));
			tstr+=1;
			ctr=0;
		    }
		}
		/*	      printf("MX:%s\n", str);*/
	    }
	    return(look_up_address(str));
	    }
#else
	{
	    addr.s_addr=(unsigned long)0;
	}
    
#endif
    
    } else {
	addr.s_addr=inet_addr(hostname);
    }
    return(addr);
}

char *sip_get_dstname(char *msg)
{
    char *line, *cr, *url;
    static char *res=NULL;
    char *username, *hostname;

    line=strstr(msg, "\nTo:");
    if (line==NULL) {
	line=strstr(msg, "\nt:");
	if (line==NULL) return NULL;
	line+=3;
    } else {
	line+=4;
    }
    url=strdup(line);
    cr=strchr(url, '\r');
    if (cr==NULL) cr=strchr(url, '\n');
    if (cr==NULL) return NULL;
    *cr='\0';
    username=strdup(url);
    hostname=strdup(url);
    
    parse_sip_url(url, username, NULL, hostname, NULL, NULL, NULL, NULL,
		  NULL, NULL);
    
    /*free the memory from last time we were called*/
    if (res!=NULL) free(res);
    
    res=malloc(strlen(username)+strlen(hostname)+2);
    sprintf(res, "%s@%s", username, hostname);
    free(url);
    free(username);
    free(hostname);
    return res;
}

int sip_get_method(char *msg)
{
    char method[20];

    strncpy(method, msg, 19);
    if (strchr(method, ' ')!=0)
	*strchr(method, ' ')='\0';
    if (strcmp(method, "INVITE")==0)
	return INVITE;
    if (strcmp(method, "OPTIONS")==0)
	return OPTIONS;
    if (strcmp(method, "REGISTER")==0)
	return REGISTER;
    if (strcmp(method, "ACK")==0)
	return ACK;
    if (strcmp(method, "BYE")==0)
	return BYE;
    if (strcmp(method, "CANCEL")==0)
	return CANCEL;
    return METHOD_UNKNOWN;
}

int is_a_sip_request(char *msg)
{
    return((strncmp(msg, "INVITE ", 7)==0) || 
	   (strncmp(msg, "ACK ", 4)==0) || 
	   (strncmp(msg, "BYE ", 4)==0) || 
	   (strncmp(msg, "CANCEL ", 7)==0) || 	 
	   (strncmp(msg, "REGISTER ", 9)==0) || 	 
	   (strncmp(msg, "OPTIONS ", 8)==0));
}

int is_a_sip_reply(char *msg)
{
    return(strncmp(msg, "SIP/2.0 ", 8)==0);
}

int parse_sip_reply(int fd, char *msg, char *addr)
{
    char rtype;

    rtype=msg[8];

    MDEBUG(SIP, ("rtype: %c\n", rtype));

    if(rtype=='1')
	parse_sip_progress(fd, msg, addr);
    else if(rtype=='2')
	parse_sip_success(fd, msg, addr);
    else if(rtype=='3')
	parse_sip_redirect(fd, msg, addr);
    else if(rtype=='4')
	parse_sip_fail(fd, msg, addr);
    else if(rtype=='5')
	parse_sip_fail(fd, msg, addr);
    else if(rtype=='6')
	parse_sip_fail(fd, msg, addr);
    else
	fprintf(stderr, "Illegal SIP reply type\n");
    return 0;
}

int sip_udp_listen(char *address, int port) 
{    
    int rxsock;
    struct sockaddr_in name;
    unsigned int group;
    int one=1;
    
    group = inet_addr(address);
    if((rxsock=socket( AF_INET, SOCK_DGRAM, 0 )) < 0) {
        perror("couldn't get SIP receive socket");
        return(-1);
    }
    
    if (setsockopt(rxsock, SOL_SOCKET, SO_REUSEADDR,
		   (char *)&one, sizeof(one)) < 0) {
	perror("SO_REUSEADDR");
    }

#ifdef SO_REUSEPORT
    if (setsockopt(rxsock, SOL_SOCKET, SO_REUSEPORT,
		   (char *)&one, sizeof(one)) < 0) {
	perror("SO_REUSEPORT");
    }
#endif

#ifndef WIN32
    fcntl(rxsock, F_SETFD, 1);
#endif

    name.sin_family = AF_INET;
    name.sin_addr.s_addr = INADDR_ANY;
    name.sin_port = htons(port);
    if (bind(rxsock, (struct sockaddr *)&name, sizeof(name))) {
        perror("bind");
	fprintf(stderr, "Address: %x, Port: %d\n",
		group, port);
        return(-1);
    }
#ifndef WIN32
    if (IN_CLASSD(ntohl(group)))
#endif
    {
	struct ip_mreq imr;
	
	imr.imr_multiaddr.s_addr = group;
	imr.imr_interface.s_addr = INADDR_ANY;
	
	if (setsockopt(rxsock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
		       (char *)&imr, sizeof(struct ip_mreq)) < 0 ) {
	    perror("setsockopt - IP_ADD_MEMBERSHIP");
	    return(-1);
	}
    }
    return(rxsock);
}

int sip_tcp_listen(int port)
{
    int fd, one=1;
    struct sockaddr_in name;
    
    debug_tcp_conns();
    fd=socket(PF_INET, SOCK_STREAM, 0);
    if (fd<0) {
	fprintf(stderr, "failed to create socket\n");
	return -1;
    }
    
    name.sin_family = AF_INET;
    name.sin_addr.s_addr = INADDR_ANY;
    name.sin_port = htons(port);
    if (bind(fd, (struct sockaddr *)&name, sizeof(name))<0) {
	perror("bind");
	fprintf(stderr, "Port: %d\n", port);
	return(-1);
    }
    
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR,
		   (char *)&one, sizeof(one)) < 0) {
	perror("SO_REUSEADDR");
    }

#ifdef SO_REUSEPORT
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEPORT,
		   (char *)&one, sizeof(one)) < 0) {
	perror("SO_REUSEPORT");
    }
#endif

    if (listen(fd,10)<0) {
	fprintf(stderr, "listen failed!\n");
	return -1;
    }

    MDEBUG(SIP, ("sip_tcp_listen: listening on port %d\n", port));

    return fd;
}


int sip_tcp_accept(connection conns[])
{
    struct sockaddr_in addr;
    int cnum=-1, addrlen=sizeof(struct sockaddr_in);

    debug_tcp_conns();
    for(cnum=0;cnum<MAX_CONNECTIONS;cnum++) {
	if (conns[cnum].used==0)
	    break;
    }
    if (cnum==-1) return -1;
    
    /* Allocate a 6K buffer - shouldn't normally need anywhere near
     * this much, but if we need more, we can will realloc later.
     */
    conns[cnum].used=1;
    conns[cnum].buf=malloc(6000);
    conns[cnum].bufsize=6000;
    conns[cnum].fd=accept(sip_tcp_rx_sock, (struct sockaddr *)&addr, &addrlen);
    conns[cnum].addr=strdup(inet_ntoa(addr.sin_addr));
    fprintf (stderr,"Accepted connection from %s\n", conns[cnum].addr);
    debug_tcp_conns();
    return 0;
}

void sip_tcp_free(connection *conn)
{
    debug_tcp_conns();
    conn->used=0;
    conn->len=0;
    free(conn->buf);
    conn->bufsize=0;
    close(conn->fd);
    conn->fd=0;
    free(conn->addr);
    conn->addr=0;
    free(conn->host);
    conn->host=0;
    conn->port=0;
    free(conn->callid);
    conn->callid=0;
    debug_tcp_conns();
}

/*
 * If there is a request ready in the buffer, this returns the total number
 * of bytes in the request.
 * If there is no request ready, it returns -1;
 */
int sip_request_ready(char *buf, int len)
{
    char *clenstr, *payload;
    int clen;

    clenstr=malloc(80);
    clenstr[0]='\0';
    extract_field(buf, clenstr, 80, "content-length");
    if (strlen(clenstr)==0)
	return -1;
    clen=atoi(clenstr);
    payload=strstr(buf, "\r\n\r\n");
    if (payload==NULL) {
	fprintf (stderr,"no CRLFCRLF in buf:>>>%s<<<\n", buf);
	return 0;
    }
    fprintf (stderr,"len:%d clen:%d payload-buf:%d\n", len, clen, (payload-buf));
    if (len >= clen+4+(payload-buf))
	return (clen+4+(payload-buf));
    else 
	return -1;
}

int extract_field(char *buf, char *field_ret, int retlen, char *field)
{
    char *ptr=buf, ufield[20];
    int flen;

    strcpy(ufield, field);
    strcat(ufield, ":");
    flen=strlen(ufield);
#ifdef NOTDEF
    fprintf (stderr,"extract_field: %s\n", field);
#endif
    while (1) {
	if (strncasecmp(ptr, ufield, flen)==0) {
	    ptr+=flen;
	    while(*ptr==' ') ptr++;
	    while((*ptr!='\r')&&(retlen>1)) {
#ifdef NOTDEF
		fprintf (stderr,"%c", *ptr);
#endif
		*field_ret++=*ptr++;
		retlen--;
	    }
	    *field_ret='\0';
#ifdef NOTDEF
	    fprintf (stderr,"<-returning\n");
#endif
	    return 0;
	}
	ptr=strchr(ptr,'\n');
	if (ptr!=NULL) {
	    ptr++;
	} else {
	    break;
	}
    }
    return -1;
}

int extract_parts(char *buf, char *method, char *url, char *via, char *rest)
{
    int i=0,j=0;

    /* Copy the method into "method:*/
    while(buf[i]!=' ')
	method[j++]=buf[i++];
    
    method[j]='\0';
    
    /*remove any whitespace*/
    while(buf[i]==' ')
	i++;
    
    /*copy the url into "url"*/
    j=0;
    while(buf[i]!=' ')
	url[j++]=buf[i++];
    url[j]='\0';
    
    /*skip to beginning of next line*/
    while(buf[i]!='\n')
	i++;

    i++;
    
    /*copy all the via fields into "via"*/
    j=0;
    while (strncmp(&buf[i], "Via:", 4)==0) {
	while(buf[i]!='\n') {
	    via[j++]=buf[i++];
	}
	via[j++]=buf[i++];
    }
    via[j]='\0';
    
    /*copy the rest into "rest"*/
    strncpy(rest, &buf[i], MAXADSIZE-1);
    return 0;
}

int is_a_sip_url(char *url) {
    if (strncmp(url, "sip:", 4)==0) 
	return 1;
    else
	return 0;
}

/*
 * parse_sip_url takes a SIP URL and splits it up into the many pieces 
 * that might exist in it.  You can pass a NULL pointer for any parameter
 * except url if you aren't interested in that particular part of the URL.
 * Int parameters return zero if the relevant part doesn't exist.
 * String parameters return empty strings if the relevant part doesn't exist.
 * The others parameter collects any url-parameters that don't have separate
 * parameters of their own as a single semi-colon separated string.
 */

int parse_sip_url(char *url, char* user, char *passwd, char *host,
		  int *port, int *transport, int *ttl, char *maddr, 
		  char *tag, char *others)
{
    char *buf, *ptr1, *ptr2, *ptr3;
    
    buf=strdup(url);
    
    /* Have to extract the URL from the common name first. */
    if (strchr(buf, '<')==NULL) {
	ptr1=buf;
    } else {
	ptr1=strchr(buf, '<')+1;
	if (strchr(ptr1, '>')==NULL) {
	    fprintf(stderr, "No unmatched open brace in URL: %s\n", url);
	    return -1;
	} else {
	    *strchr(ptr1, '>')='\0';
	}
    }
    
    if (is_a_sip_url(ptr1)==0) {
	if ((strncmp(buf, "http:", 5)==0)||
	    (strncmp(buf, "ftp:", 4)==0)||
	    (strncmp(buf, "mailto:", 7)==0)||
	    (strncmp(buf, "gopher:", 7)==0)||
	    (strncmp(buf, "news:", 5)==0)) {
	    /*it's really not a SIP URL*/
	    fprintf(stderr, "Not a SIP URL: %s\n", ptr1);
	    return -1;
	}
	/* It didn't start "sip:" but might still be OK - take the chance.*/
    } else {
	ptr1=ptr1+4;
    }
    
    ptr2=strchr(ptr1, '@');
    if (ptr2==NULL) {
	fprintf(stderr, "URL %s has no username\n", url);
	return -1;
    }
    
    ptr3=strchr(ptr2, ':');
    if ((ptr3==NULL)||(ptr2<ptr3)) {
	/*there's no password*/
	*ptr2='\0';
	if (user!=NULL)
	    strcpy(user, ptr1);
	if (passwd!=NULL)
	    passwd[0]='\0';
	ptr1=ptr2+1;
    } else {
	/*there's a password field*/
	*ptr3='\0';
	if (user!=NULL)
	    strcpy(user, ptr1);
	ptr1=ptr3+1;
	*ptr2='\0';
	if (passwd!=NULL)
	    strcpy(passwd, ptr1);
	ptr1=ptr2+1;
    }
    ptr2=strchr(ptr1, ':');
    if (ptr2!=NULL) {
	/*there is a port*/
	*ptr2='\0';
	if (host!=NULL)
	    strcpy(host,ptr1);
	ptr1=ptr2+1;
	ptr2=strchr(ptr1, ';');
	if (ptr2!=NULL) {
	    /*there are also parameters*/
	    *ptr2='\0';
	    if (port!=NULL)
		*port=atoi(ptr1);
	    ptr1=ptr2+1;
	} else {
	    /*there are no parameters*/
	    if (port!=NULL)
		*port=atoi(ptr1);
	    return 0;
	}
    } else {
	/*there's no port*/
	ptr2=strchr(ptr1, ';');
	if (ptr2!=NULL) {
	    /*there are parameters*/
	    *ptr2='\0';
	    if (host!=NULL)
		strcpy(host,ptr1);
	    ptr1=ptr2+1;
	} else {
	    /*there are no parameters*/
	    if (host!=NULL)
		strcpy(host,ptr1);
	    return 0;
	}
    }
    /*now deal with the parameters*/
    if (others!=NULL)
	others[0]='\0';
    if (ttl!=NULL)
	*ttl=0;
    if (maddr!=NULL)
	maddr[0]='\0';
    if (tag!=NULL)
	tag[0]='\0';
    if (transport!=NULL)
	*transport=SIP_NO_TRANSPORT;

    while (ptr1!=NULL) {
	ptr2=strchr(ptr1, ';');
	if (ptr2!=NULL) *ptr2='\0';
	if ((strncmp(ptr1, "ttl=", 4)==0)&&(ttl!=NULL)) {
	    *ttl=atoi(ptr1+4);
	} else if ((strcasecmp(ptr1, "transport=udp")==0)&&(transport!=NULL)) {
	    *transport=SIP_UDP_TRANSPORT;
	} else if ((strcasecmp(ptr1, "transport=tcp")==0)&&(transport!=NULL)) {
	    *transport=SIP_TCP_TRANSPORT;
	} else if ((strncmp(ptr1, "maddr=", 5)==0)&&(maddr!=NULL)) {
	    strcpy(maddr, ptr1+6);
	} else if ((strncmp(ptr1, "tag=", 4)==0)&&(tag!=NULL)) {
	    strcpy(tag, ptr1+4);
	} else if (others!=NULL) {
	    strcat(others, ptr1);
	    strcat(others, ";");
	} 
	if (ptr2==NULL)
	    ptr1=NULL;
	else
	    ptr1=ptr2+1;
    }
    return 0;
}

int parse_sip_path (char *path, char *version, int *transport, 
		    char *host, int *port, int *ttl) 
{
    char *ptr1, *ptr2, *buf;
    buf=strdup(path);
    if (strncmp(buf, "Via:", 4)==0) {
	ptr1=buf+4;
    } else if (strncmp(buf, "v:", 2)==0) {
	ptr1=buf+2;
    } else {
	ptr1=buf;
    }
    /*skip whitespace*/
    while(*ptr1==' ') ptr1++;
    if (strncmp(ptr1, "SIP/", 4)==0)
	ptr1+=4;
    ptr2=strchr(ptr1, '/');
    if (ptr2==NULL) {
	/*transport unspecified*/
	ptr2=strchr(ptr1, ' ');
	if (ptr2==NULL) goto invalid_path;
	*ptr2='\0';
	if (version!=NULL)
	    strcpy(version, ptr1);
    } else {
	/*transport specified*/
	*ptr2='\0';
	if (version!=NULL)
	    strcpy(version, ptr1);
	ptr1=ptr2+1;
	ptr2=strchr(ptr1, ' ');
	if (ptr2==NULL) goto invalid_path;
	*ptr2='\0';
	if (transport!=NULL) {
	    if (strcmp(ptr1, "UDP")==0) {
		*transport=SIP_UDP_TRANSPORT;
	    } else if (strcmp(ptr1, "TCP")==0) {
		*transport=SIP_TCP_TRANSPORT;
	    } else {
		*transport=SIP_NO_TRANSPORT;
	    }
	}
    }
    ptr1=ptr2+1;
    while(*ptr1==' ') ptr1++;
    ptr2=strchr(ptr1, ':');
    if (ptr2==NULL) {
	/*no port specified*/
	ptr2=strchr(ptr1, ';');
	if (ptr2==NULL) {
	    /*no parameters either*/
	    if (host!=NULL)
		strcpy(host, ptr1);
	    free(buf);
	    return 0;
	} else {
	    /*there are parameters*/
	    *ptr2='\0';
	    if (host!=NULL)
		strcpy(host, ptr1);
	    ptr1=ptr2+1;
	}
    } else {
	/*port was specified*/
	*ptr2='\0';
	if (host!=NULL)
	    strcpy(host, ptr1);
	ptr1=ptr2+1;
	ptr2=strchr(ptr1, ';');
	if (ptr2==NULL) {
	    /*no parameters*/
	    if (port!=NULL)
		*port=atoi(ptr1);
	    free(buf);
	    return 0;
	} else {
	    *ptr2='\0';
	    if (port!=NULL)
		*port=atoi(ptr1);
	    ptr1=ptr2+1;
	}
    }

    while (1) {
	ptr2=strchr(ptr1, ';');
	if (ptr2!=NULL) *ptr2='\0';
	if (strncmp(ptr1, "ttl=", 4)==0) {
	    if (ttl!=NULL)
		*ttl=atoi(ptr1+4);
	} else if (strncmp(ptr1, "received=", 9)==0) {
	    /*XXX don't handle this yet*/
	} else if (strncmp(ptr1, "branch=", 7)==0) {
	    /*XXX don't handle this yet*/
	}
	if (ptr2==NULL) break;
	ptr1=ptr2+1;
    }
    free(buf);
    return 0;

invalid_path:
    fprintf(stderr, "Invalid path: %s\n", path);
    free(buf);
    return -1;
}

int sip_send_tcp_request(int origfd, char *host, int port, char *user_data, 
			 int wait)
{
    /*
     * fd is set to zero if this is a new request. If it is a request on an 
     * existing call, fd may be non-zero so we can reuse the existing fd.
     */

    struct sockaddr_in sinhim;
    struct hostent *addr;
    unsigned long inaddr;
    int fd,i,len;
    int sipstate;
#define	CONNECTING	1
#define	READING		2
    struct msghdr msg;
    struct iovec iov[10];
    int iovlen;
    
    MDEBUG(SIP, ("sip_send_tcp_request: proto=sip, host=%s, port=%d\nmsg=%s\n",
		 host, port, user_data));
    
    debug_tcp_conns();

    if (origfd!=0) {
	/*there may be an existing TCP connection we can use*/
	for(i=0;i<MAX_CONNECTIONS;i++) {
	    if (sip_tcp_conns[i].used==1) {
		fprintf (stderr,"1: fd: %d, host: %s port: %d\n", origfd, host, port);
		fprintf (stderr,"2: fd: %d, host: %s port: %d\n", sip_tcp_conns[i].fd,
		       sip_tcp_conns[i].host, sip_tcp_conns[i].port);
		if ((sip_tcp_conns[i].fd==origfd)&&
		    (strcmp(sip_tcp_conns[i].host,host)==0)&&
		    (sip_tcp_conns[i].port==port)) {
		    /* There's an existing connection that still seems to be up.*/
		    fprintf (stderr,"sending %d butes\n", strlen(user_data));
		    len=send(origfd, user_data, strlen(user_data), 0);
		    fprintf (stderr,"sent %d bytes:\n>>>%s<<<\n", len, user_data);
		    if (len==strlen(user_data)) {
			fprintf (stderr,"send message on existing connection %d\n", i);
			return origfd;
		    }
		}
	    }
	}
	fprintf (stderr,"existing connection had been closed\n");
    }

    if ( (inaddr = inet_addr(host)) != INADDR_NONE) {
	/* it's dotted-decimal */
	memcpy((char *)&sinhim.sin_addr.s_addr, (char *)&inaddr, 
	       sizeof(inaddr) );
	sinhim.sin_family = AF_INET;
    } else {
	if ((addr=gethostbyname(host)) == NULL) {
	    fprintf(stderr, "Unknown hostname %s\n", host);
	    return -1;
	}
	sinhim.sin_family = addr->h_addrtype;
	sinhim.sin_family = AF_INET;
#ifdef h_addr
	memcpy((char*)&sinhim.sin_addr, addr->h_addr_list[0], addr->h_length);
#else
	memcpy((char*)&sinhim.sin_addr, addr->h_addr, addr->h_length);
#endif
    }
    sinhim.sin_port = htons(port);

    sdr_update_ui();
    
    if((fd=socket(AF_INET, SOCK_STREAM, 0)) < 0) {
	perror("socket");
	return -1;
    }

#ifdef NBCONNECT
    fcntl(fd, F_SETFL, FNDELAY);
#endif

    iovlen = 0;
    iov[iovlen].iov_base = user_data;
    iov[iovlen].iov_len = strlen(iov[iovlen].iov_base);
    iovlen++;
    
    /* workaround for accrights / control renaming */
    memset((char *)&msg, 0, sizeof(msg));
    
    msg.msg_name = (void *)&sinhim;
    msg.msg_namelen = sizeof sinhim;
    msg.msg_iov = iov;
    msg.msg_iovlen = iovlen;
    if (connect(fd, (struct sockaddr *)&sinhim, sizeof(struct sockaddr_in))<0
#ifdef NBCONNECT
	&& errno != EINPROGRESS
#endif
	) {
	perror("sip_send_tcp_request: connect");
	return -1;
    }
    
    MDEBUG(SIP, ("sip_send_tcp_request: connected to host=%s\n", host));

    sipdatalen=0;
    sipstate = CONNECTING;
    if (sipdata==NULL) {
	sipdata=malloc(BLOCKSIZE);
	sipblocks=1;
    }
    
    while (1) {
	fd_set r,w;
	struct timeval tv;
	int i;

	tv.tv_sec=0;
	tv.tv_usec=100000;
	FD_ZERO(&r);
	if (sipstate == READING) FD_SET(fd, &r);
	FD_ZERO(&w);
	if (sipstate == CONNECTING) FD_SET(fd, &w);
	
	if(select(fd+1, &r, &w, NULL, &tv)!=0)  {
	    Tk_DoOneEvent(TK_DONT_WAIT);
	    if (sipstate == CONNECTING) {
#ifdef NBCONNECT
		int err = 0;
		int errlen = sizeof(err);
		
		if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &errlen) < 0) {
#ifdef SOLARIS
		    switch (errno) {
			/*
			 * Solaris 2.4's socket emulation doesn't allow you
			 * to determine the error from a failed non-blocking
			 * connect and just returns EPIPE.  Create a fake
			 * error message for connect.
			 */
			case EPIPE:
			    err = ENOTCONN;
			    break;
			    
			    /*
			     * Solaris 2.5's socket emulation returns the 
			     * connect error as a getsockopt error. If 
			     * getsockopt returns an error that could have 
			     * been returned by connect, use that.
			     */
			case ENETDOWN:
			case ENETUNREACH:
			case ENETRESET:
			case ECONNABORTED:
			case ECONNRESET:
			case ENOBUFS:
			case EISCONN:
			case ENOTCONN:
			case ESHUTDOWN:
			case ETOOMANYREFS:
			case ETIMEDOUT:
			case ECONNREFUSED:
			case EHOSTDOWN:
			case EHOSTUNREACH:
			case EWOULDBLOCK:
			case EALREADY:
			case EINPROGRESS:
			    err = errno;
			    break;
			    
			    /*
			     * Otherwise, it's probably a real error.
			     */
			default:
			    {
				perror("getsockopt");
				return -1;
			    }
		    }
#else
		    perror("getsockopt");
		    return -1;
#endif
		}
		if (err != 0)  {
		    perror("connect");
		    return -1;
		}
		fcntl(fd, F_SETFL, 0);
#endif
		if (send(fd, user_data, strlen(user_data),0)
		    !=strlen(user_data)) {
		    fprintf (stderr,"failed to send to fd %d\n", fd);
		}
		if (wait==0) {
		    /*
		     * don't wait around for a reply - this was called from a
		     * context where we don't expect a reply on this connection
		     * such as when we opened this connection for a response
		     * rather than a request.
		     */
		    close(fd);
		    return -1;
		}
		/*
		 * we do expect a reply.  Don't wait here for it, but
		 * initiate a file handler on this socket, and use the
		 * normal TCP receive code to get the response.
		 */
		for(i=0;i<MAX_CONNECTIONS;i++) {
		    if (sip_tcp_conns[i].used==0) {
			sip_tcp_conns[i].used=1;
			sip_tcp_conns[i].len=0;
			sip_tcp_conns[i].buf=malloc(6000);
			sip_tcp_conns[i].bufsize=6000;
			sip_tcp_conns[i].fd=fd;
			sip_tcp_conns[i].port=port;
			fprintf (stderr,"port is now %d\n", port);
			sip_tcp_conns[i].host=strdup(host);
			sip_tcp_conns[i].addr=
			    strdup(inet_ntoa(sinhim.sin_addr));
			debug_tcp_conns();

			MDEBUG(SIP, ("\n-------------------------------------------\nInitiated new SIP TCP connection %d to %s\n",
				     i, sip_tcp_conns[i].addr));

			linksocket(sip_tcp_conns[i].fd, TK_READABLE,
				   (Tcl_FileProc*)sip_readfrom_tcp);
			break;
		    }
		}
		sipstate = READING;
		return fd;
	    }
	} else {
	}
    }

    close(fd);
    sipdata[sipdatalen]='\0';
    interp->result=sipdata;
    return -1;
}

int sip_send_tcp_reply(int fd, char *callid, char *addr, int port, char *msg)
{
    /*
     * The fd should be the file descriptor that the request came in on.
     * If it's still valid, send the reply back on the same fd.
     * If it's no longer connected, initiate a new TCP connection to
     * return the response.
     */
    int i, nfd;
    fprintf (stderr,"seeking for call-id >>%s<<\n", callid);
    debug_tcp_conns();
    for(i=0;i<MAX_CONNECTIONS; i++) {
	if ((sip_tcp_conns[i].used==1)) {
	    printf (stderr,"Used conn %d has callid >>%s<<\n", 
		   i, sip_tcp_conns[i].callid);
	}
	if ((sip_tcp_conns[i].used==1) && 
	    (strcmp(sip_tcp_conns[i].callid,callid)==0)) {
	    /* This is our fd. */
	    fprintf (stderr,"this is our fd\n");
	    if (sip_send_tcp_reply_to_fd(sip_tcp_conns[i].fd, msg)>=0) {
		return 0;
	    } else {
		/* The write failed! Open a new connection...*/
		nfd = sip_send_tcp_request(0, addr, port, msg, 
					   0/*don't wait*/);
		close(nfd);
		return 0;
	    }
	}
    }

    /* There's no appropriate fd - guess it got closed and reused. */
    nfd = sip_send_tcp_request(0, addr, port, msg, 0/*don't wait*/);
    close(nfd);
    return 0;
}

int sip_send_tcp_reply_to_fd(int fd, char *msg)
{
    fprintf (stderr,"\nsending reply mesg: %s\n", msg);
    write(fd, msg, strlen(msg));
    /* 
     * If we close we have to go to time-wait.  Give the client the chance to
     * close first, and it they don't we will eventually do so.
     */
    /*  close(fd);*/
    return 0;
}

int sip_finished_reading_tcp(char *data, int len) 
{
    char *ptr;
    char contentlen[20];
    int clen=0;

    fprintf (stderr,"checking for content-length\n");
    if (extract_field(data, contentlen, 20, "content-length")==0) {
	clen=atoi(contentlen);
    }
    fprintf (stderr,"clen=%d\n", clen);
    ptr=find_end_of_header(data, len);
    fprintf (stderr,"eoh at %x, start at %x, len: %d\n", (unsigned int)ptr, 
	   (unsigned int)data, len);

    if (ptr==NULL) return 0;

    if (clen==0) return 1;

    if ((ptr-data)+clen<=len) return 1;

    return 0;
}

char *find_end_of_header(char *data, int len) 
{
    char *ptr=data;

    len-=4;
    while(len>0) {
	if (strncmp(ptr, "\r\n\r\n", 4)==0)
	    return ptr+4;
	ptr++;
    }
    return NULL;
}

char *sip_generate_callid()
{
    static char callid[40];
    struct timeval tv;
    pid_t pid;
    
    gettimeofday(&tv, NULL);
    pid = getpid();
    sprintf(callid, "%d-%d@%s", (unsigned int)pid, (int) tv.tv_sec, hostname);
    return &callid[0];
}




int sip_parse_recvd_data(char *buf, int length, int sipfd, char *srcaddr)
{
    char sipfdstr[10];
    char *dstname;
    char *srcuser, *dstuser, *path, *cseq, *callid;
    int method;
    char u_at_h[80];
    char u_at_a[80];
    struct in_addr myhost;


    MDEBUG(SIP,("SIP announcement received [len=%d]\n***VVV***\n%s***^^^***\n",
		length, buf));
    
    if (is_a_sip_request(buf)) {
	MDEBUG(SIP,("It's a request\n"));
	dstname=sip_get_dstname(buf);
	/*
	 * There could be more than one request in this buffer - find out
	 * how long the first request is.
	 */
	sprintf(u_at_h, "%s@%s", username, hostname);
	myhost.s_addr=hostaddr;
	sprintf(u_at_a, "%s@%s", username, inet_ntoa(myhost));
	
	if (dstname==NULL) {
	    MDEBUG(SIP,("sip_parse_recv_data (sip.c): dstname != NULL???\n"));
	    return 0; /* REVIEW: What to do? */
	}
	
	fprintf (stderr,"dstname:>%s<\nu_at_h:>%s<\nu_at_a:>%s<\nsipalias:>%s<\n",
	       dstname, u_at_h, u_at_a, sipalias);
	fprintf (stderr,"who's the request for?!\n");
	if (((dstname!=NULL)&&(strcmp(u_at_h, dstname)==0)) || 
	    ((dstname!=NULL)&&(strcmp(u_at_a, dstname)==0)) || 
	    ((dstname!=NULL)&&(strcmp(sipalias, dstname)==0))) {
	    
	    fprintf (stderr,"It's for a request for me!\n");
	    
	    Tcl_SetVar(interp, "sip_advert", buf, TCL_GLOBAL_ONLY);
	    sprintf(sipfdstr, "%d", sipfd);
	    Tcl_SetVar(interp, "sip_fd", sipfdstr, TCL_GLOBAL_ONLY);
	    if (Tcl_VarEval(interp, 
		     "sip_user_alert  $sip_fd  $sip_advert ", NULL)!=TCL_OK) {
		Tcl_AddErrorInfo(interp, "\n");
		/*	    fprintf(stderr, "%s\n", interp->result);       */
		/*	    Tcl_VarEval(interp, "puts $errorInfo", NULL);  */
	    };
	} else {
	    fprintf (stderr,"But it's not for me :-(\n");
	    sprintf(sipfdstr, "%d", sipfd);
	    callid=malloc(80);
	    srcuser=malloc(80);
	    dstuser=malloc(80);
	    path=malloc(256);
	    cseq=malloc(80);
	    method=sip_get_method(buf);
	    extract_field(buf, callid, 80, "Call-ID");
	    extract_field(buf, srcuser, 80, "From");
	    extract_field(buf, dstuser, 80, "To");
	    extract_field(buf, path, 80, "Via");
	    extract_field(buf, cseq, 80, "Cseq");
	    fprintf (stderr,"path: >%s<\n", path);
	    fprintf (stderr,"cseq: >%s<\n", cseq);
	    switch(method) {
		case INVITE:
		    if (Tcl_VarEval(interp, "sip_send_unknown_user ", 
				    sipfdstr ," ", callid, " {", srcuser, 
				    "} {", dstuser, "} {", path, "} {", 
				    cseq, "} INVITE", NULL)!=TCL_OK) {
			Tcl_AddErrorInfo(interp, "\n");
			fprintf(stderr, "%s\n", interp->result);
			Tcl_VarEval(interp, "puts $errorInfo", NULL);
		    };
		    break;
		case OPTIONS:
		    if (Tcl_VarEval(interp, "sip_send_unknown_user ", 
				    sipfdstr ," ", 
				    callid, " {", srcuser, "} {", dstuser, 
				    "} {", path, 
				    "} {", cseq, "} OPTIONS", NULL)!=TCL_OK) {
			Tcl_AddErrorInfo(interp, "\n");
			fprintf(stderr, "%s\n", interp->result);
			Tcl_VarEval(interp, "puts $errorInfo", NULL);
		    };
		    break;
		case BYE:
		    if (Tcl_VarEval(interp, "sip_send_unknown_user ", sipfdstr,
				    " ", callid, " {", srcuser, "} {", dstuser,
				    "} {", path, "} {", cseq, "} BYE", 
				    NULL)!=TCL_OK) {
			Tcl_AddErrorInfo(interp, "\n");
			fprintf(stderr, "%s\n", interp->result);
			Tcl_VarEval(interp, "puts $errorInfo", NULL);
		    };
		    break;
		case ACK:
		    if (Tcl_VarEval(interp, "sip_unknown_user_ack ", 
				    callid, NULL)!=TCL_OK) {
			Tcl_AddErrorInfo(interp, "\n");
			fprintf(stderr, "%s\n", interp->result);
			Tcl_VarEval(interp, "puts $errorInfo", NULL);
		    };
		    break;
		case CANCEL:
		    /*XXX should we send an ACK here?  I think so...*/
		    break;
		case REGISTER:
		    if (Tcl_VarEval(interp, "sip_send_method_unsupported ", 
				    sipfdstr ," ", 
				    callid, " {", srcuser, "} {", 
				    dstuser, "} {",  path, "} {", cseq, 
				    "} REGISTER", NULL)!=TCL_OK) {
			Tcl_AddErrorInfo(interp, "\n");
			fprintf(stderr, "%s\n", interp->result);
			Tcl_VarEval(interp, "puts $errorInfo", NULL);
		    };
		    break;
	    }
	    free(callid);free(srcuser);free(dstuser);free(path);free(cseq);
	}
	
    } else if(is_a_sip_reply(buf)) {
	MDEBUG(SIP,("It's a reply\n"));
	parse_sip_reply(sipfd, buf, srcaddr);
	
    } else {
	MDEBUG(SIP,("Don't know what it is!\n"));
    }
    
    return(0);
}

