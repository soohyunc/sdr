/*Copyright (c) 1997 University of Southern California*/

#include "sdr.h"
#include "sip.h"
#include "prototypes.h"

#define DEBUG

int sip_udp_rx_sock;
int sip_tcp_rx_sock;
int sip_udp_tx_sock;
connection sip_tcp_conns[MAX_CONNECTIONS];
Tcl_Interp *interp;


struct proxy_entry {
  char *username;
  char *redirect;
  int ttl;
  int proto;
  int action;
};

int sip_proxy_request(struct proxy_entry *dbe, 
		      int fd, int request_proto, char *buf);
int sip_relay_request(char *dst, int ttl, int proto,  
		      int fd, int request_proto, char *buf);
int sip_redirect_request(char *dst, int ttl, int proto,  
			 int fd, int request_proto, char *buf);
int sip_register_request(int fd, int request_proto, char *buf);
int sip_unauthorized_request(int fd, int request_proto, char *buf);
int extract_via_parts(char *via, char *addr, int *ttl, int *proto);
int is_multicast(char *addr);


#define RELAY 0
#define REDIRECT 1
#define UNAUTHORIZED 2
#define NOTFOUND 2

#define UDP 0
#define TCP 1

#define MAXUSERNAME 80
#define MAXUSERS 100
#define MAXMETHOD 20
#define MAXURL 256
#define MAXADDRLEN 80
#define MAXCONFLINE 256
#define MAX_FD 255

struct proxy_entry *db[MAXUSERS];
int users=0;
char myaddress[MAXADDRLEN];
char hostname[MAXADDRLEN];
int hostaddr;


int sip_recv_udp()
{
  int length, i;
  char *dstname;
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
      if (dstname!=NULL)
	{
	  for(i=0;i<users;i++)
	    {
	      printf("comparing %s with %s\n", db[i]->username, dstname);
	      if (strcmp(db[i]->username, dstname)==0)
		{
		  sip_proxy_request(db[i], UDP, 0, buf);
		  break;
		}
	    }
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


/*By the time we call sip_recv_tcp there should be at least one
  complete request in the receive buffer.  There might be more than
  one request...*/

int sip_recv_tcp(char *buf, int length, int sipfd, char *pktsrc)
{
  int i;
  char *dstname, *method;

  /*XXXX if we got more than one request, this won't work*/
  buf[length]='\0';

#ifdef DEBUG
  printf("SIP message received (len=%d)\n%s\n", length, buf);
#endif
  if (is_a_sip_request(buf))
    {
#ifdef DEBUG
      printf("It's a request\n");
#endif
      method=sip_get_method(buf);
      if ((strcmp(method, "INVITE")==0)||(strcmp(method, "OPTIONS")==0)) {
	dstname=sip_get_dstname(buf);
	if (dstname!=NULL) {
	  for(i=0;i<users;i++) {
	    printf("comparing %s with %s\n", db[i]->username, dstname);
	    if (strcmp(db[i]->username, dstname)==0) {
	      sip_proxy_request(db[i], TCP, sipfd, buf);
	      break;
	    }
	  }
        }
      } else if (strcmp(method, "REGISTER")==0) {
	sip_register_request(sipfd, TCP, buf);
      } else if (strcmp(method, "ACK")==0) {
	printf("got an ACK - don't handle this yet\n");
      } else if (strcmp(method, "BYE")==0) {
	printf("got an BYE - don't handle this yet\n");
      } else if (strcmp(method, "CANCEL")==0) {
	printf("got an CANCEL - don't handle this yet\n");
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


int sip_proxy_request(struct proxy_entry *dbe, int fd, int request_proto,
		      char *buf)
{
  switch(dbe->action)
    {
    case RELAY: 
      {
	return(sip_relay_request(dbe->redirect, dbe->ttl, dbe->proto, 
				 fd, request_proto, buf));
	break;
      }
    case REDIRECT:
      {
	return(sip_redirect_request(dbe->redirect, dbe->ttl, dbe->proto, 
				    fd, request_proto, buf));
      }
    case UNAUTHORIZED: 
      {
	return(sip_unauthorized_request(fd, request_proto, buf));
      }
    }
  return -1;
}

int sip_relay_request(char *dst, int ttl, int proto, int fd, 
		      int request_proto, char *buf)
{
  char method[MAXMETHOD], url[MAXURL], via[MAXADSIZE], rest[MAXADSIZE];
  char tmp[MAXADSIZE], dsturl[MAXADSIZE];
#ifdef DEBUG
  printf("sip_relay_request %s %d %d\n", dst, ttl, proto);
#endif
  strcpy(dsturl, "sip:");
  strcat(dsturl, dst);
  if (ttl>0) {
    sprintf(dsturl+strlen(dsturl), ";ttl=%d;maddr=%s", ttl, 
	    strchr(dst, '@')+1);
  }
  extract_parts(buf, method, url, via, rest);
  if (proto==UDP) {
    if (ttl>0) {
      sprintf(tmp, "Via:SIP/2.0/UDP %s %d\r\n", dst, ttl); 
      strcat(via, tmp);
    }
    sprintf(tmp, "Via:SIP/2.0/UDP %s\r\n", myaddress); 
    strcat(via, tmp);
    sprintf(tmp, "%s %s SIP/2.0\r\n%s%s", method, url, via, rest);
    sip_send_udp(dsturl, tmp);
  } else if(proto==TCP) {
    sprintf(tmp, "Via:SIP/2.0/TCP %s\r\n", myaddress);
    strcat(via, tmp);
    sprintf(tmp, "%s %s SIP/2.0\r\n%s%s", method, url, via, rest);
    sip_send_tcp_request(dsturl, tmp);
  } else {
    return -1;
  }
  return 0;
}

int sip_redirect_request(char *dst, int ttl, int proto, int fd, 
			 int request_proto, char *buf)
{
  char method[MAXMETHOD], url[MAXURL], via[MAXADSIZE], rest[MAXADSIZE];
  char tmp[MAXADSIZE], addr[MAXADDRLEN], reply[MAXADSIZE];
  char replyurl[MAXADDRLEN];
  int reply_ttl, reply_proto;
  extract_parts(buf, method, url, via, rest);
  if (extract_via_parts(via, addr, &reply_ttl, &reply_proto)<0)
    {
      fprintf(stderr, "Invalid Via field: %s", via);
      return -1;
    }
  sprintf(replyurl, "sip:null@%s", addr);
  /*remove the first via entry if it's multicast*/
  if (reply_ttl>0) {
    strncpy(tmp, strchr(via,'\n')+1, MAXADSIZE-1);
    sprintf(replyurl+strlen(replyurl), ";ttl=%d;maddr=%s", ttl, addr);
  } else
    strncpy(tmp, via, MAXADSIZE-1);
  if (reply_proto==UDP)
    {
      if (reply_ttl>0)
	sprintf(reply, "SIP/2.0 302 Moved Temporarily\r\n\
%sLocation:sip:%s;ttl=%d\r\n%s", 
		tmp, dst, ttl, rest);
      else
	sprintf(reply, "SIP/2.0 302 Moved Temporarily\r\n\
%sLocation:sip:%s\r\n%s", 
		tmp, dst, rest);
      sip_send_udp(replyurl, reply);
    } 
  else if(reply_proto==TCP)
    {
	sprintf(reply, "SIP/2.0 302 Moved Temporarily\r\n\
%sLocation:sip:%s\r\n%s", 
		tmp, dst, rest);
      sip_send_tcp_reply_to_fd(fd, reply);
    }
  else 
    {
      return -1;
    }
  return 0;
}

int sip_register_request(int fd, 
			 int request_proto, char *buf)
{
  
  /*XXX need to process the request*/
  char method[MAXMETHOD], url[MAXURL], via[MAXADSIZE], rest[MAXADSIZE];
  char tmp[MAXADSIZE], addr[MAXADDRLEN], reply[MAXADSIZE], location[MAXADSIZE];
  char to[MAXADSIZE], from[MAXADSIZE], replyurl[MAXADSIZE];
  int reply_ttl, reply_proto;

  printf("sip_register_request\n");
  extract_parts(buf, method, url, via, rest);
  extract_field(buf, location, MAXADSIZE, "location");
  extract_field(buf, to, MAXADSIZE, "to");
  extract_field(buf, from, MAXADSIZE, "from");
  if (extract_via_parts(via, addr, &reply_ttl, &reply_proto)<0)
    {
      fprintf(stderr, "Invalid Via field: %s", via);
      return -1;
    }
  sprintf(replyurl, "sip:null@%s", addr);
  /*remove the first via entry if it's multicast*/
  if (reply_ttl>0) {
    strncpy(tmp, strchr(via,'\n')+1, MAXADSIZE-1);
    sprintf(replyurl+strlen(replyurl), ";ttl=%d;maddr=%s", reply_ttl, addr);
  } else
    strncpy(tmp, via, MAXADSIZE-1);
  if (request_proto==UDP)
    {
      /*XXX multicast case incorrect*/
      if (reply_ttl>0)
	sprintf(reply, "SIP/2.0 200 Registered\r\n\
%sTo:%s\r\nFrom:%s\r\nLocation:%s\r\nContent-length:0\r\n\r\n", 
		tmp, to, from, location);
      else
	sprintf(reply, "SIP/2.0 200 Registered\r\n\
%sTo:%s\r\nFrom:%s\r\nLocation:%s\r\nContent-length:0\r\n\r\n", 
		tmp, to, from, location);
      sip_send_udp(replyurl, reply);
    } 
  else if(request_proto==TCP)
    {
	sprintf(reply, "SIP/2.0 200 Registered\r\n\
%sTo:%s\r\nFrom:%s\r\nLocation:%s\r\nContent-length:0\r\n\r\n", 
		tmp, to, from, location);
      printf("Response: %s\n", reply);
      sip_send_tcp_reply_to_fd(fd, reply);
    }
  else 
    {
      printf("unknown protocol %d\n", request_proto);
      return -1;
    }
  return 0;
}

int sip_unauthorized_request(int fd, int request_proto, char *buf)
{
  char method[MAXMETHOD], url[MAXURL], via[MAXADSIZE], rest[MAXADSIZE];
  char tmp[MAXADSIZE], addr[MAXADDRLEN], reply[MAXADSIZE], replyurl[MAXADSIZE];
  int reply_ttl, reply_proto;
  extract_parts(buf, method, url, via, rest);
  if (extract_via_parts(via, addr, &reply_ttl, &reply_proto)<0)
    {
      fprintf(stderr, "Invalid Via field: %s", via);
      return -1;
    }
  sprintf(replyurl, "sip:null@%s", addr);
  /*remove the first via entry if it's multicast*/
  if (reply_ttl>0) {
    strncpy(tmp, strchr(via,'\n')+1, MAXADSIZE-1);
    sprintf(replyurl+strlen(replyurl), ";ttl=%d;maddr=%s", reply_ttl, addr);
  } else
    strncpy(tmp, via, MAXADSIZE-1);
  if (reply_proto==UDP)
    {
      sprintf(reply, "SIP/2.0 401 Unauthorized\r\n%s%s", tmp, 
	      rest);
      sip_send_udp(replyurl, reply);
    } 
  else if(reply_proto==TCP)
    {
      sprintf(reply, "SIP/2.0 401 Unauthorized\r\n%s%s", tmp, 
	      rest);
      sip_send_tcp_reply_to_fd(fd, reply);
    }
  else 
    {
      return -1;
    }
  return 0;
}

int extract_via_parts(char *via, char *addr, int *ttl, int *proto)
{
  int i,j;
  if (strncmp(via, "Via:", 4)!=0)
    return -1;

  /*skip any whitespace*/
  i=4;
  while(via[i]==' ')
    i++;
  
  if (strncmp(&via[i], "SIP/2.0/", 8)!=0)
    return -1;

  /*identify the protocol*/
  i+=8;
  if (strncmp(&via[i], "UDP", 3)==0)
    *proto=UDP;
  else if (strncmp(&via[i], "TCP", 3)==0)
    *proto=TCP;
  else
    return -1;

  i+=3;
  /*skip any whitespace*/
  while(via[i]==' ')
    i++;

  /*copy the address into "addr"*/
  j=0;
  while(via[i]!=' ')
    addr[j++]=via[i++];
  addr[j]='\0';

  if((*proto==UDP)&&(is_multicast(addr)==0))
    {
      /*skip any whitespace*/
      while(via[i]==' ')
	i++;
      *ttl=atoi(&via[i]);
    }
  else
    {
      *ttl=0;
    }
#ifdef DEBUG
  printf("proto:%d ttl: %d addr:%s\n", *proto, *ttl, addr);
#endif
  return 0;
}
  
int is_multicast(char *addr)
{
  /*return 0 is this is a multicast address, -1 otherwise*/
  char tmp[4];
  int byte;
  strncpy(tmp, addr,3);
  if (tmp[1]=='.') tmp[1]='\0';
  else if (tmp[2]=='.') tmp[2]='\0';
  byte=atoi(tmp);
  if((byte<224)||(byte>239))
    return -1;
  else
    return 0;
}

int parse_sip_success(char *msg, char *addr)
{
  return 0;
}

int parse_sip_fail(char *msg, char *addr)
{
  return 0;
}

int parse_sip_progress(char *msg, char *addr)
{
  char *rtype;
  rtype=msg+8;
#ifdef DEBUG
  printf("parse_sip_progress\n");
#endif
  if (strncmp(rtype, "180 ", 4)==0)
    parse_sip_ringing(msg, addr);
  else if (strncmp(rtype, "100 ", 4)==0)
    parse_sip_trying(msg, addr);
  return 0;
}

int parse_sip_redirect(char *msg, char *addr)
{
  return 0;
}

int parse_sip_ringing(char *msg, char *addr)
{
  return 0;
}

int parse_sip_trying(char *msg, char *addr)
{
  return 0;
}

void trim_nl(char *str)
{
  if (str[strlen(str)-1]=='\n')
    str[strlen(str)-1]='\0';
  if (str[strlen(str)-1]=='\r')
    str[strlen(str)-1]='\0';
  
}

int parse_server_config(char *filename)
{
  int entry=-1;
  FILE *file;
  char line[MAXCONFLINE];
  file=fopen(filename, "r");
  if (file==NULL) {
    fprintf(stderr, "Can't find config file %s\n", filename);
    exit(1);
  }
  while(feof(file)==0)
    {
      fgets(line, MAXCONFLINE, file);
      trim_nl(line);
      if (strncmp("user:", line, 5)==0)
	{
	  entry++;
	  if (entry>=MAXUSERS)
	    {
	      fprintf(stderr, "Too many config file entries\n");
	      exit(1);
	    }
	  db[entry]=malloc(sizeof(struct proxy_entry));
	  users++;
	  db[entry]->username=malloc(strlen(line)-4);
	  strcpy(db[entry]->username, &line[5]);
	}
      else if(entry==-1)
	{
	  fprintf(stderr, "Format error in config file\n");
	  exit(1);
	}
      else if (strncmp("redirect:", line, 9)==0)
	{
	  db[entry]->redirect=malloc(strlen(line)-8);
	  strcpy(db[entry]->redirect, &line[9]);
	}
      else if (strncmp("proto:", line, 6)==0)
	{
	  if (strncmp("udp", &line[6], 3)==0)
	    db[entry]->proto=UDP;
	  else if (strncmp("tcp", &line[6], 3)==0)
            db[entry]->proto=TCP;
	  else
	    fprintf(stderr, "Illegal protocol in config file\n");
	}
      else if (strncmp("ttl:", line, 4)==0)
	{
	  db[entry]->ttl=atoi(&line[4]);
	}
      else if (strncmp("action:", line, 7)==0)
	{
	  if (strncmp("relay", &line[7], 5)==0)
            db[entry]->action=RELAY;
	  else if (strncmp("redirect", &line[7], 8)==0)
            db[entry]->action=REDIRECT;
	  else if (strncmp("unauthorized", &line[7], 6)==0)
            db[entry]->action=UNAUTHORIZED;
	}
    }
  return 0;
}


int main(int argc, char **argv)
{
  fd_set readfds;
  struct hostent *hstent;
  struct in_addr in;
  int i, bytes;

  /*initialise TCP connection cache*/
  for(i=0;i<MAX_CONNECTIONS;i++)
  {
    sip_tcp_conns[i].fd=-1;
    sip_tcp_conns[i].used=0;
    sip_tcp_conns[i].len=0;
  }

  /*find our own address*/
  gethostname(hostname, MAXADDRLEN);
  if (hostname[0] == '\0') {
    fprintf(stderr, "gethostname failed!\n");
    exit(1);
  }
  hstent=(struct hostent*)gethostbyname(hostname);
  if (hstent == (struct hostent*) NULL) {
    fprintf(stderr, "gethostbyname failed (hostname='%s'!\n", hostname);
    exit(1);
  }
  memcpy((char *)&hostaddr, (char *)hstent->h_addr_list[0], hstent->h_length);
  in.s_addr=hostaddr;  
  strncpy(myaddress, inet_ntoa(in), MAXADDRLEN);

  /*parse_server_config("sip.conf");*/
  
  sip_udp_rx_sock=sip_udp_listen(SIP_GROUP, SIP_PORT);
  sip_tcp_rx_sock=sip_tcp_listen(SIP_PORT);
  if (sip_tcp_rx_sock<0) exit(1);
  while(1)
    {
      FD_ZERO(&readfds);
      FD_SET(sip_udp_rx_sock, &readfds);
      FD_SET(sip_tcp_rx_sock, &readfds);
      for(i=0;i<MAX_CONNECTIONS;i++)
      {
	if (sip_tcp_conns[i].used==1)
	  FD_SET(sip_tcp_conns[i].fd, &readfds);
      }
      select(MAX_FD, &readfds, NULL, NULL, NULL);
      if (FD_ISSET(sip_udp_rx_sock, &readfds)!=0)
      {
	/*Got a UDP request*/
	sip_recv_udp();
      }
      else if (FD_ISSET(sip_tcp_rx_sock, &readfds)!=0)
      {
	/*Got a new TCP request*/
	sip_tcp_accept(sip_tcp_conns);
      }
      else 
      {
	printf("new data\n");
	/*Got new data on an existing TCP connection*/
	for(i=0;i<MAX_CONNECTIONS;i++)
	{
	  if ((sip_tcp_conns[i].used==1)&&(FD_ISSET(sip_tcp_conns[i].fd, &readfds)))
	  {
	    printf("on connection %d\n", i);
	    if (sip_tcp_conns[i].bufsize<(1500+sip_tcp_conns[i].len))
	    {
	      /*need to allocate more buffer space before we read*/
	      sip_tcp_conns[i].buf=realloc(sip_tcp_conns[i].buf, 
				       6000+sip_tcp_conns[i].len);
	    }
	    bytes=read(sip_tcp_conns[i].fd, &(sip_tcp_conns[i].buf[sip_tcp_conns[i].len]),
		       1500);
	    printf("read %d bytes\n", bytes);
	    if (bytes==0)
	    {
	      fprintf(stderr, "connection aborted\n");
	      sip_tcp_free(&sip_tcp_conns[i]);
	      continue;
	    }
	    (sip_tcp_conns[i].len)+=bytes;
	    printf("length %d bytes\n", sip_tcp_conns[i].len);
	    if (sip_request_ready(sip_tcp_conns[i].buf, sip_tcp_conns[i].len)==1)
	    {
	      printf("sip request ready\n");
	      sip_recv_tcp(sip_tcp_conns[i].buf, sip_tcp_conns[i].len, 
			   sip_tcp_conns[i].fd, sip_tcp_conns[i].addr);
	    } else {
	      printf("sip request not yet ready\n");
	    }
	  }
	}
      }
    }
}

void sdr_update_ui() {
}
