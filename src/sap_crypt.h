struct keydata {
  char key[MAXKEYLEN];
  char keyname[MAXKEYLEN];
  u_int keyversion;
  u_int starttime;
  u_int endtime;
  struct keydata *prev;
  struct keydata *next;
};

struct keyfile {
  char key[MAXKEYLEN];
  char keyname[MAXKEYLEN];
  u_int keyversion;
  u_int starttime;
  u_int endtime;
};

int save_keys(void);
int load_keys(void);
#ifndef AUTH
int write_crypted_file(char *filename, char *data, int len, char *key);
#else
int find_keyname_by_key(char *key, char *keyname);
#endif
int load_crypted_file(char *filename, char *buf, char *key);

/* for random.c */

void lblsrandom(unsigned int seed);
long lblrandom(void);

int sec_randomkey(char *key, int *seed);
int sec_seed(void);
long sec_longrand(void);
 
#define    OK 0
#define NOTOK (-1)

/* for sap_crypt.c kbase64routines */

int ToBase64( u_char **inbp, int *ilen, char *outbuf, int olen);
int bin_to_b64_aux(u_char *in,int inlen,char **cpp);


