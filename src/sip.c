/*
 * Copyright (c) 1996 University College London
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

#ifdef WIN32
#define MAX_FD 512
#else
#define MAX_FD 64
#endif

#ifndef WIN32
#include <arpa/nameser.h>
#include <resolv.h>
#endif
#include "dns.h"
#include "prototypes.h"
#define MAXINVITES 20

extern int sip_udp_rx_sock;
extern int sip_udp_tx_sock;
extern char username[];
extern char hostname[];
extern char sipalias[];
extern unsigned long hostaddr;
extern Tcl_Interp *interp;


/* Global debug variables */

/* MDEBUG defined in sip.h for now. */
int mdebug = MDEBUG_FLAG;
#include "mdebug.h"

connection sip_tcp_conns[MAX_CONNECTIONS];

int sip_recv_udp()
{
    int length;
    char pktsrc[256];
    static char buf[MAXADSIZE];
    struct sockaddr_in from;
    int fromlen=sizeof(struct sockaddr);
    if ((length = recvfrom(sip_udp_rx_sock, (char *) buf, MAXADSIZE, 0,
			   (struct sockaddr *)&from, (int *)&fromlen)) < 0) {
	perror("sip recv error");
	return 0;
    }
    strcpy(pktsrc, inet_ntoa(from.sin_addr));
    if (length==MAXADSIZE) {
	/*some sneaky bastard is trying to splat the stack?*/
	fprintf(stderr, "Warning: 2K announcement truncated\n");
    }
    buf[length]='\0';
    return (sip_parse_recvd_data(buf, length, 0, pktsrc));
}

/* MM comment out sip_parse_recvd_data here and put in sip_common.c */
#ifndef SIP_SERVER
#if 0

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
	
	printf("dstname:>%s<\nu_at_h:>%s<\nu_at_a:>%s<\nsipalias:>%s<\n",
	       dstname, u_at_h, u_at_a, sipalias);
	printf("who's the request for?!\n");
	if (((dstname!=NULL)&&(strcmp(u_at_h, dstname)==0)) || 
	    ((dstname!=NULL)&&(strcmp(u_at_a, dstname)==0)) || 
	    ((dstname!=NULL)&&(strcmp(sipalias, dstname)==0))) {
	    
	    printf("It's for a request for me!\n");
	    
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
	    printf("But it's not for me :-(\n");
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
	    printf("path: >%s<\n", path);
	    printf("cseq: >%s<\n", cseq);
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

#endif /* if 0 */
#endif /* #ifndef SIP_SERVER */


int sip_recv_tcp()
{
    /*Got a new TCP request*/
    int i;
    
    /* Need to be able to distinguish the new connection. */
    for(i=0;i<MAX_CONNECTIONS;i++)
	if (sip_tcp_conns[i].used==1) sip_tcp_conns[i].used=2;
    sip_tcp_accept(sip_tcp_conns);
    for(i=0;i<MAX_CONNECTIONS;i++) {
	if (sip_tcp_conns[i].used==2) 
	    sip_tcp_conns[i].used=1;
	else if (sip_tcp_conns[i].used==1) {
	    /* This is the new connection. */
	    MDEBUG(SIP, ("Accepted new SIP TCP connection from %s\n", 
			 sip_tcp_conns[i].addr));
	    linksocket(sip_tcp_conns[i].fd, TK_READABLE, 
		       (Tcl_FileProc*)sip_readfrom_tcp);
	}
    }
    return 0;
}

int sip_readfrom_tcp() 
{
    int i, bytes, consumed;
    char callid[80], *parsebuf;
    fd_set readfds;

    /* debug_tcp_conns(); (1.13) */
    
    /* Got new data on an existing TCP socket. */
    for(i=0;i<MAX_CONNECTIONS;i++) {
	if (sip_tcp_conns[i].used==1)
	    FD_SET(sip_tcp_conns[i].fd, &readfds);
    }

    select(MAX_FD, &readfds, NULL, NULL, NULL);

    for(i=0;i<MAX_CONNECTIONS;i++) {
	if ((sip_tcp_conns[i].used==1)&&(FD_ISSET(sip_tcp_conns[i].fd, 
						  &readfds))) {
	    printf("on connection %d\n", i);
	    if (sip_tcp_conns[i].bufsize<(1500+sip_tcp_conns[i].len)) {
		/*need to allocate more buffer space before we read*/
		sip_tcp_conns[i].buf=realloc(sip_tcp_conns[i].buf,
					     6000+sip_tcp_conns[i].len);
	    }

	    bytes=read(sip_tcp_conns[i].fd, 
		       &(sip_tcp_conns[i].buf[sip_tcp_conns[i].len]),
		       1500);
	    printf("read %d bytes from connection %d\n", bytes, i);
	    if (bytes==0) {
		fprintf(stderr, "connection aborted\n");
		unlinksocket(sip_tcp_conns[i].fd);
		sip_tcp_free(&sip_tcp_conns[i]);
		return -1;
	    }

	    (sip_tcp_conns[i].len)+=bytes;
		printf("length %d bytes\n", sip_tcp_conns[i].len);
		
		/*
		 * We can get multiple requests arrive concatenated.
		 * We need to consume each in turn, and leave any spare bytes 
		 * from the last request still in the buffer because requests 
		 * do not necessarily arrive all in one piece with TCP.  
		 */
		while ((consumed=sip_request_ready(sip_tcp_conns[i].buf, 
						   sip_tcp_conns[i].len))>0) {
		    printf("sip request ready\n");
		    extract_field(sip_tcp_conns[i].buf, callid, 80, "Call-ID");
		    printf("callid: %s\n", callid);
		    if (callid==NULL) {
			fprintf(stderr, "Failed to extract call id\n");
			return -1;
		    }
		    sip_tcp_conns[i].callid=strdup(callid);
		    parsebuf=malloc(consumed+1);
		    memcpy(parsebuf, sip_tcp_conns[i].buf, consumed);
		    parsebuf[consumed]='\0';
		    sip_parse_recvd_data(parsebuf, 
					 consumed,
					 sip_tcp_conns[i].fd, 
					 sip_tcp_conns[i].addr);
		    free(parsebuf);
		    if (consumed > 0) {
			memcpy(sip_tcp_conns[i].buf, 
			       sip_tcp_conns[i].buf+consumed, 
			       sip_tcp_conns[i].len+1-consumed);
			sip_tcp_conns[i].len-=consumed;
		    }
		}
	}
    }
    return 1; // REVIEW: what should we return?! 

    /* debug_tcp_conns(); (1.13) */
}


int parse_sip_success(int sipfd, char *msg, char *addr)
{
    char sipfdstr[10];
    sprintf(sipfdstr, "%d", sipfd);
    if (Tcl_VarEval(interp, "sip_success ", sipfdstr, " \"", msg, "\" ", 
		    addr, NULL)!=TCL_OK) {
	Tcl_AddErrorInfo(interp, "\n");
	fprintf(stderr, "%s\n", interp->result);
	Tcl_VarEval(interp, "puts $errorInfo", NULL);
    };
    return 0;
}

int parse_sip_fail(int sipfd, char *msg, char *addr)
{
    char sipfdstr[10];
    sprintf(sipfdstr, "%d", sipfd);
    if (Tcl_VarEval(interp, "sip_failure ", sipfdstr, " \"", msg, "\" ", 
		    addr, NULL)!=TCL_OK) {
	Tcl_AddErrorInfo(interp, "\n");
	fprintf(stderr, "%s\n", interp->result);
	Tcl_VarEval(interp, "puts $errorInfo", NULL);
    };
    return 0;
}

int parse_sip_redirect(int sipfd, char *msg, char *addr)
{
    char sipfdstr[10];

    sprintf(sipfdstr, "%d", sipfd);

    if (Tcl_VarEval(interp, "sip_moved ", sipfdstr, " \"", msg, "\" ",
		    addr, NULL)!=TCL_OK) {
	Tcl_AddErrorInfo(interp, "\n");
	fprintf(stderr, "%s\n", interp->result);
	Tcl_VarEval(interp, "puts $errorInfo", NULL);
    };
    return 0;
}

int parse_sip_fa(char *msg, char *addr)
{
    return 0;
}

int parse_sip_progress(int sipfd, char *msg, char *addr)
{
    char sipfdstr[10];

    sprintf(sipfdstr, "%d", sipfd);

   MDEBUG(SIP, ("parse_sip_ringing\n"));

   if (Tcl_VarEval(interp, "sip_status ", sipfdstr, " \"", msg, "\" ",
		   addr, NULL)!=TCL_OK) {
       Tcl_AddErrorInfo(interp, "\n");
       fprintf(stderr, "%s\n", interp->result);
       Tcl_VarEval(interp, "puts $errorInfo", NULL);
   };
   return 0;
}

#ifdef NOTDEF
int sip_tx_init(char *address, int port, char ttl) 
{
    int txsock;
    struct sockaddr_in name;
    unsigned int group;
    int one=1;
#ifdef WIN32
    int wttl;
#endif

    group = inet_addr(address);
    if((txsock=socket( AF_INET, SOCK_DGRAM, 0 )) < 0) {
        perror("socket");
        return(-1);
    }
    setsockopt(txsock, SOL_SOCKET, SO_REUSEADDR,
               (char *)&one, sizeof(one));
#ifndef WIN32
    fcntl(txsock, F_SETFD, 1);
#else
    memset((char*)&name, 0, sizeof(name));
    name.sin_family = AF_INET;
    name.sin_addr.s_addr = INADDR_ANY;
    name.sin_port = 0;
    if (bind(txsock, (struct sockaddr *)&name, sizeof(name))) {
        perror("bind");
        exit(1);
    }
    name.sin_family = AF_INET;
    name.sin_addr.s_addr = htonl(group);
    name.sin_port = htons(port);
    if (connect(txsock, (struct sockaddr *)&name, sizeof(struct sockaddr_in))<0)
      {
	perror("connect");
	fprintf(stderr, "Dest Address problem\n");
	return(-1);
      }
#endif
#ifndef WIN32
    if (IN_CLASSD(ntohl(group)))
#endif
      {
#ifdef WIN32
	u_int wttl = ttl;
	if (setsockopt(txsock, IPPROTO_IP, IP_MULTICAST_TTL, (char *)&wttl, 
		       sizeof(wttl))<0)
#else
	    if (setsockopt(txsock, IPPROTO_IP, IP_MULTICAST_TTL, (char *)&ttl, 
			   sizeof(ttl))<0)
#endif
		{
		    fprintf(stderr, "ttl: %d\n", ttl);
		    perror("setsockopt ttl");
		    return(-1);
		}
      }
    return(txsock);
}
#endif

void sdr_update_ui() {
    while(Tcl_DoOneEvent(TCL_DONT_WAIT));
}

int sip_close_tcp_connection(char *callid)
{
    int i;
    
    for(i=0;i<MAX_CONNECTIONS; i++) {
	if ((sip_tcp_conns[i].used==1) && 
	    (strcmp(sip_tcp_conns[i].callid,callid)==0)) {
	    unlinksocket(sip_tcp_conns[i].fd);
	    close(sip_tcp_conns[i].fd);
	    sip_tcp_free(&sip_tcp_conns[i]);
	    return TCL_OK;
	}
    }
    return TCL_OK;
}

