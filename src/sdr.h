#include "config_win32.h"
#include "config_unix.h"
#include "tcl.h"
#include "tk.h"

#ifdef WIN32
#define TclGetTime TclpGetTime
#include "sys/stat.h"
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <netdb.h>
#include <pwd.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <ctype.h>
#include <arpa/nameser.h>
#include <resolv.h>
#ifdef AIX41
#include <sys/select.h>
#endif
#endif
#include <tcl.h>
#include <tk.h>
#ifndef FREEBSD
#include <malloc.h>
#endif
#include <string.h>
#include <fcntl.h>
#include <errno.h>

#ifdef FREEBSD
#include <sys/uio.h>
#endif

#if defined(SYSV) || defined(__linux__)
#include <unistd.h>
#endif


#define MAXFILENAMELEN	256
#define MAXKEYLEN 256
#define MAXALIAS 80
#define MAXMEDIA 10
#define MAXPHONE 10
#define MAXBW 10
#define MAXKEY 10
#define MAXTIMES 10
#define MAXRPTS 10
#define MAXVARS 20
#define MAX_SOCKS 20
#define TMPSTRLEN 1024

#define AIDLEN 20
#define TMPKEYIDLEN 8
#define ASYMKEYIDLEN 9
#define AUTHTYPELEN 6
#define ENCTYPELEN 6
#define AUTHSTATUSLEN 18
#define ENCSTATUSLEN 18
#define AUTHMESSAGELEN 800
#define ENCMESSAGELEN 800
#define NRANDSTRLEN 10
#define TRUSTLEN 20

#define GUI 1
#define NO_GUI 0



#ifdef WIN32

#define close closesocket

#define MAXHOSTNAMELEN	256

typedef char *caddr_t;


typedef int pid_t;
typedef int uid_t;
typedef int gid_t;

int uname(struct utsname *);
int getopt(int, char * const *, const char *);
int strcasecmp(const char *, const char *);
void lblsrandom(unsigned int);
long lblrandom(void);
int gettimeofday(struct timeval *p, struct timezone *z);
int gethostid(void);
int getuid(void);
int getgid(void);
int getpid(void);
int nice(int);
int sendmsg(int, struct msghdr*, int);
time_t time(time_t *);

#define ECONNREFUSED	WSAECONNREFUSED
#define ENETUNREACH	WSAENETUNREACH
#define EHOSTUNREACH	WSAEHOSTUNREACH
#define EWOULDBLOCK	WSAEWOULDBLOCK

#define M_PI		3.14159265358979323846

/*
#define srand48 srand
#define lrand48 rand
*/

#endif /* WIN32 */

#ifdef SUNOS4
char *strerror(int i);
#endif

#define IPv4 4
#define IPV4_ADDR_LEN 4
#define IPv6 6
#ifdef HAVE_IPv6
#include "ipv6_macros.h"
#endif


#define SAP_GROUP        "224.2.127.254"
#define SAP_PORT         9875

#define SAPv6_DEFAULT_MASK 13
#define SAPv6_GROUP        "ff0e:0:0:0:0:0:2:7ffe"
#define SAPv6_DEFAULT      "ff0e::2:8000"

#define SIP_GROUP        "224.0.1.75"
#define SIP_PORT         5060
#define SIPv6_GROUP      "ff0e:0:0:0:0:0:0:014b"



#ifdef TRUE
#undef TRUE
#undef FALSE
#endif
#define TRUE (1)
#define FALSE (0)
#define INTERVAL 200000
#define MAXADSIZE 2048

#ifndef WIN32
/* to debug uncomment the following line */
/*#define writelog(a) a*/
#define writelog(a)
#else
#define writelog(a)
#endif
 
#define TIMEOUT           4
#define MAXSIGSIZE        152
#define MAXKEYSIZE        1024
#define MAXENCSIZE        2048
#define MAXDECSIZE        8192

#define authPGP   1
#define authX509  2
#define authPGPC  3
#define authX509C 4

#define   DES 0
#define  DES3 1
#define   PGP 2
#define PKCS7 3

/*Missing Prototypes*/

#if !defined(WIN32)&&!defined(SGI)&&!defined(AIX41)&&!defined(_HPUX_SOURCE) && !defined(SOLARIS) && !defined(FREEBSD)
int gethostname(char * name, size_t namelen);
#endif

struct advert_data {
  unsigned int interval;
  unsigned long end_time;
  char *aid;
  char *data;
  int tx_sock;
  int addr_fam;
#ifdef AUTH
  struct auth_info *authinfo;
  struct sap_header *sap_hdr;
  struct priv_header *sapenc_p;
#endif
  unsigned char ttl;
  unsigned int padding;
  unsigned int length;
  int encrypt;
  struct advert_data *next_ad;
  struct advert_data *prev_ad;
  Tk_TimerToken timer_token;
};
  
struct sap_header {
#ifdef DIFF_BYTE_ORDER
  u_int compress:1;
  u_int enc:1;
  u_int type:1;
  u_int resv:1;
  u_int addr:1;
  u_int version:3;
#else
  u_int version:3;
  u_int addr:1;
  u_int resv:1;
  u_int type:1;
  u_int enc:1;
  u_int compress:1;
#endif
  u_int authlen:8;
  u_int msgid:16;
/* MM -make protocol independent, see new sap_header def's below */
/*  u_int src; */
};

/* These repitious sap headers are UGLY... */
struct sapv4_header {
#ifdef DIFF_BYTE_ORDER
  u_int compress:1;
  u_int enc:1;
  u_int type:1;
  u_int resv:1;
  u_int addr:1;
  u_int version:3;
#else
  u_int version:3;
  u_int addr:1;
  u_int resv:1;
  u_int type:1;
  u_int enc:1;
  u_int compress:1;
#endif
  u_int authlen:8;
  u_int msgid:16;
  u_int src; 
};

struct sapv6_header {
#ifdef DIFF_BYTE_ORDER
  u_int compress:1;
  u_int enc:1;
  u_int type:1;
  u_int resv:1;
  u_int addr:1;
  u_int version:3;
#else
  u_int version:3;
  u_int addr:1;
  u_int resv:1;
  u_int type:1;
  u_int enc:1;
  u_int compress:1;
#endif
  u_int authlen:8;
  u_int msgid:16;
  unsigned char src[16];
};


#define SAPV6_HDR_LEN sizeof(struct sapv6_header)
#define SAPV4_HDR_LEN sizeof(struct sapv4_header)

/*we use this to store info about authentication*/
struct auth_info {
  u_int auth_type;
  u_int padding;
  u_int version;
  u_int siglen;
  u_int autlen;
  u_int pad_len;
  u_int sig_len;
  u_int key_len;
  char *signature;
};

/*this is the actual header that goes in the packets*/
struct auth_header {
#ifdef DIFF_BYTE_ORDER
  u_int auth_type:4;
  u_int padding:1;
  u_int version:3;
#else
  u_int version:3;
  u_int padding:1;
  u_int auth_type:4;
#endif
  u_int siglen:8;
};
/*beware sizeof(struct auth_header) doesn't return 2!!!*/
#define AUTH_HEADER_LEN 2
#define ENC_HEADER_LEN  2

struct priv_header {
#ifdef DIFF_BYTE_ORDER
  u_int enc_type:4;
  u_int padding:1;
  u_int version:3;
#else
  u_int version:3;
  u_int padding:1;
  u_int enc_type:4;
#endif
  u_int hdr_len:8;
  u_int pad_len;
  u_int txt_len;
  u_int encd_len;
 char  *enc_data;
 char  *txt_data;
};

struct enc_header {
  u_int timeout;
};

typedef unsigned int hash_t;

#define LSDAP_CHECK_BYTE 235
#define LSDAP_ADVERT 1
#define LSDAP_HASHLIST 2
#define LSDAP_HASHREQ 3

struct lsdap_header 
{
  u_char check;
  u_char type;
  char payload[1];
};

struct lsdap_advert 
{
  u_char check;
  u_char type;
  u_char origin;
  u_char ttl;
  hash_t  hash;
  char addata[1];
};

struct lsdap_hashlist
{
  u_char check;
  u_char type;
  u_char seq;
  u_char padding2;
  hash_t hashlist[1];
};

struct lsdap_hashreq
{
  u_char check;
  u_char type;
  u_char padding1;
  u_char padding2;
  hash_t  hash;
};

#ifdef WIN32
/* get rid of some Microsoft brain-damage */
#ifdef interface
#undef interface
#endif
#endif
