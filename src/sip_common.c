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

int sip_send_udp(char *dst, int ttl, char *msg)
{
  struct sockaddr_in sin;
#ifdef DEBUG
  printf("sip_send_udp to %s\n", dst);
#endif
  sin.sin_addr.s_addr=inet_addr(dst);
  if (sin.sin_addr.s_addr==-1)
    sin.sin_addr=look_up_address(dst);
  if (sin.sin_addr.s_addr==0)
    {
      fprintf(stderr, "address lookup failed\n");
      return -1;
    }
#ifdef DEBUG
  printf("sip_send_udp to %s (%s)\n", inet_ntoa(sin.sin_addr), dst);
#endif
  sin.sin_port=htons(SIP_PORT);
  sin.sin_family=AF_INET;
  if (ttl>0)
    {
      fprintf(stderr, "sending SIP to multicast not yet implemented\n");
      return -1;
    }
  else
    {
      return(sip_send(msg, strlen(msg), &sin, 0));
    }
}

int sip_send_tcp(char *dst, char *msg)
{
  return -1;
}

int sip_send(char *msg, int len, struct sockaddr_in *dst, int ttl)
{
  /*note: I'd love to use sendto rather than this socket cache, but
    I need to keep the PCB around so I can detect a port unreachable
    coming back when there's no server.  Of course this doesn't work
    on all platforms...
  */
  static int no_of_socks=0;
  static long slist[MAXINVITES];
  static int sockets[MAXINVITES];
  int code=0;
  int freesock=-1, usedsock=-1, sock, i, one=1;
  if (no_of_socks==0)
    {
      for(i=0;i<MAXINVITES;i++)
	sockets[i]=-1;
      freesock=0;
    }
  else
    {
      for(i=0;i<MAXINVITES;i++)
	{
	  if((freesock==-1)&&(sockets[i]==-1))
	    freesock=i;
	  if((sockets[i]!=-1)&&(slist[i]==dst->sin_addr.s_addr))
	    {
	      usedsock=i;
	      break;
	    }
	}
    }
  if(usedsock!=-1)
    {
      sock=usedsock;
    }
  else
    {
/*      printf("new socket\n");*/
      sock=freesock;
      sockets[sock]=socket( AF_INET, SOCK_DGRAM, 0 );
      no_of_socks++;
      slist[sock]=dst->sin_addr.s_addr;
      if (sockets[sock]==-1)
	{
	  perror("couldn't get SIP socket");
	  return -1;
	}

#ifndef WIN32
      fcntl(sockets[sock], F_SETFD, 1);
#endif
#ifdef NOTDEF      
      name.sin_family = AF_INET;
      name.sin_addr.s_addr = htonl(group);
      name.sin_port = htons(port);
#endif
      if (connect(sockets[sock], (struct sockaddr *)dst, 
		  sizeof(struct sockaddr_in))<0)
	{
	  perror("connect");
	  fprintf(stderr, "Dest Address problem\n");
	  return(-1);
	}
      if (setsockopt(sockets[sock], SOL_SOCKET, SO_REUSEADDR,
		 (char *)&one, sizeof(one)) < 0)
	{
	  perror("SO_REUSEADDR");
	}
    }
#ifdef DEBUG
  printf("sip send\n");
#endif
  if (ttl>0)
    {
      if (setsockopt(sockets[sock], IPPROTO_IP, IP_MULTICAST_TTL, (char *)&ttl,
		     sizeof(ttl))<0)
	{
	  fprintf(stderr, "ttl: %d\n", ttl);
	  perror("setsockopt ttl");
	  return(-1);
	}
    }
  code=send(sockets[sock], msg, len, 0);
  if (code==-1)
    {
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
  for(i=0;i<strlen(hostname);i++)
    {
      if ((!isdigit(hostname[i]))&&(hostname[i]!='.'))
	{
	  dotted_decimal=0;
	  break;
	}
    }
  if (dotted_decimal==0)
    {
      hostaddr=gethostbyname(hostname);
      if(hostaddr!=NULL)
	{
	  memcpy((char *)&(addr.s_addr), hostaddr->h_addr_list[0], 4);
	}
      else
#ifndef WIN32
	{
	  char buf[200];
	  int ans[500];
	  int ctr;
	  char *tstr, *resstr;
	  struct dnshdr *dnsa;
	  int len;
	  addr.s_addr=0;
	  len=res_mkquery(QUERY, hostname, C_IN, T_MX, NULL, NULL, 
			  NULL, buf, 200);
	  if (len==-1) perror("res_mkquery");
	  len=res_send(buf, len, ans, 2000);
	  if (len==-1) perror("res_send");
	  ans[0]=htonl(ans[0]);
	  ans[1]=htonl(ans[1]);
	  ans[2]=htonl(ans[2]);
	  dnsa=(struct dnshdr*)&ans[0];
/*	  printf("id:%d, opcode:%d, rcode:%d, qdcount:%d, ancount:%d, nscount:%d, arcount:%d\n", dnsa->id, dnsa->opcode, dnsa->rcode, dnsa->qdcount, dnsa->ancount, dnsa->nscount, dnsa->arcount);*/

	  if(dnsa->rcode!=0) 
	    {
	      addr.s_addr=(unsigned long)0;
	      return(addr);
	    }

	  /*query*/
	  ctr=ans[sizeof(struct dnshdr)];
	  tstr=(char *)(&ans[sizeof(struct dnshdr)]);
	  for(i=0;i<dnsa->qdcount;i++)
	    {
	      ctr=tstr[0];
	      tstr++;
	      while(ctr!=0)
		{
		  int tmp;
		  memcpy(str, tstr, ctr);
		  str[ctr]='\0';
		  tmp=ctr;
		  ctr=tstr[ctr];
		  tstr+=(tmp+1);
		}
	      tstr+=4;
	    }

	  for(i=0;i<dnsa->ancount;i++)
	    {
	      /*domain part of answer*/
	      ctr=tstr[0];
	      tstr++;
	      if ((ctr&192)!=192) {
		while(ctr!=0)
		  {
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
	      while(ctr!=0)
		{
		  int tmp;
		  if((ctr&192)!=192)
		    {
		      memcpy(resstr, tstr, ctr);
		      resstr[ctr]='.';
		      resstr+=ctr+1;
/*		      printf("query:%s\n", str);*/
		      tmp=ctr;
		      ctr=tstr[ctr];
		      tstr+=(tmp+1);
		      if(ctr==0) *(resstr-1)='\0';
		    } else {
		      /*it's compressed*/
		        if(*tstr==0) tstr+=2;
			resstr+=dn_expand(ans, ans+len, tstr-1, resstr, 200-strlen(resstr));
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
    } 
  else
    {
      addr.s_addr=inet_addr(hostname);
    }
  return(addr);
}

char *sip_get_dstname(char *msg)
{
  char *line, *nl, *amp;
  static char username[80];
  line=strstr(msg, "To:");
  if (line==NULL) return NULL;
  line+=3;
  nl=strchr(line, '\n');
  amp=strchr(line, '@');
  if ((nl==NULL)||(amp==NULL)||(amp>nl))
    return NULL;
  strncpy(username, line, amp-line);
  return &username[0];
}

int is_a_sip_request(char *msg)
{
  return(strncmp(msg, "INVITE ", 7)==0);
}

int is_a_sip_reply(char *msg)
{
  return(strncmp(msg, "SIP/2.0 ", 8)==0);
}

int parse_sip_reply(char *msg)
{
  char rtype;
  rtype=msg[8];
#ifdef DEBUG
  printf("rtype: %c\n", rtype);
#endif
  if(rtype=='1')
    parse_sip_progress(msg);
  else if(rtype=='2')
    parse_sip_success(msg);
  else if(rtype=='3')
    parse_sip_redirect(msg);
  else if(rtype=='4')
    parse_sip_fail(msg);
  else if(rtype=='5')
    parse_sip_fail(msg);
  else if(rtype=='6')
    parse_sip_fail(msg);
  else
    fprintf(stderr, "Illegal SIP reply type\n");
  return 0;
}

int sip_listen(char *address, int port) 
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
               (char *)&one, sizeof(one)) < 0)
      {
	perror("SO_REUSEADDR");
      }
#ifdef SO_REUSEPORT
    if (setsockopt(rxsock, SOL_SOCKET, SO_REUSEPORT,
               (char *)&one, sizeof(one)) < 0)
      {
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

