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

/* #define DEBUG */

extern struct keydata* keylist;
extern char passphrase[MAXKEYLEN];
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
  strcat(keyfilename, "\\keys");
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
#ifdef AUTH
 if (src == hfrom || src != hostaddr) {
    parse_entry(NULL,data,length,src,hfrom,addr,port,sec,"trusted",recvkey ,
                NULL, NULL, 0, NULL,NULL, NULL, 0, NULL,NULL,NULL);
  } else {
    parse_entry(NULL,data,length,src,hfrom,addr,port,sec,"untrusted",recvkey,
                NULL, NULL, 0, NULL,NULL, NULL, 0, NULL,NULL,NULL);
  }
#else
 
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
#endif /*AUTH*/
  return 0;
}


int build_packet(char *buf, char *adstr, int len, int encrypt)
{
  struct sap_header *bp;
  int len_add=0;
  int privlen=0;
 
  bp=(struct sap_header *)buf;
  bp->compress=0;
  if (encrypt==0) {
    memcpy(buf+sizeof(struct sap_header), adstr, len);
    bp->enc=0;
  } else {
    bp->enc=1;
 
/* first add the timeout field */
    *(u_int*)(buf+sizeof(struct sap_header))=0;         /* timeout */
 
/* now add the privacy header */
 
    privlen = add_privacy_header(buf,0);
 
/* add the data after the privacy header */
 
    memcpy(buf+sizeof(struct sap_header)+4+privlen, adstr, len);
#ifdef DEBUG
    printf("sending encrypted session\n");
#endif
    len_add=4+privlen;
  }
  bp->src=htonl(hostaddr);
  bp->msgid=0;
  bp->version=1;
  bp->type=0;
  bp->authlen=0;
  return len_add;
}
 
int add_privacy_header(char *buf, int auth_len)
{
  struct priv_header *priv_hdr;
  int padlen, privlen=0;
  priv_hdr = (struct priv_header *)malloc(sizeof(struct priv_header));
 
/* only DES is used at the moment so the header is very simple */
 
  priv_hdr->version=1;
  priv_hdr->padding=1;
  priv_hdr->enc_type=DES;
  priv_hdr->hdr_len=1;       /* No. of 32 bit words in privacy header       */
  padlen = 2;                /* always 2 padding bytes at end of DES header */
 
#ifdef DEBUG
  printf("Privacy Header built: version = %d, padding = %d, enctype = %d, hdr_len = %d\n",priv_hdr->version, priv_hdr->padding, priv_hdr->enctype, priv_hdr->hdr
_len);
#endif
/* copy priv_hdr to buf */
 
  memcpy(buf+sizeof(struct sap_header)+auth_len+4, priv_hdr, (priv_hdr->hdr_len*4) );
 
/* set the padding byte number at end of header */
 
  buf[sizeof(struct sap_header)+4+auth_len+(priv_hdr->hdr_len*4)-1] = (char)padlen;
 
/* finished with the privacy header so free it up and return length of header */
 
  privlen = priv_hdr->hdr_len*4;
  free(priv_hdr);
 
  return(privlen);
}
int store_data_to_announce(struct advert_data *addata, 
			   char * adstr, char *keyname)
{
  char  key[MAXKEYLEN];
  char *encdata;

  if (strcmp(keyname,"")!=0) {
    if (find_key_by_name(keyname, key)!=0)
      return -1;
    addata->length= strlen(adstr);
#ifdef NEVER
    encrypt_announcement(adstr, &encdata, &(addata->length), key);
#else
    encrypt_announcement(adstr, &encdata, (int *)addata->length, key);
#endif
    addata->data=malloc(addata->length);
    memcpy(addata->data, encdata, addata->length);
    addata->encrypt=1;
    return 0;
  } else {
    addata->length= strlen(adstr);
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
  char aid[80]="";
  struct timeval tv;
  char key[MAXKEYLEN]="";
  char *tempptr=NULL;
  int i, *authinfo=0;
  int  *encinfo=0;
  struct advert_data *addata=NULL;

  char data[MAXADSIZE];
  char new_data[MAXADSIZE];
  char authstatus[AUTHSTATUSLEN];
  char encstatus[ENCSTATUSLEN];
  char authmessage[AUTHMESSAGELEN];
  char encmessage[ENCMESSAGELEN];

  int irand;
  int new_len;
  int rc_storauth;
  int rc_genauth;
  int rc_storenc;

  tempptr = (char *)malloc(10);

/* Clear key */
  for (i=0; i<MAXKEYLEN; ++i) {
    key[i]=0;
  }

  memset(authmessage,0,AUTHMESSAGELEN);
  memset(encmessage, 0,ENCMESSAGELEN);
  memset(authstatus, 0,AUTHSTATUSLEN);
  memset(encstatus,  0,ENCSTATUSLEN);
  memset(new_data,   0,MAXADSIZE);
  memset(data,       0,MAXADSIZE);

  gettimeofday(&tv, NULL);
  endtime=atol(argv[2]);
  ttl=(unsigned char)atoi(argv[5]);
  port=atoi(argv[4]);
  interval=INTERVAL;

/* need the copy because parse entry splats the data */

  strncpy(data, argv[1], MAXADSIZE);
  find_key_by_name(argv[6], key);

#ifdef AUTH

  irand = (random()&0xffff);

/* use PGP to create authentication info for the SAP packet */

  if ( strcmp(argv[7],"pgp")==0 || strcmp(argv[7],"cpgp")==0 ) {

    writelog(printf("ui_create_session: (a) calling generate_authentication_info\n");)
    if(!generate_authentication_info(data,strlen(data), authstatus, irand ,authmessage, AUTHMESSAGELEN)) {
      Tcl_SetVar(interp, "validpassword", "0", TCL_GLOBAL_ONLY);
      return TCL_OK;
    } else {
      Tcl_SetVar(interp, "validpassword", "1", TCL_GLOBAL_ONLY);

      addata=(struct advert_data *)malloc(sizeof (struct advert_data));
      addata->data=NULL;
      addata->authinfo=(struct auth_info *)malloc(sizeof(struct auth_info));
      addata->sapenc_p=NULL;
#ifdef EDNEVER
/* this is already set in generate_authentication_info */
      strcpy(authstatus, "Authenticated");
#endif
      writelog(printf("ui_create_session: (a) calling store_authentication_in_memory\n");)
      rc_storauth = store_authentication_in_memory(addata , argv[7], irand);
      if ( rc_storauth == 0 || rc_storauth == 2 ) {
        Tcl_SetVar(interp, "validauth", "0", TCL_GLOBAL_ONLY);
        return TCL_OK;
      } else  {
        Tcl_SetVar(interp, "validauth", "1", TCL_GLOBAL_ONLY);
      }
     }

  } else if ( strcmp(argv[7],"x509")==0 || strcmp(argv[7],"cx50")==0 ) {

    if (!generate_x509_authentication_info(data,strlen(data), authstatus, irand,authmessage, AUTHMESSAGELEN)) {
      Tcl_SetVar(interp, "validpassword", "0", TCL_GLOBAL_ONLY);
      return TCL_OK;
    } else {
      Tcl_SetVar(interp, "validpassword", "1", TCL_GLOBAL_ONLY);
      addata=(struct advert_data *)malloc(sizeof (struct advert_data));
      addata->data=NULL;
      addata->authinfo=(struct auth_info *)malloc(sizeof(struct auth_info));
      strcpy(authstatus, "Authenticated");
      if (store_x509_authentication_in_memory(addata , argv[7], irand) == 2 ) {
        Tcl_SetVar(interp, "validauth", "0", TCL_GLOBAL_ONLY);
        return TCL_OK;
      } else {
        Tcl_SetVar(interp, "validauth", "1", TCL_GLOBAL_ONLY);
      }
    }
  } else {
    strncpy(authstatus, "noauth", AUTHSTATUSLEN);
    strncpy(authmessage, "none", AUTHMESSAGELEN);
    /*XXXXwhat does this do???*/
    strncpy(argv[7],"none", strlen(argv[7]));
  }

/* use PGP to create encryption info for the SAP packet  */

  irand = (random()&0xffff);
  if ( (strcmp(argv[8],"pgp")==0  && strcmp(argv[6],"")==0) ) {

    writelog(printf("ui_create_session: (a) calling generate_encryption_info\n");)
    if (!generate_encryption_info(data, encstatus, irand,
				  encmessage, ENCMESSAGELEN)) { 
      Tcl_SetVar(interp, "validfile", "0", TCL_GLOBAL_ONLY);
      return TCL_OK;
    } else {
      Tcl_SetVar(interp, "validfile", "1", TCL_GLOBAL_ONLY);
    }

/* if not created addata then we have not been in authentication */

    if(addata == NULL) {
      addata=(struct advert_data *)malloc(sizeof (struct advert_data));
      addata->data=NULL;
      addata->authinfo=NULL;
    }

    addata->sapenc_p=(struct priv_header *)malloc(sizeof(struct priv_header));

    strcpy(encstatus, "Encrypted");
    writelog(printf("ui_create_session: (a) calling store_encryption_in_memory\n");)
    rc_storenc = store_encryption_in_memory(addata, argv[8], irand);
    if ( rc_storenc != 1 ) {
      writelog(printf("ui_create_session: rc_storenc = %d\n",rc_storenc);)
      return TCL_OK;
    }

  } else if ( (strcmp(argv[8],"x509")==0  && strcmp(argv[6],"")==0) ) {

    if (!generate_x509_encryption_info(data, encstatus, irand, 
				       encmessage, ENCMESSAGELEN)) {
      Tcl_SetVar(interp, "validfile", "0", TCL_GLOBAL_ONLY);
      return TCL_OK;
    } else {
      Tcl_SetVar(interp, "validfile", "1", TCL_GLOBAL_ONLY);
    }

    if(addata == NULL) {
      addata=(struct advert_data *)malloc(sizeof (struct advert_data));
      addata->data=NULL;
      addata->authinfo=NULL;
     }
    addata->sapenc_p=(struct priv_header *)malloc(sizeof(struct priv_header));
    strncpy(encstatus, "Encrypted", ENCSTATUSLEN);
    store_x509_encryption_in_memory(addata, argv[8], irand);

   } else {

     strncpy(encstatus, "noenc", ENCSTATUSLEN);
     strncpy(encmessage, "none", ENCMESSAGELEN);
/* fix to avoid memory problem as string "none" is longer than argv[8] if */
/* this is "des" */
     strcpy(tempptr, "none");
     argv[8] = tempptr;
   }

    if (strcmp(argv[6],"")!=0) {
      if (find_key_by_name(argv[6], key)!=-1) {
        strncpy(encstatus, "success", ENCSTATUSLEN);
        strncpy(encmessage,"Des has been successful", ENCMESSAGELEN);
	/*XXXX what does this do???*/
        strncpy(argv[8], "des", strlen(argv[8]));
      }
    }  

/* edmund - quite happy above is okay - 10.56 - sep 8 */
/* don't know why we are regenerating the auth info here ? */

    if ( strcmp(argv[7],"pgp")==0 || strcmp(argv[7],"cpgp")==0 ) {

      new_len=gen_new_data(data,new_data,argv[6],addata);
      irand = (random()&0xffff);
      memset(authmessage,0,AUTHMESSAGELEN);
      memset(authstatus,0,AUTHSTATUSLEN);
      free(addata->authinfo);
      addata->authinfo=(struct auth_info *)malloc(sizeof(struct auth_info));
      writelog(printf("ui_create_session: (b) calling generate_authentication_info\n");)
      rc_genauth = generate_authentication_info(new_data,new_len, 
		      authstatus, irand ,authmessage, AUTHMESSAGELEN);
      writelog(printf("ui_create_session: rc from generate_authentication_info = %d\n",rc_genauth);)
      addata->authinfo=(struct auth_info *)malloc(sizeof(struct auth_info));
      writelog(printf("ui_create_session: (b) calling store_authentication_in_memory\n");)
      rc_storauth = store_authentication_in_memory(addata , argv[7], irand);
      writelog(printf("ui_create_session: rc from store_authentication_in_memory = %d\n",rc_storauth);)

    } else if ( strcmp(argv[7],"x509")==0 || strcmp(argv[7],"cx50")==0 ) {

      new_len=gen_new_data(data,new_data,argv[6],addata);
      irand = (random()&0xffff);
      memset(authmessage,0,AUTHMESSAGELEN);
      memset(authstatus,0,AUTHSTATUSLEN);
      free(addata->authinfo);
      addata->authinfo=(struct auth_info *)malloc(sizeof(struct auth_info));
      generate_x509_authentication_info(new_data,new_len, authstatus, 
					irand, authmessage, AUTHMESSAGELEN);
      store_x509_authentication_in_memory(addata , argv[7], irand);

    }

    parse_entry(aid, data, strlen(data), hostaddr, hostaddr, argv[3], port,
         tv.tv_sec, "trusted", key, argv[7], authstatus,
         authinfo, argv[9],argv[8],encstatus,encinfo,argv[10],authmessage,encmessage);
 
    writelog(printf("++ debug ++ queue_ad_for_sending from ui_createsession: key = %s\n",argv[6]);) 
    queue_ad_for_sending(aid, argv[1], interval, endtime, argv[3], port, ttl, argv[6], argv[7], authstatus ,argv[8], encstatus,addata);
 
#else

    parse_entry(aid, data, strlen(data), hostaddr, hostaddr, argv[3], port, tv.tv_sec, "trusted", key);
    queue_ad_for_sending(aid, argv[1], interval, endtime, argv[3], port, ttl, argv[6]);
#endif /* AUTH */

  free(tempptr);
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
#ifdef AUTH
write_crypted_file(argv[1], argv[2], atoi(argv[3]), get_pass_phrase(),
                     argv[5], argv[4]);
#else
  write_crypted_file(argv[1], argv[2], atoi(argv[3]), get_pass_phrase());
#endif
  return (TCL_OK);
}
#ifdef AUTH
int ui_write_authentication(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  write_authentication(argv[1], argv[2],atoi(argv[3]),argv[4]);
  return (TCL_OK);
}
int ui_write_encryption(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  write_encryption(argv[1], argv[2],atoi(argv[3]),
                        argv[5],argv[6], argv[4]);
 
  return (TCL_OK);
}
#endif


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

int ui_make_random_key()
{
  return(make_random_key());
}

int ui_find_key_by_name(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;
{
  char key[MAXKEYLEN]="";
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
  char keyname[MAXKEYLEN]="";
  find_keyname_by_key(argv[1], keyname);
  sprintf(interp->result, "{%s}", keyname);
  return TCL_OK;
}

int gen_new_data(char *adstr,char *new_data, char *keyname,struct advert_data *addata )

{
        FILE *file=NULL;
	char *homedir;
	char testname[256];
        char *buf=NULL;
        int newlen;
        struct sap_header *bp=NULL;
        struct auth_info *authinfo=NULL;
        struct priv_header *sapenc_p=NULL;
        int auth_len=0;
        int hdr_len=0;
        int privlen=0;
 
                    authinfo = addata->authinfo;
                    if (addata->sapenc_p != NULL)
                    sapenc_p = addata->sapenc_p;
        switch  (authinfo->auth_type) {
	case 3:
        case 4:
        auth_len = authinfo->sig_len+authinfo->key_len+2+authinfo->pad_len;
        break;
	case 1:
        case 2:
                auth_len = authinfo->sig_len+2+authinfo->pad_len;
        break;
	default:
                  auth_len = 0;
                  authinfo = NULL;
        break;
          }
                if (strcmp(keyname,"") != 0){
                    store_data_to_announce(addata, adstr, keyname);
                } else if (sapenc_p != NULL) {
                    if ( sapenc_p->enc_type == 2 ||  sapenc_p->enc_type == 3 ) {
                       hdr_len = sapenc_p->encd_len+2+sapenc_p->pad_len;
                       addata->length = sapenc_p->encd_len+sapenc_p->pad_len;
                       if (addata->data !=NULL)
                         free (addata->data);
                       addata->data = malloc(addata->length);
                       memcpy(addata->data, sapenc_p->enc_data, addata->length);
 
                     }
                } else {
                  hdr_len = 0;
		  addata->length = strlen(adstr);
		  if (addata->data !=NULL)
		    free (addata->data);
		  addata->data = malloc(strlen(adstr));
		  addata->encrypt=0;
		  memcpy(addata->data, adstr, strlen(adstr));
		}
 
         if (hdr_len != 0) {
            newlen=sizeof(struct sap_header)+4+hdr_len;
          } else if (addata->encrypt !=0) {
                newlen=sizeof(struct sap_header)+4+addata->length;
         } else {
                newlen=sizeof(struct sap_header)+addata->length;
               }
 
         buf=(char *)malloc(newlen);
         bp=malloc(sizeof(struct sap_header));
            bp->compress=0;
            bp->src=htonl(hostaddr);
            bp->msgid=0;
            bp->version=1;
            bp->type=0;
            bp->authlen=auth_len/4;
        if (addata->encrypt==0 && hdr_len==0) {
                bp->enc=0;
                memcpy(buf,bp,sizeof(struct sap_header));
                free(bp);
                memcpy(buf+sizeof(struct sap_header), addata->data, addata->length);   
 
        } 
        else 
        {
                bp->enc=1;
                memcpy(buf,bp,sizeof(struct sap_header));
                free(bp);
                if (addata->encrypt !=0 ) {
                        *(u_int*)(buf+sizeof(struct sap_header))=0;
                        privlen = add_privacy_header(buf,0);
                        memcpy(buf+sizeof(struct sap_header)+4,
                                                addata->data, addata->length);
                }
                else
                {
                     *(u_int*)(buf+sizeof(struct sap_header))=0;
                     memcpy((buf+sizeof(struct sap_header))+4, sapenc_p, 2);
                     memcpy(buf+sizeof(struct sap_header)+4+2,
                                                addata->data, addata->length);
 
                }
        }
      free(addata->data);
      addata->length =0;
      memcpy(new_data,buf,newlen); 
      free(buf);
homedir=(char *)getenv("HOME");
#ifdef WIN32
sprintf(testname, "%s\\sdr\\data_snd.txt", homedir);
#else
sprintf(testname, "%s/.sdr/data_snd.txt", homedir);
#endif
file=fopen(testname, "w");
fwrite(new_data, 1, newlen, file);
fclose(file);


return newlen;
}
int gen_new_auth_data(char *buf, char *new_data,struct sap_header *bp,int auth_len,int len,int enc)
{
FILE *file=NULL;
char *homedir;
char testname[256];
int len1;
int newlen;
char *newbuf=NULL;
char *sbuf;
struct sap_header *bp1=NULL;
bp1=malloc(sizeof(struct sap_header));
bp1->version=bp->version;
bp1->type=bp->type;
bp1->enc=bp->enc;
bp1->compress=bp->compress;
bp1->authlen=bp->authlen;
bp1->src=bp->src;
bp1->msgid=0;
	switch (enc) {
	case 0:
         newlen=len-auth_len;
        newbuf = malloc(newlen);
        memcpy(newbuf,bp1,sizeof(struct sap_header));
        sbuf=buf+sizeof(struct sap_header)+auth_len;
        len1 = newlen-sizeof(struct sap_header);
        memcpy(newbuf+sizeof(struct sap_header),sbuf,len1);
        break;
	case 1:
	newlen=len-auth_len;
	newbuf = malloc(newlen);
        memcpy(newbuf,bp1,sizeof(struct sap_header));
	sbuf=buf+8+auth_len;
	len1 = newlen-8;
        memcpy(newbuf+sizeof(struct sap_header),sbuf,2);
        sbuf+=2;
        len1=len1-2;
	memcpy(newbuf+8+2,sbuf,len1 );
	break;
	case 2:
	newlen=len-auth_len-4;
	newbuf = malloc(newlen);
        memcpy(newbuf,bp1,sizeof(struct sap_header));
	sbuf=buf+8+auth_len;
	memcpy(newbuf+8,sbuf,4);
	sbuf=sbuf+4+4;
	len1=newlen-8-4;
	memcpy(newbuf+8+4,sbuf,len1);
	break;
	}
memcpy(new_data,newbuf,newlen);
homedir=(char *)getenv("HOME");
#ifdef WIN32
sprintf(testname, "%s\\sdr\\data_rcv.txt", homedir);
#else
sprintf(testname, "%s/.sdr/data_rcv.txt", homedir);
#endif
file=fopen(testname, "w");
if (file==NULL) {
  printf("failed to open temp file %s\n", testname);
  return newlen;
}
fwrite(new_data, 1, len, file);
fclose(file); 
return newlen;
}
int gen_new_cache_data(char *new_data, struct sap_header *bp,char *data,int data_len,int enc)
{
FILE *file=NULL;
char *homedir;
char testname[256];
int len;
char *sbuf;
struct sap_header *bp1=NULL;
bp1=malloc(sizeof(struct sap_header));
bp1->version=bp->version;
bp1->type=bp->type;
bp1->enc=bp->enc;
bp1->compress=bp->compress;
bp1->authlen=bp->authlen;
bp1->src=bp->src;
bp1->msgid=0;
len =data_len-1+sizeof(struct sap_header);
memcpy(new_data,bp1,sizeof(struct sap_header));
free(bp1);
	
	switch (enc) {
	case 1:
	/**(u_int*)(new_data+sizeof(struct sap_header))=0;*/
	len+=4;
	memcpy((new_data+sizeof(struct sap_header))+4,data,data_len);
	break;
	case 0:
	memcpy(new_data+sizeof(struct sap_header),data,data_len);
        len = len +1;
	break;
	case 2:
	memcpy((new_data+sizeof(struct sap_header)),data,data_len);
	break;
	}

homedir=(char *)getenv("HOME");
#ifdef WIN32
sprintf(testname, "%s\\sdr\\data_ch.txt", homedir);
#else
sprintf(testname, "%s/.sdr/data_ch.txt", homedir);
#endif
file=fopen(testname, "w");
fwrite(new_data, 1, len, file);
fclose(file);

return len;
}

