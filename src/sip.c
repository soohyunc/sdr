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
#ifndef WIN32
#include <arpa/nameser.h>
#include <resolv.h>
#endif
#include "dns.h"
#include "prototypes.h"
/*#define DEBUG*/
#define MAXINVITES 20

extern int siprxsock;
extern int siptxsock;
extern char username[];
extern char sipalias[];
extern Tcl_Interp *interp;
int sip_recv()
{
  int length;
  char *dstname;
  char pktsrc[256];
  static char buf[MAXADSIZE];
  struct sockaddr_in from;
  int fromlen=sizeof(struct sockaddr);
  if ((length = recvfrom(siprxsock, (char *) buf, MAXADSIZE, 0,
                       (struct sockaddr *)&from, (int *)&fromlen)) < 0) {
      perror("sip recv error");
      return 0;
  }
  strcpy(pktsrc, inet_ntoa(from.sin_addr));
  if (length==MAXADSIZE) {
      /*some sneaky bugger is trying to splat the stack?*/
      fprintf(stderr, "Warning: 2K announcement truncated\n");
  }
  buf[length]='\0';
#ifdef DEBUG
  printf("SIP announcement received (len=%d)\n%s\n", length, buf);
#endif
  if (is_a_sip_request(buf))
    {
#ifdef DEBUG
      printf("It's a request\n");
#endif
      dstname=sip_get_dstname(buf);
      if (((dstname!=NULL)&&(strcmp(username, dstname)==0)) || 
	  ((dstname!=NULL)&&(strcmp(sipalias, dstname)==0)))
	{
#ifdef DEBUG
	  printf("It's for a request for me!\n");
#endif
	  Tcl_SetVar(interp, "sip_advert", buf, TCL_GLOBAL_ONLY);
	  if (Tcl_VarEval(interp, "sip_user_alert $sip_advert", NULL)!=TCL_OK)
	    {
	      Tcl_AddErrorInfo(interp, "\n");
	      fprintf(stderr, "%s\n", interp->result);
	      Tcl_VarEval(interp, "puts $errorInfo", NULL);
	    };
	}
    }
  else if(is_a_sip_reply(buf))
    {
#ifdef DEBUG
      printf("It's a reply\n");
#endif
      parse_sip_reply(buf, pktsrc);
    }
  else
    {
#ifdef DEBUG
      printf("Don't know what it is!\n");
#endif
    }
  return(0);
}


int parse_sip_success(char *msg, char *addr)
{
  if (Tcl_VarEval(interp, "sip_success \"", msg, "\" ", addr, NULL)!=TCL_OK)
    {
      Tcl_AddErrorInfo(interp, "\n");
      fprintf(stderr, "%s\n", interp->result);
      Tcl_VarEval(interp, "puts $errorInfo", NULL);
    };
  return 0;
}

int parse_sip_fail(char *msg, char *addr)
{
  if (Tcl_VarEval(interp, "sip_failure \"", msg, "\" ", addr, NULL)!=TCL_OK)
    {
      Tcl_AddErrorInfo(interp, "\n");
      fprintf(stderr, "%s\n", interp->result);
      Tcl_VarEval(interp, "puts $errorInfo", NULL);
    };
  return 0;
}

int parse_sip_redirect(char *msg, char *addr)
{
  if (Tcl_VarEval(interp, "sip_moved \"", msg, "\" ", addr, NULL)!=TCL_OK)
    {
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

int parse_sip_progress(char *msg, char *addr)
{
#ifdef DEBUG
  printf("parse_sip_ringing\n");
#endif
  if (Tcl_VarEval(interp, "sip_status \"", msg, "\" ", addr, NULL)!=TCL_OK)
    {
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
