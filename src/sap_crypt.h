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
int write_crypted_file(char *filename, char *data, int len, char *key);
int load_crypted_file(char *filename, char *buf, char *key);

