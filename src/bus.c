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
#include "prototypes.h"

extern int busrxsock;
extern char username[];
extern unsigned long hostaddr;
extern Tcl_Interp *interp;
extern int ui_visible;
#define BUS_ADDR "224.1.127.255"
#define BUS_PORT 9859
int bus_recv()
{
  int length;
  static char buf[MAXADSIZE];
  struct sockaddr_in from;
  int fromlen=sizeof(struct sockaddr);
  if ((length = recvfrom(busrxsock, (char *) buf, MAXADSIZE, 0,
                       (struct sockaddr *)&from, (int *)&fromlen)) < 0) {
      perror("bus recv error");
      return 0;
  }
  if (length==MAXADSIZE) {
      /*some sneaky bugger is trying to splat the stack?*/
      fprintf(stderr, "Warning: 2K local conf bus message truncated\n");
  }
/*  printf("BUS message received (len=%d)\n%s\n", length, buf);*/
  if (is_a_bus_message(buf))
    {
      parse_bus_message(buf, length);
    }
  return(0);
}

int bus_send(char *msg, int len)
{
#ifndef WIN32
  /*we do this so rarely that it's worth setting up the socket on demand
   and cleaning up afterwards*/
  unsigned char ttl=0;
  int bustxsock;
  struct sockaddr_in sin;
  sin.sin_addr.s_addr=inet_addr(BUS_ADDR);
  sin.sin_port=htons(BUS_PORT);
  sin.sin_family=AF_INET;
  bustxsock=socket( AF_INET, SOCK_DGRAM, 0 );
  if (connect(bustxsock, (struct sockaddr *)&sin, 
	      sizeof(struct sockaddr_in))<0)
    {
      perror("connect");
      fprintf(stderr, "Dest Address problem\n");
      close(bustxsock);
      return(-1);
    }
  
  if (setsockopt(bustxsock, IPPROTO_IP, IP_MULTICAST_TTL, (char *)&ttl,
		 sizeof(ttl))<0)
    {
      perror("setsockopt ttl");
      fprintf(stderr, "ttl: %d\n", ttl);
      close(bustxsock);
      return(-1);
    }
  if (send(bustxsock, msg, len, 0)==-1)
    {
      perror("bus send");
      close(bustxsock);
      return(errno);
    }
  close(bustxsock);
#endif
  return(0);
}

int bus_listen() 
{    
#ifdef WIN32
  int sock = -1;
#else
  int sock;
  sock=sip_udp_listen(BUS_ADDR, BUS_PORT);
#endif
  return(sock);
}

int is_a_bus_message(char *buf)
{
  return(strncmp(buf, "LCB/1.0", 7)==0);
}

void parse_bus_message(char *buf, int len)
{
  char *line;
  pid_t hispid, mypid;
  buf[len]='\0';
/*  printf("bus message:\n%s\n", buf);*/
  line=strchr(buf,'\n');
  line++;
  if (strncmp(line, "sdr ", 4)!=0)
    {
      /*it's not for me*/
      return;
    }
  line+=4;
  if (strncmp(line, "instance ", 9)==0)
    {
      line=strchr(line, ' ');
      line++;
      hispid=atoi(line);
      mypid=getpid();
      if (hispid==mypid)
	{
	  /*it's a message I sent!*/
	  return;
	}
      line=strchr(line, ' ');
      line++;
      if (strncmp(line, username, strlen(username))==0)
	{
	  char addrstr[16];
	  struct in_addr in;
	  in.s_addr=hostaddr;
	  strcpy(addrstr, inet_ntoa(in));
	  line=strchr(line, ' ');
	  line++;
	  if(strncmp(line, addrstr, strlen(addrstr))==0)
	    {
	      /*yes, my user is really trying to run two instances*/
	      line=strchr(line, ' ');
	      line++;
	      /*line should now hold the display*/
	      if (ui_visible==TRUE)
		{
		  /*not sure what we should do here*/
		  fprintf(stderr, "interface visible\n");
		  return;
		}
	      else
		{
		  fprintf(stderr, "OK, mapping i/f\n");
		  Tcl_SetVar2(interp, "env", "DISPLAY", line, TCL_GLOBAL_ONLY);
		  rebuild_interface();
		}
	    }
	  else
	    {
	      /*this shouldn't happen*/
	      fprintf(stderr, "TTL problem on LCB: message ignored\n");
	    }
	}
      else
	{
	  /*don't care about instances run by someone else*/
	  fprintf(stderr, "someone else\n");
	  return;
	}
    }
  else
    {
      fprintf(stderr, "Unknown LCB message type received\n");
      return;
    }
}

int bus_send_new_app()
{
  char *display;
  char msg[256];
  pid_t pid;
  struct in_addr in;
  display=getenv("DISPLAY");
  pid=getpid();
  in.s_addr=hostaddr;
  sprintf(msg, "LCB/1.0\nsdr instance %u %s %s %s",
	  (unsigned int)pid, username, inet_ntoa(in),
	  display ? display : "(none)");
/*  printf("%s\n", msg);*/
  return(bus_send(msg, strlen(msg)));
}
