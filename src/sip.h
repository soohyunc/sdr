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

#define METHOD_UNKNOWN 0
#define INVITE 1
#define OPTIONS 2
#define REGISTER 3
#define ACK 4
#define CANCEL 5
#define BYE 6

typedef struct connection_s {
  int fd;
  int used;
  char *buf;
  int bufsize;
  int len;
  char *addr;
  char *host;
  char *callid;
  int port;
} connection;


/* Funtions in sip.c */
int sip_close_tcp_connection(char *callid);

/* Funtions in sip_common.c */
int sip_send_tcp_reply_to_fd(int fd, char *msg);


/* maryann's debug define, see mdebug.h */
#define MDEBUG_FLAG 0x0 
/*#define MDEBUG_FLAG 0x3 /* combination SIP and REG (sip register) levels */




