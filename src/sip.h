#ifndef SIP_MODULE
#define SIP_MODULE
#endif

#define MAX_CONNECTIONS 100

#define SIP_NO_TRANSPORT 0
#define SIP_UDP_TRANSPORT 1
#define SIP_TCP_TRANSPORT 2

#ifndef INADDR_NONE
#define INADDR_NONE     0xffffffff
#endif

#define BLOCKSIZE 100000
#define READSIZE 1024

typedef struct connection_s {
  int fd;
  int used;
  char *buf;
  int bufsize;
  int len;
  char *addr;
  char *callid;
} connection;

