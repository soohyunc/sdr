/*
 * Copyright (c) 1995,1996 University College London
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
#include "ui_fns.h"
#include "prototypes.h"

extern Tcl_Interp *interp;

extern char hostname[];
extern char username[];
extern char sipalias[];
extern unsigned long hostaddr;
extern int rxsock[];
extern int no_of_rx_socks;
extern int doexit;

int ui_sd_listen(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  sd_listen(argv[1], atoi(argv[2]), rxsock, &no_of_rx_socks, 1);
  return TCL_OK;
}

int ui_generate_port(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;  
{
  sprintf(interp->result, "%d", generate_port(argv[1]));
  return TCL_OK;
}

int ui_generate_id()
{
  int i=0;
  i=(random()&0xffff);
  sprintf(interp->result, "%d", i);
  return TCL_OK;
}

int ui_lookup_host(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  struct in_addr in;
  in=look_up_address(argv[1]);
  sprintf(interp->result, "%s", inet_ntoa(in));
  return TCL_OK;
}

int ui_sip_send_udp(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  int code;
  /*addr, ttl, port, message*/
  code=sip_send_udp(argv[1], atoi(argv[2]), atoi(argv[3]), argv[4]);
  switch (code)
    {
    case 0:
      sprintf(interp->result, "0");
      return TCL_OK;
    case 61:
      sprintf(interp->result, "-1");
      return TCL_OK;
    default:
      return(code);
    }
}

int ui_sip_send_tcp_request(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  int fd;
  /*fd, addr, port, msg, wait*/
  /*fd here is so we can reuse existing connections for ACK and BYE*/
  /*fd will be 0 if there is no connection to reuse*/
  fd=sip_send_tcp_request(atoi(argv[1]), argv[2], atoi(argv[3]), 
			    argv[4], 1/*wait for reply*/);
  sprintf(interp->result, "%d", fd);
  return TCL_OK;
}

int ui_sip_send_tcp_reply(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  int code;
  /*fd, callid, addr, port, msg*/
  code=sip_send_tcp_reply(atoi(argv[1]), argv[2], argv[3], 
			  atoi(argv[4]), argv[5]);
  switch (code)
    {
    case 0:
      sprintf(interp->result, "0");
      return TCL_OK;
    default:
      return(code);
    }
}

int ui_set_sipalias(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  strncpy(sipalias, argv[1], MAXALIAS-1);
  return TCL_OK;
}
 
int ui_check_address(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  struct in_addr in;
  in.s_addr=inet_addr(argv[1]);
  if(check_address(&in)==TRUE)
    {
      interp->result="ok";
    }
  else
    {
      interp->result="dup";
    }
  return TCL_OK;
}
 
int ui_generate_address(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  struct in_addr in;
  if (argc==1) {
    in=generate_address(NULL, interp->result, 0);
  } else {
    in.s_addr=inet_addr(argv[1]);
    in=generate_address(&in, atoi(argv[2]));
  }
  strcpy(interp->result,inet_ntoa(in));
  return TCL_OK;
}

static char daynames[7][4];
static char longdaynames[7][21];
static char monnames[12][4];
static char longmonnames[12][21];

#ifdef WIN32
/*XXX - tcl7.5 'clock' function slightly broken under win32 */
static const char *days[]={"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
static const char *mons[]={"Jan", "Feb", "Mar", "Apr", "May", "Jun", 
	      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

void initnames() 
{
  int i;

  for (i = 0; i < 7; ++i)
    {
      strcpy(daynames[i], days[i]);
      strcpy(longdaynames[i], days[i]);
    }
  for (i = 0; i < 12; ++i)
    {
      strcpy(monnames[i], mons[i]);
      strcpy(longmonnames[i], mons[i]);
    }
}
#else
void initnames() 
{
  int i;
  u_int base;
  char buf[128];

  Tcl_Eval(interp, "clock format [clock seconds] -format %w");
  base = atoi(interp->result);
  for(i=0;i<7;i++)
    {
      sprintf(buf, "clock format [clock scan {%d day}] -format %%a", i);
      Tcl_Eval(interp, buf);
      strncpy(daynames[(base + i) % 7], interp->result, 3);

      sprintf(buf, "clock format [clock scan {%d day}] -format %%A", i);
      Tcl_Eval(interp, buf);
      strncpy(longdaynames[(base + i) % 7], interp->result, 20);
    }
  Tcl_Eval(interp, "clock scan 1/1");
  base = atoi(interp->result);
  for(i=0;i<12;i++)
    {
      sprintf(buf, "clock format [clock scan {%d month} -base %u] -format %%h",
	      i, base);
      Tcl_Eval(interp, buf);
      strncpy(monnames[i], interp->result, 3);

      sprintf(buf, "clock format [clock scan {%d month} -base %u] -format %%B",
	      i, base);
      Tcl_Eval(interp, buf);
      strncpy(longmonnames[i], interp->result, 20);
    }
}
#endif

int ui_getdayname(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  int mnum;
  mnum=atoi(argv[1]);
  if ((argc==2)||(strcmp(argv[2],"-short")==0))
    interp->result=daynames[mnum];
  else
    interp->result=longdaynames[mnum];
  return TCL_OK;
}

int ui_getmonname(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  int mnum;
  mnum=atoi(argv[1]);
  if ((argc==2)||(strcmp(argv[2],"-short")==0))
      interp->result=monnames[mnum-1];
  else
      interp->result=longmonnames[mnum-1];
  return TCL_OK;
}

int ui_getemailaddress(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  static char email[256];
  sprintf(email, "%s@%s", username, hostname);
  interp->result=email;
  return TCL_OK;
}

int ui_getusername(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv; 
{
  interp->result=username;
  return TCL_OK;
}

int ui_gethostaddr(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv; 
{
  struct in_addr in;
  in.s_addr=htonl(hostaddr);
  strcpy(interp->result,(char *)inet_ntoa(in));
  return TCL_OK;
}

int ui_gethostname(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv; 
{
  strcpy(interp->result,hostname);
  return TCL_OK;
}

int ui_getpid(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv; 
{
  static char pids[8];
  pid_t pid=0;
#ifndef WIN32
  pid=getpid();
#endif
  sprintf(pids, "%d", (unsigned int)pid);
  interp->result=pids;
  return TCL_OK;
}

int ui_stop_session_ad(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  stop_session_ad(argv[1]);
  return TCL_OK;
}

int ui_sip_parse_url(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  /*do this here and not in TCL because we want a single common SIP
    URL parser for the sip_server and sdr*/

  int port=SIP_PORT, ttl=0, transport=SIP_NO_TRANSPORT;
  char *addr, *user, *passwd, *maddr, *tag, *others, transport_str[5];
  /*allocate enough memory*/
  addr=malloc(strlen(argv[1]));
  *addr='\0';
  user=malloc(strlen(argv[1]));
  *user='\0';
  maddr=malloc(strlen(argv[1]));
  *maddr='\0';
  passwd=malloc(strlen(argv[1]));
  *passwd='\0';
  tag=malloc(strlen(argv[1]));
  *tag='\0';
  others=malloc(strlen(argv[1]));
  *others='\0';
  parse_sip_url(argv[1], user, passwd, addr, &port, &transport, 
    &ttl, maddr, tag, others);
  switch(transport) {
  case SIP_NO_TRANSPORT: 
    strcpy(transport_str, "NONE");
    break;
  case SIP_UDP_TRANSPORT: 
    strcpy(transport_str, "UDP");
    break;
  case SIP_TCP_TRANSPORT: 
    strcpy(transport_str, "TCP");
    break;
  }
  sprintf(interp->result, 
	  "\"%s\" \"%s\" \"%s\" %d \"%s\" %d \"%s\" \"%s\" \"%s\"", 
	  user, passwd, addr, port, transport_str, ttl, maddr, tag, others);
  free(addr);
  free(user);
  free(maddr);
  free(passwd);
  free(tag);
  free(others);
  return TCL_OK;
}

int ui_sip_parse_path(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  /*do this here and not in TCL because we want a single common SIP
    Via field parser for the sip_server and sdr*/

  int port=SIP_PORT, ttl=0, transport=SIP_NO_TRANSPORT;
  char *addr, *version, transport_str[5];
  /*allocate enough memory*/
  addr=malloc(strlen(argv[1]));
  *addr='\0';
  version=malloc(strlen(argv[1]));
  *version='\0';
  parse_sip_path(argv[1], version, &transport, addr, &port, &ttl);
  switch(transport) {
  case SIP_NO_TRANSPORT: 
    strcpy(transport_str, "NONE");
    break;
  case SIP_UDP_TRANSPORT: 
    strcpy(transport_str, "UDP");
    break;
  case SIP_TCP_TRANSPORT: 
    strcpy(transport_str, "TCP");
    break;
  }
  sprintf(interp->result, 
	  "\"%s\" \"%s\" \"%s\" %d %d", 
	  version, transport_str, addr, port, ttl);
  free(addr);
  free(version);
  return TCL_OK;
}


int ui_sip_close_tcp_connection(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  return (sip_close_tcp_connection(argv[1]));
}

int ui_run_program(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  int i;
  int pid;
  pid=run_program(argv[1]);
  sprintf(interp->result, "%d", pid);
  return TCL_OK;
}
