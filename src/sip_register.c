/*
 * Copyright (c) 1995,1996 University College London
 *           (c) 1997 University of Southern California             
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
#include "prototypes.h"
#include "ui_fns.h"
#include "mdebug.h"

#ifndef WIN32
#include <sys/file.h>
#define NBCONNECT
#include <sys/uio.h>
#endif

#include <tcl.h>

extern char hostname[];
extern char username[];
extern Tcl_Interp *interp;
extern char *webdata;
extern int webblocks;
extern int webdatalen;

#define MAXURLLEN 256

int send_sip_register(char *uridata, char *proxyuri, char *user_data);

int sip_register()
{
    /* 
     * We use HTTP to register to a SIP server so people can call us
     * without knowing which host we're on.
     */
#define MAXEMAILLEN 80
#ifdef NEVER
#define MAXURLLEN 256
#endif
#define MSGLEN 2048

    char emailaddr[MAXEMAILLEN];
    char *serverurl;  
    char msg[MSGLEN];
    int retval;

    strncpy(emailaddr, 
	    Tcl_GetVar(interp, "youremail", TCL_GLOBAL_ONLY), 
	    MAXEMAILLEN);

    if ((strlen(emailaddr)==0)||(strchr(emailaddr,'@')==0))
	return -1;

    serverurl=malloc(MAXURLLEN);

    strncpy(serverurl,
	    Tcl_GetVar(interp, "sip_server_url", TCL_GLOBAL_ONLY),
	    MAXURLLEN);


    if ((strlen(serverurl)==0)||(is_a_sip_url(serverurl)==0)) {
	free(serverurl);
	return -1;
    }

    strcpy(msg, "REGISTER sip:");
    strcat(msg, emailaddr);
    strcat(msg, " SIP/2.0\r\nVia: SIP/2.0/UDP ");
    strcat(msg, hostname);
    strcat(msg, "\r\nCall-ID: ");
    strcat(msg, sip_generate_callid());
    strcat(msg, "\r\nTo: sip:");
    strcat(msg, emailaddr);
    strcat(msg, "\r\nFrom: sip:");
    strcat(msg, emailaddr);
    strcat(msg, "\r\nLocation: sip:");
    strcat(msg, username);
    strcat(msg, "@");
    strcat(msg, hostname);
    strcat(msg, "\r\nContent-length:0\r\n\r\n");
    retval = send_sip_register(serverurl, NULL, msg);
    free(serverurl);
    return retval;
}

int send_sip_register(char *uridata, char *proxyuri, char *user_data)
{
    MDEBUG(REG,("send_sip_register %s\n %s\n", uridata, user_data));
    
    if (is_a_sip_url(uridata)==1) {
	int port=0, transport=SIP_NO_TRANSPORT, ttl=0;
#ifdef NEVER
	char host[strlen(uridata)], maddr[strlen(uridata)], url[strlen(uridata)];
#else
	char host[MAXURLLEN], maddr[MAXURLLEN], url[MAXURLLEN];
#endif
	strcpy(url, uridata);
	parse_sip_url(url, NULL, NULL, host, &port, &transport, &ttl, maddr, 
		      NULL, NULL);
	/*set appropriate defaults for register*/
	if (port==0) port=SIP_PORT;
	if (transport==SIP_NO_TRANSPORT) transport=SIP_TCP_TRANSPORT;
	if ((strlen(maddr)>0)&&(ttl==0)) ttl=16;
	
	if (transport==SIP_TCP_TRANSPORT) {
	    sip_send_tcp_register(host, port, user_data);
	} else {
	    if (strlen(maddr)>0) {
		sip_send_mcast_register(host, maddr, port, ttl, user_data);
	    } else {
		sip_send_udp_register(host, port, user_data);
	    }
	}
    } else {
	fprintf(stderr, "invalid SIP URL entered: %s\n", uridata);
    }
    return 0;
}

int sip_send_mcast_register (const char *host, const char *maddr, int port, 
			    int ttl, const char *user_data)
{
    return -1;
}

int sip_send_udp_register(const char *host, int port, const char *user_data)
{
    return -1;
}

int sip_send_tcp_register(const char *host, int port, char *user_data)
{
    return(sip_send_tcp_request(0, host, port, user_data, 
				1 /*wait for reply*/ ));
}

