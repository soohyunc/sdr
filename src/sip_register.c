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
#include "prototypes.h"
#include "ui_fns.h"

#ifndef WIN32
#include <sys/file.h>
#define NBCONNECT
#include <sys/uio.h>
#endif


#include <tcl.h>
#ifndef INADDR_NONE
#define INADDR_NONE     0xffffffff
#endif

extern char hostname[];
extern char username[];
extern Tcl_Interp *interp;
extern char *webdata;
extern int webblocks;
#define BLOCKSIZE 100000
#define READSIZE 1024
extern int webdatalen;
#ifdef DEBUG
static char msg[80];
#endif

int send_sip_register(char *uridata, char *proxyuri, char *user_data);

int sip_register()
{
  /*We use HTTP to register to a SIP server so people can call us
    without knowing which host we're on*/
  #define MAXEMAILLEN 80
  #define MAXURLLEN 256
  #define MSGLEN 2048
  char emailaddr[MAXEMAILLEN];
  char serverurl[MAXURLLEN];
  char msg[MSGLEN];
  strncpy(emailaddr, 
	  Tcl_GetVar(interp, "youremail", TCL_GLOBAL_ONLY), 
	  MAXEMAILLEN);
  if ((strlen(emailaddr)==0)||(strchr(emailaddr,'@')==0))
    return -1;
  strncpy(serverurl,
	  Tcl_GetVar(interp, "sip_server_url", TCL_GLOBAL_ONLY),
	  MAXURLLEN);
  if ((strlen(serverurl)==0)||(strncmp(serverurl,"http://",7)!=0))
    return -1;
  strcat(msg, "user:");
  strcat(msg, emailaddr);
  strcat(msg, "\r\nredirect:");
  strcat(msg, username);
  strcat(msg, "@");
  strcat(msg, hostname);
  strcat(msg, "\r\n");
  strcat(msg, "proto:udp\r\n");
  strcat(msg, "action:redirect\r\n");
  strcat(msg, "ttl:0\r\n");
  return(send_sip_register(serverurl, NULL, msg));
}

int send_sip_register(char *uridata, char *proxyuri, char *user_data)
{
  
  char *uri, *end, *t1, *t2, *proto, lenbuf[80];
  struct sockaddr_in sinhim;
  struct hostent *addr;
  unsigned long inaddr;
  int fd, usingproxy;
  int webstate;
#define	CONNECTING	1
#define	READING		2
  struct msghdr msg;
  struct iovec iov[10];
  int iovlen;
#ifdef MSG_EOF
  int usettcp = 1;
#endif

#ifdef DEBUG
  printf("send_sip_register %s %s", uridata, user_data);
#endif
  uri=uridata;
  proto=uri;
  if (proxyuri!=NULL)
    usingproxy=1;
  end=strchr(uri,':');
  if(end==0)
    {
      fprintf(stderr, "Parse error in URL: %s\n", uri);
      return -1;
    }
  *end='\0';
  if (strncmp(proto, "http", 4)==0 || usingproxy)
    {
      int port=80;
      char file[256];

      uri=end+3;
      t1=strchr(uri, '/');
      if (t1==0)
	{
	  strcpy(file, "/");
	}
      else
	{
	  *t1='\0';
	  file[0]='/';
	  strncpy(&file[1], t1+1, sizeof(file) - 2);
	}
      
      t2=strchr(uri, ':');
      if (t2==0)
	{
	  port=80;
	}
      else
	{
	  port=atoi(t2+1);
	  *t2='\0';
	}
#ifdef DEBUG
      printf("proto=http, host=%s, port=%d, file=%s\n",
	     uri, port, file);
#endif
      if ( (inaddr = inet_addr(uri)) != INADDR_NONE)
	{
	  /* it's dotted-decimal */
	  memcpy((char *)&sinhim.sin_addr.s_addr, (char *)&inaddr, sizeof(inaddr) );
	  sinhim.sin_family = AF_INET;
	}
      else
	{
	  if ((addr=gethostbyname(uri)) == NULL)
	    {
	      fprintf(stderr, "Unknown hostname %s\n", uri);
	    }
	  sinhim.sin_family = addr->h_addrtype;
	  sinhim.sin_family = AF_INET;
	  sinhim.sin_port = htons(port);
#ifdef h_addr
	  memcpy((char*)&sinhim.sin_addr, addr->h_addr_list[0], addr->h_length);
#else
	  memcpy((char*)&sinhim.sin_addr, addr->h_addr, addr->h_length);
#endif
	}

      while (Tk_DoOneEvent(TK_DONT_WAIT)) ;
try_again:
      if((fd=socket(AF_INET, SOCK_STREAM, 0))<0)
	{
	  perror("socket");
	  return -1;
	}
#ifdef NBCONNECT
      fcntl(fd, F_SETFL, FNDELAY);
#endif

      iovlen = 0;
      iov[iovlen].iov_base = "POST ";
      iov[iovlen++].iov_len = 5;
      iov[iovlen].iov_base = file;
      iov[iovlen++].iov_len = strlen(file);
      iov[iovlen].iov_base = " HTTP/1.0\r\nUser-agent: sdrwww ";
      iov[iovlen++].iov_len = 30;
      iov[iovlen].iov_base = Tcl_GetVar(interp, "sdrversion", TCL_GLOBAL_ONLY);
      iov[iovlen].iov_len = strlen(iov[iovlen].iov_base);
      iovlen++;
      iov[iovlen].iov_base = "\r\nPragma: nocache";
      iov[iovlen++].iov_len = 17;
      iov[iovlen].iov_base = "\r\nContent-type: application/x-sip-loc";
      iov[iovlen].iov_len = strlen(iov[iovlen++].iov_base);
      sprintf(lenbuf, "\r\nContent-length: %d", strlen(user_data));
      iov[iovlen].iov_base = lenbuf;
      iov[iovlen].iov_len = strlen(iov[iovlen++].iov_base);
      iov[iovlen].iov_base = "\r\nAccept: text/plain\r\n"
			     "Accept: text/html\r\n\r\n";
      iov[iovlen++].iov_len = 43;
      iov[iovlen].iov_base = user_data;
      iov[iovlen].iov_len = strlen(iov[iovlen++].iov_base);

      /* workaround for accrights / control renaming */
      memset((char *)&msg, 0, sizeof(msg));

      msg.msg_name = (void *)&sinhim;
      msg.msg_namelen = sizeof sinhim;
      msg.msg_iov = iov;
      msg.msg_iovlen = iovlen;
#ifdef MSG_EOF
      msg.msg_flags = usettcp ? MSG_EOF : 0;

      if (sendmsg(fd, &msg, msg.msg_flags) < 0
#ifdef NBCONNECT
		&& errno != EINPROGRESS
#endif
	 )
	{
	  perror("connect/send");
	  return -1;
	}
#else
      if (connect(fd, (struct sockaddr *)&sinhim, sizeof(struct sockaddr_in))<0
#ifdef NBCONNECT
		&& errno != EINPROGRESS
#endif
	 )
	{
	  perror("connect");
	  return -1;
	}
#endif

      webdatalen=0;
      webstate = CONNECTING;
      while (1)
	{
	  int tmp;
	  fd_set r,w;
	  struct timeval tv;

	  tv.tv_sec=0;
	  tv.tv_usec=100000;
	  FD_ZERO(&r);
	  if (webstate == READING) FD_SET(fd, &r);
	  FD_ZERO(&w);
	  if (webstate == CONNECTING) FD_SET(fd, &w);
	  
	  if(select(fd+1, &r, &w, NULL, &tv)!=0)
	    {
	      if (webstate == CONNECTING) {
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
		     * Solaris 2.5's socket emulation returns the connect
		     * error as a getsockopt error.  If getsockopt returns
		     * an error that could have been returned by connect,
		     * use that.
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
		if (err != 0) 
		  {
		    perror("connect");
		    return -1;
		  }
		fcntl(fd, F_SETFL, 0);
#endif
#ifndef MSG_EOF
		sendmsg(fd, &msg, 0);
#endif
		webstate = READING;
		continue;
	      }
	      if((webdatalen+READSIZE)>(webblocks*BLOCKSIZE)) {
		webblocks++;
		webdata=realloc(webdata, webblocks*BLOCKSIZE);
	      }
	      tmp=recv(fd, &webdata[webdatalen], READSIZE, 0);
	      if(tmp <= 0)
		{
		  break;
		}
	      webdatalen+=tmp;
	    }
	  else 
	    {
	    }
	}
      close(fd);
#ifdef MSG_EOF
      /*
       * Some web servers can't handle T/TCP and just close the connection.
       * Try again if we hit one of those.
       */
      if (webdatalen == 0 && usettcp) {
	usettcp = 0;
	goto try_again;
      }
#endif
      webdata[webdatalen]='\0';
      interp->result=webdata;
    }
  else if(strncmp(proto, "ftp", 3)==0)
    {
      Tcl_VarEval(interp, "msgpopup", "Protocol Error", "Sorry - this browser does not yet support ftp URLs", NULL);
    }
  else if(strncmp(proto, "mailto", 6)==0)
    {
      Tcl_VarEval(interp, "msgpopup", "Protocol Error", "Sorry - this browser does not yet support mailto URLs", NULL);
    }
  else
    {
      perror("Unknown protocol");
    }
  return -1;
}

