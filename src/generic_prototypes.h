/*general stuff not needed on systems with prototypes for this stuff*/


#ifdef SUNOS4
int socket(int domain, int type, int protocol);
void  perror(char *s);
int getsockopt(int s, int level, int optname, char *optval,  int *optlen);
int setsockopt(int s, int level, int optname, char *optval, int optlen);
int bind(int s, const struct sockaddr *name, int namelen);
int connect(int s, struct sockaddr *name, int namelen);
int write(int fildes, const void *buf, size_t nbyte);
int select (int width, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);
int printf(const char *format, /* args */ ... );
int fprintf(FILE *strm, const char *format, ... );
int sscanf(const char *s, const char *format, ...);
size_t fread(void *ptr, size_t size, size_t nitems, FILE *stream);
size_t fwrite(const void *ptr, size_t size, size_t nitems,
          FILE *stream);
int fclose(FILE *stream);
int fflush(FILE *stream);
int unlink(char *path);
int send(int s, char *msg, int len, int flags);
int recvfrom(int s, char *buf, int len, int flags,
          struct sockaddr *from, int *fromlen);
size_t strftime(const char *s, size_t maxsize,
          const char *format, const struct tm *timeptr);
int close(int fildes);
uid_t getuid(void);
void bcopy(char *s1, char *s2, int len);
void bzero(char *str, int len);
int gettimeofday(struct timeval *tp, struct timezone *tzp);
#endif


#ifdef SOLARIS
/*int gettimeofday(struct timeval *tp);*/
#endif

/*yeuch - dont use these unless you really know why*/
#ifdef ALPHA
#define PTOI(p) (int)(long)p
#define ITOP(p) (void *)(long)p
#else
#define PTOI(p) (int)p
#define ITOP(p) (void *)p
#endif
