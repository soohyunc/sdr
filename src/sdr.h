#include <stdio.h>


#include <stdlib.h>
#include <sys/types.h>
#ifdef WIN32
#define TclGetTime TclpGetTime
#include <winsock.h>
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

#ifdef SYSV
#include <unistd.h>
#endif


#define MAXFILENAMELEN	256
#define MAXKEYLEN 256
#define MAXALIAS 80

#define GUI 1
#define NO_GUI 0



#ifdef WIN32

#define close closesocket

#define MAXHOSTNAMELEN	256

#define _SYS_NMLN	9
struct utsname {
	char sysname[_SYS_NMLN];
	char nodename[_SYS_NMLN];
	char release[_SYS_NMLN];
	char version[_SYS_NMLN];
	char machine[_SYS_NMLN];
};

typedef char *caddr_t;

struct iovec {
	caddr_t iov_base;
	int	    iov_len;
};

struct timezone {
	int tz_minuteswest;
	int tz_dsttime;
};

typedef int pid_t;
typedef int uid_t;
typedef int gid_t;

/*
 * Message header for recvmsg and sendmsg calls.
 */
struct msghdr {
        caddr_t msg_name;               /* optional address */
        int     msg_namelen;            /* size of address */
        struct  iovec *msg_iov;         /* scatter/gather array */
        int     msg_iovlen;             /* # elements in msg_iov */
        caddr_t msg_accrights;          /* access rights sent/received */
        int     msg_accrightslen;
};
    
int uname(struct utsname *);
int getopt(int, char * const *, const char *);
int strcasecmp(const char *, const char *);
void srandom(unsigned int);
long random(void);
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

#define srand48 srand
#define lrand48 rand

#endif /* WIN32 */

#ifdef SUNOS4
char *strerror(int i);
#endif

#define SAP_GROUP        "224.2.127.254"
#define SAP_PORT         9875
#ifdef LISTEN_FOR_SD
#define OLD_SAP_GROUP	"224.2.127.255"
#define	OLD_SAP_PORT	9876
#endif
#define SIP_GROUP        "224.0.1.75"
#define SIP_PORT        5060


#ifdef TRUE
#undef TRUE
#undef FALSE
#endif
#define TRUE (1)
#define FALSE (0)
#define INTERVAL 300000
#define MAXADSIZE 2048
#ifdef AUTH
/*#define AUTHDEB(a) a*/
#define AUTHDEB(a)
#else
#define AUTHDEB(a)
#endif
 
#ifdef AUTH
#define SAUTHDEB(a) a
/*#define SAUTHDEB(a)*/
#else
#define SAUTHDEB(a)
#endif
#ifdef AUTH
#define MAXSIGSIZE        152
#define MAXKEYSIZE        1024
#define MAXENCSIZE        2048
#define MAXDECSIZE        8192
#define authPGP  1
#define authX509  2
#define authPGPC 3
#define authX509C 4
#endif


/*Missing Prototypes*/
long lrand48();
void srand48(long seedval);
double drand48();

#if !defined(WIN32)&&!defined(SGI)&&!defined(AIX41)&&!defined(_HPUX_SOURCE) && !defined(SOLARIS) && !defined(FREEBSD)
int gethostname(char * name, size_t namelen);
#endif

struct advert_data {
  unsigned int interval;
  unsigned long end_time;
  char *aid;
  char *data;
  int tx_sock;
#ifdef AUTH
  struct auth_header *sapauth_p;
  struct sap_header *sap_p;
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
  u_int type:3;
  u_int version:3;
#else
  u_int version:3;
  u_int type:3;
  u_int enc:1;
  u_int compress:1;
#endif
  u_int authlen:8;
  u_int msgid:16;
  u_int src;
};


#ifdef AUTH
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
  u_int autlen:8;
  u_int pad_len;
  u_int sig_len;
  u_int key_len;
  char *signature;
  char *keycertificate;
};
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
#endif

struct enc_header {
  u_int timeout;
};

#define   DES 0
#define  DES3 1
#define   PGP 2
#define PKCS7 3

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
