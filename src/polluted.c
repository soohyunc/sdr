#include "sdr.h"
#include "prototypes.h"
#include "prototypes_crypt.h"
#include "ui_fns.h"

int init_security();

extern Tcl_Interp *interp;

extern char hostname[];
extern char username[];
extern unsigned long hostaddr;
extern int rxsock[];
extern int no_of_rx_socks;
extern int doexit;

struct keydata* keylist;
char passphrase[MAXKEYLEN];
extern Tcl_Interp *interp;
extern unsigned long hostaddr;
extern int debug1;
extern int doexit;

int init_security()
{
  struct stat sbuf;
  char keyfilename[MAXFILENAMELEN];
  strcpy(passphrase, "");
  keylist=NULL;
  get_sdr_home(keyfilename);
#ifdef WIN32
  strcat(keyfilename, "\\sdr\\keys");
#else
  strcat(keyfilename, "/keys");
#endif
  if (stat(keyfilename, &sbuf)<0) return 0;
  if (sbuf.st_size>0) {
    announce_error(Tcl_GlobalEval(interp, "enter_passphrase"),
		   "enter_passphrase");
  }
  return 0;
}

int aux_load_file(char *buf, char *name, char *flag)
{
  FILE *cache;
  int len;

  if (strcmp(flag, "crypt") == 0) {
    if (strcmp(get_pass_phrase(), "")==0) {
      return TCL_OK;
    }
    len=load_crypted_file(name, buf, get_pass_phrase());
    buf[len]='\n';
    buf[len+1]='\0';
  } else {
    cache=fopen(name, "r");
    if (cache==NULL) return TCL_OK;
    len=fread(buf, 1, MAXADSIZE, cache);
    buf[len]='\0';
    fclose(cache);
  }
  return len;

}

int parse_announcement(int enc, char *data, int length, 
		       unsigned long src, unsigned long hfrom,
		       char *addr, int port, int sec)
{
  char recvkey[MAXKEYLEN]="";
  
  /*Decrypt the announcement, and skip the encryption fields*/
  if (enc==1) {
    /*note - encrypted data includes timeout*/
#ifdef DEBUG
    printf("received encrypted announcement...\n");
#endif
    if (decrypt_announcement(data, &length, recvkey)!=0) {
#ifdef DEBUG
      printf("      ... cannot decrypt announcement!\n");
#endif
      return 1;
    }
    /*data now has encryption fields removed*/
  } else {
    strcpy(recvkey, "");
  }

  /* if someone else is repeating our announcements, be careful
     not to re-announce their modified version ourselves */
  if (src == hfrom || src != hostaddr)
    {
      parse_entry(NULL, data, length, src, hfrom,
		  addr, port,
		  sec, "trusted", recvkey);
    }
  else
    {
      parse_entry(NULL, data, length, src, hfrom,
		  addr, port,
		  sec, "untrusted", recvkey);
    }
  return 0;
}


int build_packet(char *buf, char *adstr, int len, int encrypt)
{
  struct sap_header *bp;
  int len_add=0;

  bp=(struct sap_header *)buf;
  bp->compress=0;
  if (encrypt==0) {
    memcpy(buf+sizeof(struct sap_header), adstr, len);
    bp->enc=0;
  } else {
    memcpy(buf+sizeof(struct sap_header)+4, adstr, len);
#ifdef DEBUG
    printf("sending encrypted session\n");
#endif
    bp->enc=1;
    *(u_int*)(buf+sizeof(struct sap_header))=0;		/* timeout */
    len_add=4;
  }
  bp->src=htonl(hostaddr);
  bp->msgid=0;
  bp->version=1;
  bp->type=0;
  bp->authlen=0;
  return len_add;
}

int store_data_to_announce(struct advert_data *addata, 
			   char * adstr, char *keyname)
{
  char  key[MAXKEYLEN];
  char *encdata;

  if (strcmp(keyname,"")!=0) {
    if (find_key_by_name(keyname, key)!=0)
      return -1;
    encrypt_announcement(adstr, &encdata, &(addata->length), key);
    addata->data=malloc(addata->length);
    memcpy(addata->data, encdata, addata->length);
    addata->encrypt=1;
    return 0;
  } else {
    addata->data=malloc(addata->length);
    addata->encrypt=0;
    memcpy(addata->data, adstr, addata->length);
    return 0;
  }
}

int ui_createsession(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  int endtime, interval;
  unsigned char ttl;
  int port;
  char aid[80];
  char data[2048];
  struct timeval tv;
  char key[MAXKEYLEN]="";

  gettimeofday(&tv, NULL);
  endtime=atol(argv[2]);
  ttl=(unsigned char)atoi(argv[5]);
  port=atoi(argv[4]);
  interval=INTERVAL;
  /*need the copy because parse entry splats the data*/
  strncpy(data, argv[1], 2047);
  find_key_by_name(argv[6], key);
  parse_entry(aid, data, strlen(data), hostaddr, hostaddr, argv[3], port, tv.tv_sec, "trusted", key);
  queue_ad_for_sending(aid, argv[1], interval, endtime, argv[3], port, ttl, argv[6]);
  return TCL_OK;
}
 


int ui_quit()
{
  /*Save any encryption keys we gained*/
  save_keys();
 
  doexit=TRUE;
  return TCL_OK;
}

int ui_set_passphrase(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  return (set_pass_phrase(argv[1]));
}

int ui_get_passphrase(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  strcpy(interp->result, get_pass_phrase());
  return (TCL_OK);
}

int ui_write_crypted_file(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  write_crypted_file(argv[1], argv[2], atoi(argv[3]), get_pass_phrase());
  return (TCL_OK);
}

int ui_add_key(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  return (register_key(/*key*/ argv[1], 
		       /*keyname*/ argv[2] ));
}

int ui_delete_key(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  return (delete_key(/*keyname*/ argv[1]));
}

int ui_load_keys(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  int res;
  res=load_keys();
  if (res<0) {
    sprintf(interp->result, "0");
  } else {
    sprintf(interp->result, "1");
  }
  return TCL_OK;
}

int ui_save_keys()
{
  return(save_keys());
}

int ui_find_key_by_name(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  char key[MAXKEYLEN];
  find_key_by_name(argv[1], key);
  sprintf(interp->result, "{%s}", key);
  return TCL_OK;
}
int ui_find_keyname_by_key(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  char keyname[MAXKEYLEN];
  find_keyname_by_key(argv[1], keyname);
  sprintf(interp->result, "{%s}", keyname);
  return TCL_OK;
}
