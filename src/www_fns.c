/*
 * Copyright (c) 1995,1996 University College London
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

extern char *help[];
extern char *helpdata[];
extern int no_of_help;
char *webdata=NULL;
int webblocks=0;
#define BLOCKSIZE 100000
#define READSIZE 1024
int webdatalen;
#ifdef DEBUG
static char msg[80];
#endif
int stoploading=0;

static int www_perror(Tcl_Interp *, char *, int);

int ui_webto(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  char uridata[1024];
  char *uri, *end, *t1, *t2, *proto;
  struct sockaddr_in sinhim;
  struct hostent *addr;
  unsigned long inaddr;
  int fd, i, usingproxy, reload;
  int webstate;
#define	CONNECTING	1
#define	READING		2
  struct msghdr msg;
  struct iovec iov[6];
  int iovlen;
#ifdef MSG_EOF
  int usettcp = 1;
#endif

  if (webdata==NULL) {
    webdata=malloc(BLOCKSIZE);
    webblocks=1;
  }
  stoploading=0;
  if (argc < 2 || argc > 5)
    {
      sprintf(interp->result, "Content-Type: text/html\n\nusage: webto url [proxy] [reload] [nottcp] [argc=%d]\n",argc);
      return TCL_OK;
    }
  usingproxy = (argc >= 3 && *argv[2]);
  reload = (argc >= 4 && (*argv[3] == 'r'));
#ifdef MSG_EOF
  if (argc >= 5 && (*argv[4] == 'n'))
    usettcp = 0;
#endif
  strncpy(uridata,argv[1], 1024);
#ifdef DEBUG
  printf("URI: %s\n", uridata);
#endif
  uri=uridata;
  proto=uri;
  end=strchr(uri,':');
  if(end==0)
    {
      fprintf(stderr, "Parse error in URL: %s\n", uri);
      strcpy(interp->result, "Content-Type: text/html\n\nParse error in URL\n");
      return TCL_OK;
    }
  *end='\0';
  if(strncmp(proto, "help", 4)==0)
    {
#ifdef DEBUG
      printf("Page: %s\n", end+1);
#endif
      strcpy(webdata, "Content-Type: text/html\n\n");
      for(i=0;i<no_of_help;i++) 
	{
	  if(strcmp(end+1,help[i])==0)
	    strcat(webdata,helpdata[i]);
	}
      interp->result=webdata;
    }
  else if (strncmp(proto, "http", 4)==0 || usingproxy)
    {
      int port=80;
      char file[256];

      if (usingproxy)	/* Using proxy */
	{
	  uri = argv[2];
	  *end = ':';
	  strncpy(file, argv[1], sizeof(file) - 1);
	}
      else
	{
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
	      sprintf(interp->result, "Content-Type: text/html\n\n<html><h1>Unknown Host</h1>%s does not exist</html>", uri);
	      return TCL_OK;
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

      Tcl_SetVar2(interp, "webstatus", NULL, "Connecting...", TCL_GLOBAL_ONLY);
      Tcl_Eval(interp, "webstatus");
      while (Tk_DoOneEvent(TK_DONT_WAIT)) ;
try_again:
      if((fd=socket(AF_INET, SOCK_STREAM, 0))<0)
	{
	  return www_perror(interp, "socket", errno);
	}
#ifdef NBCONNECT
      fcntl(fd, F_SETFL, FNDELAY);
#endif

      iovlen = 0;
      iov[iovlen].iov_base = "GET ";
      iov[iovlen++].iov_len = 4;
      iov[iovlen].iov_base = file;
      iov[iovlen++].iov_len = strlen(file);
      iov[iovlen].iov_base = " HTTP/1.0\r\nUser-agent: sdrwww ";
      iov[iovlen++].iov_len = 30;
      iov[iovlen].iov_base = Tcl_GetVar(interp, "sdrversion", TCL_GLOBAL_ONLY);
      iov[iovlen].iov_len = strlen(iov[iovlen].iov_base);
      iovlen++;
      if (reload) {
	iov[iovlen].iov_base = "\r\nPragma: nocache";
	iov[iovlen++].iov_len = 17;
      }
      iov[iovlen].iov_base = "\r\nAccept: text/plain\r\n"
			     "Accept: text/html\r\nAccept: image/*\r\n\r\n";
      iov[iovlen++].iov_len = 60;

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
	  return www_perror(interp, "connect/send", errno);
	}
#else
      if (connect(fd, (struct sockaddr *)&sinhim, sizeof(struct sockaddr_in))<0
#ifdef NBCONNECT
		&& errno != EINPROGRESS
#endif
	 )
	{
	  return www_perror(interp, "connect", errno);
	}
#endif

      webdatalen=0;
      webstate = CONNECTING;
      while (stoploading==0)
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
			return www_perror(interp, "getsockopt", errno);
		  }
#else
		  return www_perror(interp, "getsockopt", errno);
#endif
		}
		if (err != 0) 
		  {
		    return www_perror(interp, "connect", err);
		  }
		fcntl(fd, F_SETFL, 0);
#endif
#ifndef MSG_EOF
		sendmsg(fd, &msg, 0);
#endif
		Tcl_SetVar2(interp, "webstatus", NULL, "Receiving...", TCL_GLOBAL_ONLY);
		Tcl_Eval(interp, "webstatus");
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
#ifdef DEBUG
	      sprintf(msg, "Read %d bytes", webdatalen);
	      printf("%s", msg);
	      Tcl_SetVar2(interp, "webstatus", NULL, msg, TCL_GLOBAL_ONLY);
	      if(Tcl_Eval(interp, "webstatus")!=0) {printf("%s\n", interp->result);}
#endif
	      Tcl_Eval(interp, "update");
	    }
	  else 
	    {
	      Tcl_Eval(interp, "show_active");
	      while (Tk_DoOneEvent(TK_DONT_WAIT)) ;
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
      strcpy(interp->result, "Unknown protocol");
    }
  return TCL_OK;
}

static int www_perror(interp, who, err)
    Tcl_Interp *interp;			/* Current Interpreter. */
    char *who;				/* Function that errored */
    int err;				/* Errno */
{
    char *p = strerror(err);

    if (p == NULL)
	sprintf(interp->result, "Content-Type: text/html\n\n"
				"<html><h1>Error</h1>"
				"%s: Unknown error %d"
				"</html>\n", who, err);
    else
	sprintf(interp->result, "Content-Type: text/html\n\n"
				"<html><h1>Error</h1>"
				"%s: %s"
				"</html>\n", who, p);
    return TCL_OK;
}

int ui_save_www_data_to_file (dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  FILE *file;
  file=fopen(argv[2], "w");
  fwrite(&webdata[atoi(argv[1])], 1, webdatalen-atoi(argv[1]), file);
  fclose(file);
  return TCL_OK;
}

int ui_stop_www_loading () 
{
  stoploading=1;
  return TCL_OK;
}
