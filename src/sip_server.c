/*Copyright (c) 1997 University of Southern California*/

#include "sdr.h"
#include "prototypes.h"

#define DEBUG

int siprxsock;
int siptxsock;
Tcl_Interp *interp;


struct proxy_entry {
  char *username;
  char *redirect;
  int ttl;
  int proto;
  int action;
};

int sip_proxy_request(struct proxy_entry *dbe, char *buf);
int sip_relay_request(char *dst, int ttl, int proto, char *buf);
int sip_redirect_request(char *dst, int ttl, int proto, char *buf);
int sip_unauthorized_request(char *buf);
int extract_via_parts(char *via, char *addr, int *ttl, int *proto);
int extract_parts(char *buf, char *method, char *url, char *via, char *rest);
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
      if (dstname!=NULL)
	{
	  for(i=0;i<users;i++)
	    {
	      printf("comparing %s with %s\n", db[i]->username, dstname);
	      if (strcmp(db[i]->username, dstname)==0)
		{
		  sip_proxy_request(db[i], buf);
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


int sip_proxy_request(struct proxy_entry *dbe, char *buf)
{
  switch(dbe->action)
    {
    case RELAY: 
      {
	return(sip_relay_request(dbe->redirect, dbe->ttl, dbe->proto, buf));
	break;
      }
    case REDIRECT:
      {
	return(sip_redirect_request(dbe->redirect, dbe->ttl, dbe->proto, buf));
      }
    case UNAUTHORIZED: 
      {
	return(sip_unauthorized_request(buf));
      }
    }
  return -1;
}

int sip_relay_request(char *dst, int ttl, int proto, char *buf)
{
  char method[MAXMETHOD], url[MAXURL], via[MAXADSIZE], rest[MAXADSIZE];
  char tmp[MAXADSIZE], *dsthost;
#ifdef DEBUG
  printf("sip_relay_request %s %d %d\n", dst, ttl, proto);
#endif
  dsthost=strchr(dst, '@')+1;
  extract_parts(buf, method, url, via, rest);
  if (proto==UDP)
    {
      if (ttl>0)
	{
	  sprintf(tmp, "Via:SIP/2.0/UDP %s %d\r\n", dst, ttl); 
	  strcat(via, tmp);
	}
      sprintf(tmp, "Via:SIP/2.0/UDP %s\r\n", myaddress); 
      strcat(via, tmp);
      sprintf(tmp, "%s %s SIP/2.0\r\n%s%s", method, url, via, rest);
      sip_send_udp(dsthost, ttl, tmp);
    } 
  else if(proto==TCP)
    {
      sprintf(tmp, "Via:SIP/2.0/TCP %s\r\n", myaddress);
      strcat(via, tmp);
      sprintf(tmp, "%s %s SIP/2.0\r\n%s%s", method, url, via, rest);
      sip_send_tcp(dsthost, tmp);
    }
  else 
    {
      return -1;
    }
  return 0;
}

int sip_redirect_request(char *dst, int ttl, int proto, char *buf)
{
  char method[MAXMETHOD], url[MAXURL], via[MAXADSIZE], rest[MAXADSIZE];
  char tmp[MAXADSIZE], addr[MAXADDRLEN], reply[MAXADSIZE];
  int reply_ttl, reply_proto;
  extract_parts(buf, method, url, via, rest);
  if (extract_via_parts(via, addr, &reply_ttl, &reply_proto)<0)
    {
      fprintf(stderr, "Invalid Via field: %s", via);
      return -1;
    }
  /*remove the first via entry if it's multicast*/
  if (reply_ttl>0)
    strncpy(tmp, strchr(via,'\n')+1, MAXADSIZE-1);
  else
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
      sip_send_udp(addr, reply_ttl, reply);
    } 
  else if(reply_proto==TCP)
    {
	sprintf(reply, "SIP/2.0 302 Moved Temporarily\r\n\
%sLocation:sip:%s\r\n%s", 
		tmp, dst, rest);
      sip_send_tcp(addr, reply);
    }
  else 
    {
      return -1;
    }
  return 0;
}

int sip_unauthorized_request(char *buf)
{
  char method[MAXMETHOD], url[MAXURL], via[MAXADSIZE], rest[MAXADSIZE];
  char tmp[MAXADSIZE], addr[MAXADDRLEN], reply[MAXADSIZE];
  int reply_ttl, reply_proto;
  extract_parts(buf, method, url, via, rest);
  if (extract_via_parts(via, addr, &reply_ttl, &reply_proto)<0)
    {
      fprintf(stderr, "Invalid Via field: %s", via);
      return -1;
    }
  /*remove the first via entry if it's multicast*/
  if (reply_ttl>0)
    strncpy(tmp, strchr(via,'\n')+1, MAXADSIZE-1);
  else
    strncpy(tmp, via, MAXADSIZE-1);
  if (reply_proto==UDP)
    {
      sprintf(reply, "SIP/2.0 401 Unauthorized\r\n%s%s", tmp, 
	      rest);
      sip_send_udp(addr, reply_ttl, reply);
    } 
  else if(reply_proto==TCP)
    {
      sprintf(reply, "SIP/2.0 401 Unauthorized\r\n%s%s", tmp, 
	      rest);
      sip_send_tcp(addr, reply);
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

int extract_parts(char *buf, char *method, char *url, char *via, char *rest)
{
  int i=0,j=0;
  /*copy the method into "method:*/
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
  while (strncmp(&buf[i], "Via:", 4)==0)
    {
      while(buf[i]!='\n')
	{
	  via[j++]=buf[i++];
	}
      via[j++]=buf[i++];
    }
  via[j]='\0';

  /*copy the rest into "rest"*/
  strncpy(rest, &buf[i], MAXADSIZE-1);
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

  parse_server_config("sip.conf");
  
  siprxsock=sip_listen(SIP_GROUP, SIP_PORT);
  while(1)
    {
      FD_ZERO(&readfds);
      FD_SET(siprxsock, &readfds);
      select(siprxsock+1, &readfds, NULL, NULL, NULL);
      if (FD_ISSET(siprxsock, &readfds)!=0)
	{
	  sip_recv_udp();
	}
    }
}

