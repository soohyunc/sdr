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
  
/* Decrypt the announcement, and skip the encryption fields */

  if (enc==1) {
    /*note - encrypted data includes timeout*/
    printf("received encrypted announcement...\n");
    if (decrypt_announcement(data, &length, recvkey)!=0) {
      printf("      ... cannot decrypt announcement!\n");
      return 1;
    }
    /*data now has encryption fields removed*/
  } else {
    strcpy(recvkey, "");
  }

  /* if someone else is repeating our announcements, be careful
     not to re-announce their modified version ourselves */

 if (src == hfrom || src != hostaddr) {
    parse_entry(NULL,data,length,src,hfrom,addr,port,sec,"trusted",recvkey ,
                NULL, NULL, 0, NULL,NULL, NULL, 0, NULL,NULL,NULL);
  } else {
    parse_entry(NULL,data,length,src,hfrom,addr,port,sec,"untrusted",recvkey,
                NULL, NULL, 0, NULL,NULL, NULL, 0, NULL,NULL,NULL);
  }

  return 0;
}

/*----------------------------------------------------------------------*/
/* build_packet - build the packet prior to sending it                  */
/* add - sap header, timeout, auth_hdr and enc_hdr                      */
/* buf malloced in send_advert(), filled here and sent in send_advert() */
/*----------------------------------------------------------------------*/
int build_packet(char *buf, char *adstr, int len, int encrypt, 
                 u_int auth_len, u_int hdr_len, 
                 struct auth_info *authinfo, struct priv_header *sapenc_p)
{
  struct sap_header  *bp;
  struct auth_header *auth_hdr;
  char *ap=NULL;

  int len_add=0;
  int privlen=0;
  int i=0;

  writelog(printf(" -- entered build_packet --\n");)
 
/* set the sap_hdr to point to the start of buf */

  bp = (struct sap_header *)buf;

/* set up some basic sap_header fields */

  bp->version  = 1;
  bp->type     = 0;
  bp->compress = 0;
  bp->authlen  = auth_len / 4;
  bp->msgid    = 0;
  bp->src      = (unsigned long)htonl(hostaddr);

  if ( (hdr_len == 0) && (encrypt == 0) ) {
    bp->enc = 0;
  } else {
    bp->enc = 1;
  }

  len_add += sizeof(struct sap_header);

/* the sap_header has been filled out now so do the auth_header */

  if ( auth_len != 0 ) {

/* auth header (length is 2 as Goli has signature length as 2nd byte !) */

    auth_hdr = (struct auth_header *)((char *)buf+sizeof(struct sap_header));

    auth_hdr->version   = authinfo->version;
    auth_hdr->padding   = authinfo->padding;
    auth_hdr->auth_type = authinfo->auth_type;
    auth_hdr->siglen    = authinfo->siglen;

/* add signature    */

    ap = (char *)buf+sizeof(struct sap_header)+AUTH_HEADER_LEN;
    memcpy(ap, authinfo->signature, authinfo->sig_len);
    ap += authinfo->sig_len;

/* add key certificate if needed */
/* obsolete - will be removed    */

    if (authinfo->auth_type == authPGPC) {
      memcpy(ap, authinfo->keycertificate, authinfo->key_len);
      ap += authinfo->key_len;
    }

/* add any necessary padding to the auth_header */

    if (authinfo->pad_len != 0) {
      for (i=0; i<((authinfo->pad_len)-1); ++i) {
        ap[i] = 0;
      }
      ap[i] = authinfo->pad_len;
    }

    len_add += auth_len;

  }

/* sap_hdr and auth_hdr filled now so fill the privacy header and data */

  if ( (hdr_len == 0) && (encrypt == 0) ) {
    memcpy(buf+sizeof(struct sap_header)+auth_len, adstr, len);
  } else {

/* first add the common timeout field - always 0 at the moment */

    for (i=0; i<4; i++) {
      buf[sizeof(struct sap_header)+auth_len+i]=0;
    }

/* fill in the privacy header */

    privlen = add_privacy_header(buf, auth_len, sapenc_p);

/* fill in the data                                                   */
/* for DES privlen will be 4 and for asymm it will be the whole thing */

    if (sapenc_p == NULL) {
      memcpy(buf+sizeof(struct sap_header)+auth_len+TIMEOUT+privlen,adstr,len);
      len_add += TIMEOUT + privlen;
    } else {
      memcpy(buf+sizeof(struct sap_header)+auth_len+TIMEOUT+ENC_HEADER_LEN,adstr,len);
      len_add += TIMEOUT + ENC_HEADER_LEN;
    }

  }

/* len_add is the amount of stuff we have added (doesn't include data)    */
/* ie auth_len + priv_len + TIMEOUT if encrypted                          */

  return (len_add);
}
 
/*-------------------------------------------------------------------------*/
/* add_privacy_header -                                                    */
/* adds privacy header to symmetrically/asymmetrically encrypted packets   */
/*-------------------------------------------------------------------------*/
int add_privacy_header(char *buf, int auth_len, struct priv_header *sapenc_p)
{
  struct priv_header *priv_hdr;
  unsigned int padlen;
  int privlen=0;
  char *ap=NULL;

  writelog(printf(" -- entered add_privacy_header --\n");)

  priv_hdr = (struct priv_header *)((char *)buf+sizeof(struct sap_header)+auth_len+TIMEOUT);

/* the only symmetric encryption at the moment is DES */

  if ( sapenc_p == NULL ) { 

/*  symm */
  
    priv_hdr->version  = 1;
    priv_hdr->padding  = 1;
    priv_hdr->enc_type = DES;
    priv_hdr->hdr_len  = 1;    /* No. of 32 bit words in privacy header   */
    padlen             = 2;    /* always 2 pad bytes at end of DES header */

/* add the padding and padlen in the final two bytes of the hdr */

    ap = (char *)buf+sizeof(struct sap_header)+TIMEOUT+auth_len+ENC_HEADER_LEN;
    ap[0] = 0;
    ap[1] = 2;

  } else { 

/* asymm */

    priv_hdr->version  = sapenc_p->version;
    priv_hdr->padding  = sapenc_p->padding;
    priv_hdr->enc_type = sapenc_p->enc_type;
    priv_hdr->hdr_len  = sapenc_p->hdr_len;

/* no need to set the padding as the encrypted payload follows immediately */
  
  }

/* calculate the return value (in bytes not words) and return it */

  privlen = priv_hdr->hdr_len*4;
 
  return(privlen);
}

/* ---------------------------------------------------------------------- */
/* store_data_to_announce :                                               */
/*   seems to set up the advert_data->data to be either the encrypted     */
/*   data or normal data and the advert_data->encrypt to be 1 or 0        */
/*   Also modifies the length within encrypt_announcement                 */
/* ---------------------------------------------------------------------- */
int store_data_to_announce(struct advert_data *addata, 
			   char * adstr, char *keyname)
{
  char  key[MAXKEYLEN];
  char *encdata=NULL;

  writelog(printf(" -- entered store_data_to_announce --\n");)

  addata->length = strlen(adstr);

/* find the right key to use */

  if (strcmp(keyname,"")!=0) {

/* symmetric encryption used */

    if (find_key_by_name(keyname, key)!=0) {
      return -1;
    }

/* if found key then encrypt the data */

    encrypt_announcement(adstr, &encdata, &(addata->length), key); 

/* copy the encrypted data and length to the advert_data structure */

    addata->data=malloc(addata->length);
    memcpy(addata->data, encdata, addata->length);
    addata->encrypt=1;
    return 0;

  } else {

/* keyname was null ie no encryption */
/* copy the clear data and length to the advert_data structure */

    addata->data=(char *)malloc(addata->length);
    memcpy(addata->data, adstr, addata->length);
    addata->encrypt=0;
    return 0;

  }
}

/* ---------------------------------------------------------------------- */
/* ui_createsession - creates the session announcement                    */
/*                                                                        */
/* argv[1]=sess; [2]=stoptime; [3]=addr; [4]=port; [5]=ttl; [6]=keyname   */
/*     [7]=auth_type; [8]=enc_type; [9]=keyid(auth); [10]=keyid(enc)      */
/*                                                                        */
/* ---------------------------------------------------------------------- */
int ui_createsession(dummy, interp, argc, argv)
    ClientData dummy;                   /* Not used. */
    Tcl_Interp *interp;                 /* Current interpreter. */
    int argc;                           /* Number of arguments. */
    char **argv;                        /* Argument strings. */
{
  struct advert_data *addata=NULL;
  struct timeval tv;
  char aid[80]="";
  char key[MAXKEYLEN]="";
  int endtime, interval, port;
  unsigned char ttl;
  char *data=NULL, *new_data=NULL;

  char *authstatus=NULL;
  char *authmessage=NULL;
  char *encstatus=NULL;
  char *encmessage=NULL;
  char *tempptr=NULL;

  int i, *authinfo=0, *encinfo=0;
  int irand, new_len;
  int rc;

/* Clear key */

  for (i=0; i<MAXKEYLEN; ++i) { 
    key[i]=0;
  }

/* set up the buffer */

  data = (char *)malloc(MAXADSIZE);

/* set up some basic information about the session */

  gettimeofday(&tv, NULL);
  endtime  = atol(argv[2]);
  ttl      = (unsigned char)atoi(argv[5]);
  port     = atoi(argv[4]);
  interval = INTERVAL;

/* need the copy because parse entry splats the data */

  strncpy(data, argv[1], MAXADSIZE);

/* Create the authentication information */

  authstatus  = (char *)malloc(AUTHSTATUSLEN);
  authmessage = (char *)malloc(AUTHMESSAGELEN);

  if ( strcmp(argv[7],"pgp")==0 || strcmp(argv[7],"cpgp")==0 ) {

/* create the advert_data structure */

    if (addata == NULL) {
      addata=(struct advert_data *)malloc(sizeof (struct advert_data));
      addata->sapenc_p = NULL;
      addata->data     = NULL;
      addata->sap_hdr  = NULL;
      addata->encrypt  = 0;
    }
    addata->authinfo = (struct auth_info *)malloc(sizeof(struct auth_info));
  
/* call generate_authentication_info */

    rc = generate_authentication_info(data,strlen(data), authstatus, 
                            authmessage, AUTHMESSAGELEN, addata, argv[7]);

/* check it all worked okay */

    if ( rc != 0 ) {
      Tcl_SetVar(interp, "validpassword", "0", TCL_GLOBAL_ONLY);
      Tcl_SetVar(interp, "validauth",     "0", TCL_GLOBAL_ONLY);
      return 1;
    } else {
      Tcl_SetVar(interp, "validpassword", "1", TCL_GLOBAL_ONLY);
      Tcl_SetVar(interp, "validauth",     "1", TCL_GLOBAL_ONLY);
    }

  } else if ( strcmp(argv[7],"x509")==0 || strcmp(argv[7],"cx50")==0 ) {

/* haven't looked at sorting out this X509 code yet */

    irand = (lblrandom()&0xffff);

    rc = generate_x509_authentication_info(data,strlen(data), authstatus, 
                     irand,authmessage, AUTHMESSAGELEN);

    if ( !rc ) {
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

/* no authentication is required */

    strncpy(authstatus, "noauth", AUTHSTATUSLEN);
    strncpy(authmessage, "none", AUTHMESSAGELEN);
/* don't know if we need the following ? */
    strncpy(argv[7],"none", strlen(argv[7]));
  }

/* Create encryption info for the SAP packet  */

  encstatus  = (char *)malloc(ENCSTATUSLEN);
  encmessage = (char *)malloc(ENCMESSAGELEN);

  if ( (strcmp(argv[8],"pgp")==0  && strcmp(argv[6],"")==0) ) {

/* create the advert_data structure if not created already */

    if(addata == NULL) {
      addata=(struct advert_data *)malloc(sizeof (struct advert_data));
      addata->data     = NULL;
      addata->authinfo = NULL;
      addata->sap_hdr  = NULL;
      addata->encrypt  = 0;
    }
    addata->sapenc_p=(struct priv_header *)malloc(sizeof(struct priv_header));

/* call generate_encryption_info */

    rc = generate_encryption_info(data, encstatus, encmessage, 
             ENCMESSAGELEN, addata, argv[8]);

/* check it all worked okay */

    if ( rc != 0 ) { 
      Tcl_SetVar(interp, "validfile", "0", TCL_GLOBAL_ONLY);
      return 1;
    } else {
      Tcl_SetVar(interp, "validfile", "1", TCL_GLOBAL_ONLY);
    }

    strcpy(encstatus, "Encrypted");

  } else if ( (strcmp(argv[8],"x509")==0  && strcmp(argv[6],"")==0) ) {

/* asymmetric - X509 encryption - not checked yet */

    irand = (lblrandom()&0xffff);
    if (!generate_x509_encryption_info(data, encstatus, irand, 
				       encmessage, ENCMESSAGELEN)) {
      Tcl_SetVar(interp, "validfile", "0", TCL_GLOBAL_ONLY);
      return TCL_OK;
    } else {
      Tcl_SetVar(interp, "validfile", "1", TCL_GLOBAL_ONLY);
    }

    if(addata == NULL) {
      addata=(struct advert_data *)malloc(sizeof (struct advert_data));
      addata->data     = NULL;
      addata->authinfo = NULL;
      addata->sap_hdr  = NULL;
      addata->encrypt  = 0;
     }
    addata->sapenc_p=(struct priv_header *)malloc(sizeof(struct priv_header));
    strncpy(encstatus, "Encrypted", ENCSTATUSLEN);
    store_x509_encryption_in_memory(addata, argv[8], irand);

  } else {

/* no encryption */

    strncpy(encstatus, "noenc", ENCSTATUSLEN);
    strncpy(encmessage, "none", ENCMESSAGELEN);
/* avoid mem problem as string "none" is longer than argv[8] if this is "des" */
    tempptr = (char *) malloc(10);
    strcpy(tempptr, "none");
    argv[8] = tempptr;
  }

/* handle the case when there is just symmetric encryption        */
/* Why successful as all find_key_by_name does is find the key ?? */

  if (strcmp(argv[6],"")!=0) {
    if (find_key_by_name(argv[6], key)!=-1) {
      strncpy(encstatus, "success", ENCSTATUSLEN);
      strncpy(encmessage,"Des has been successful", ENCMESSAGELEN);
#ifdef NEVER
      strncpy(argv[8], "des", strlen(argv[8]));
#else
      strcpy(argv[8], "des");
#endif
    }
  }  

/* The situation here is: we have generated a signature on just the data  */
/* but want to genrate one over the whole SAP packet so gen_new_data adds */
/* a sap_header etc to the data - the problem is that a sap_header also   */
/* includes the length of the auth_header - we know this as we have made  */
/* one signature already and any others will be the same size. What we    */
/* really need to do is have a quick call to PGP with the keyid (argv[9]) */
/* to find out how long the key is and then we can deduce how long the    */
/* signature will be - thus we will be able to avoid the earlier call to  */
/* PGP to sign the data which takes a relatively long time                */

/* create a new area for the data + sap_header to be held */

    new_data = (char *)malloc(MAXADSIZE);

/* generate the new data structure and call gen_auth_info */

    if ( strcmp(argv[7],"pgp")==0 || strcmp(argv[7],"cpgp")==0 ) {

      new_len = gen_new_data(data,new_data,argv[6],addata);

/* do we need these ? */

      memset(authmessage,0,AUTHMESSAGELEN);
      memset(authstatus,0,AUTHSTATUSLEN);

/* free the old advert_data->authinfo structure as we need to redo it */
/* and it is only now that we don't need to know the auth_length      */

      free(addata->authinfo);
      addata->authinfo = (struct auth_info *)malloc(sizeof(struct auth_info));

/* call generate_authentication_info */

      rc = generate_authentication_info(new_data,new_len, authstatus, 
                           authmessage, AUTHMESSAGELEN, addata, argv[7]);

/* check it all worked okay */

    if ( rc != 0 ) {
      Tcl_SetVar(interp, "validpassword", "0", TCL_GLOBAL_ONLY);
      Tcl_SetVar(interp, "validauth",     "0", TCL_GLOBAL_ONLY);
      return 1;
    } else {
      Tcl_SetVar(interp, "validpassword", "1", TCL_GLOBAL_ONLY);
      Tcl_SetVar(interp, "validauth",     "1", TCL_GLOBAL_ONLY);
    }

  } else if ( strcmp(argv[7],"x509")==0 || strcmp(argv[7],"cx50")==0 ) {

/* X.509 stuff - I haven't looked at this */

    new_len=gen_new_data(data,new_data,argv[6],addata);
    irand = (lblrandom()&0xffff);
    memset(authmessage,0,AUTHMESSAGELEN);
    memset(authstatus,0,AUTHSTATUSLEN);
    free(addata->authinfo);
    addata->authinfo=(struct auth_info *)malloc(sizeof(struct auth_info));
    generate_x509_authentication_info(new_data,new_len, authstatus, 
			irand, authmessage, AUTHMESSAGELEN);
    store_x509_authentication_in_memory(addata , argv[7], irand);

  }

/* encryption and authentication has been finished so call parse_entry */

    parse_entry(aid, data, strlen(data), hostaddr, hostaddr, argv[3], port,
         tv.tv_sec, "trusted", key, 
         argv[7], authstatus, authinfo, argv[9], 
         argv[8], encstatus,  encinfo,  argv[10], authmessage,encmessage);
 
/* queue the ad for sending */

    queue_ad_for_sending(aid, argv[1], interval, endtime, argv[3], port, 
         ttl, argv[6], argv[7], authstatus ,argv[8], encstatus, addata);

/* free up some space */
 
  free(data);
  free(new_data);
  free(authmessage);
  free(authstatus);
  free(encmessage);
  free(encstatus);

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
write_crypted_file(argv[1], argv[2], atoi(argv[3]), get_pass_phrase(),
                     argv[5], argv[4]);
  return (TCL_OK);
}

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

/*---------------------------------------------------------------------*/
/* gen_new_data                                                        */
/*  - This seems to do the following: data is the text payload which   */
/* maybe encrypted. Make new buf, create a sap_header and priv_hdr and */
/* copy this all into new_data so we can call generate_auth_info on    */
/* the whole packet (except the auth header) rather than just the sdp  */
/* payload itself                                                      */
/* couldn't we do something like call build_packet and then call       */
/* gen_new_auth_data() ?                                               */
/*---------------------------------------------------------------------*/
/* The length of the auth_hdr is in the sap_hdr and we only know this  */
/* as we have already called PGP and the sig length will be the same   */
/* if using the same key or even the same length key - this is wasteful*/
/* so it would be better to have a quick call to PGP to find the key   */
/* length and not have to call PGP to sign a file twice - for the      */
/* moment leave it as it is                                            */
/*---------------------------------------------------------------------*/
int gen_new_data(char *adstr,
                 char *new_data, 
                 char *keyname,
   struct advert_data *addata )

{
    struct sap_header *bp=NULL;
    struct auth_info *authinfo=NULL;
    struct priv_header *sapenc_p=NULL;

    char *buf=NULL;

    int newlen;
    int auth_len=0, hdr_len=0, privlen=0;
    int i;

    writelog(printf(" -- entered gen_new_data --\n");)

/* point the internal authinfo to the authinfo part of the main advert_data */

    authinfo = addata->authinfo;

    if (addata->sapenc_p != NULL) {
      sapenc_p = addata->sapenc_p;
    }

/* authPGPC and authX509C are obsolete and will be removed */

    switch  (authinfo->auth_type) {

      case authPGPC:
      case authX509C:

        auth_len = authinfo->sig_len+authinfo->key_len+AUTH_HEADER_LEN+authinfo->pad_len;
        break;

      case authPGP:
      case authX509:

        auth_len = authinfo->sig_len+AUTH_HEADER_LEN+authinfo->pad_len;
        break;

      default:

        auth_len = 0;
        authinfo = NULL;
        break;
    }

/* set up addata->length, addata->data, addata->encrypt and hdr_len */

    if (sapenc_p == NULL) {

/* unencrypted or encrypted symmetrically                    */
/* length, data, encrypt are set by store_data_to_announce() */

      hdr_len = 0;
      if (addata->data != NULL) {
        free (addata->data);
      }
      store_data_to_announce(addata, adstr, keyname);

    } else {

/* asymmetric encryption has been used */

      if ( sapenc_p->enc_type == PGP ||  sapenc_p->enc_type == PKCS7 ) {
        hdr_len = sapenc_p->encd_len+ENC_HEADER_LEN+sapenc_p->pad_len;
        addata->length = sapenc_p->encd_len+sapenc_p->pad_len;
        if (addata->data != NULL) {
          free (addata->data);
        }
        addata->data = malloc(addata->length);
        memcpy(addata->data, sapenc_p->enc_data, addata->length);
      }
    }

/* asymm: addata->encrypt = 0, sapenc_p != NULL */
/*  symm: addata->encrypt = 1, sapenc_p == NULL (4=(2 priv_hdr + 2 padding) */
/* clear: addata->encrypt = 0, sapenc_p == NULL */

    if ( (addata->encrypt == 0) && (sapenc_p != NULL) ) {          /* asymm */
      newlen=sizeof(struct sap_header)+TIMEOUT+hdr_len;
    } else if ( (addata->encrypt == 1) && (sapenc_p == NULL)) {    /*  symm */
      newlen=sizeof(struct sap_header)+TIMEOUT+addata->length+4;
    } else {                                                       /* clear */
      newlen=sizeof(struct sap_header)+addata->length;
    }

/* create a new buffer and sap_header */
    
    buf = (char *)malloc(newlen);
    bp  = (struct sap_header *)malloc(sizeof(struct sap_header));

    bp->version  = 1;
    bp->type     = 0;
    bp->compress = 0;
    bp->authlen  = auth_len/4;
    bp->msgid    = 0;
    bp->src      = htonl(hostaddr);

/* asymmetric, symmetric and then clear */
/* copy the sap_header, priv_header and payload to buf */

    if ( (addata->encrypt == 1) || (sapenc_p != NULL) ) { 
      bp->enc = 1;
      memcpy(buf,bp,sizeof(struct sap_header));
      free(bp);

/* timeout field - always 0 at the moment */

    for (i=0; i<4; i++) {
      buf[sizeof(struct sap_header)+i]=0;
    }

/* add privacy header and data - 0 as we don't want an authentication header */
    
      privlen = add_privacy_header(buf,0,sapenc_p);

/* add data directly after generic hdr for asymm and after padded for symm */

      if (sapenc_p != NULL) {                                    /* asymm */
        memcpy(buf+sizeof(struct sap_header)+TIMEOUT+ENC_HEADER_LEN,
                addata->data,addata->length);
      } else {                                                   /*  symm */
        memcpy(buf+sizeof(struct sap_header)+TIMEOUT+privlen,
                addata->data,addata->length);
      }
      
    } else {

/* no encryption was used so just copy the sap_header and the payload */

      bp->enc = 0;
      memcpy(buf,bp,sizeof(struct sap_header));
      free(bp);
      memcpy(buf+sizeof(struct sap_header), addata->data, addata->length);   
    }

/* free up some internal variables */

    free(addata->data);
    addata->length = 0;

/* copy the temporary buf to the main new_data */

    memcpy(new_data,buf,newlen); 
    free(buf);
    
    return newlen;
}
/* ------------------------------------------------------------------- */
/* gen_new_auth_data - seems to :                                      */
/*  start with a full sap packet; sets bp->msg_id =0 and removes the   */
/*  auth_hdr (whilst leaving bp->authlen alone) and returns the new    */
/*  length of the new_data buffer (malloced outside)                   */
/* ------------------------------------------------------------------- */
int gen_new_auth_data(char *buf, 
                      char *new_data,
         struct sap_header *bp,
                      int  auth_len,
                      int  len)
{
  struct sap_header *bp1=NULL;
  char *newbuf=NULL, *sbuf=NULL;
  int newlen, lenrest;

  writelog(printf("entered gen_new_auth_data\n");)

/* copy bp to bp1, setting bp->msgid=0 */

  bp1 = (struct sap_header *)malloc(sizeof(struct sap_header));
  bp1->version  = bp->version;
  bp1->type     = bp->type;
  bp1->enc      = bp->enc;
  bp1->compress = bp->compress;
  bp1->authlen  = bp->authlen;
  bp1->src      = bp->src;
  bp1->msgid    = 0;

/* calculate the length without the authentication header and malloc buffer */

  newlen = len - auth_len;
  newbuf = (char *)malloc(newlen);

/* copy sap_header to start of newbuf and free temporary sap_header */

  memcpy((char *)newbuf,(char *)bp1,sizeof(struct sap_header));
  free(bp1);

/* copy everything else, missing out the auth header */

  lenrest = newlen - sizeof(struct sap_header);
  sbuf = (char *)buf+sizeof(struct sap_header)+auth_len;
  memcpy((char *)newbuf+sizeof(struct sap_header),(char *)sbuf,lenrest);

/* copy the whole lot to the new_data buffer and free the work buffer */

  memcpy((char *)new_data,newbuf,newlen);
  free(newbuf);

  return newlen;
}

/* --------------------------------------------------------------------- */
/* write_authentication - used for storing the authentication info of    */
/*                        non-encrypted announcements in the cache       */
/* --------------------------------------------------------------------- */
int write_authentication(char *afilename,char *data, int len, char *advertid)
{
  FILE *file=NULL;

  struct auth_header auth_hdr;
  struct sap_header *sap_hdr;
  struct advert_data *addata=NULL;
  struct advert_data *get_advert_info();

  char *filename;
  char tmpfilename[MAXFILENAMELEN];
  char *buf=NULL;
  char *tmpbuf=NULL, *newbuf=NULL;

  int total,newlen,len1;
  int i=0, auth_len=0;

#ifdef WIN32  /* need to sort out the ~ on windows */
  struct stat sbuf;
  Tcl_DString buffer;
  filename = Tcl_TildeSubst(interp, afilename, &buffer);
#else
  filename = afilename;
#endif

  writelog(printf(" -- entered write_authentication --\n");)

  addata = get_advert_info(advertid);

  if (addata  == NULL) {
    writelog(printf( "write_auth: error: advertid is not set\n");)
#ifdef WIN32
    Tcl_DStringFree(&buffer);
#endif
    return 1;
  }

/* set up the SDP payload in newbuf - this is used later on    */
/* need to skip the first part (to v=0) and the last (z=\n)    */

/* len=length of "n=...k=..\nv=...z=\n"; len1="n=...k=..\n"v=  */
/* newlen="v=...\n"z= ie SDP payload length                    */         

  tmpbuf = strchr(data,'v');
  len1   = tmpbuf - data;
  newlen = len-len1-3;
  newbuf = (char *)malloc(newlen);
  memcpy(newbuf,tmpbuf,newlen);

/* set up the authentication header */

  auth_hdr.auth_type = addata->authinfo->auth_type; 
  auth_hdr.padding   = addata->authinfo->padding; 
  auth_hdr.version   = addata->authinfo->version; 
  auth_hdr.siglen    = addata->authinfo->siglen; 

  if (addata->authinfo != NULL) {
    auth_len = addata->authinfo->key_len 
               + addata->authinfo->sig_len 
               + addata->authinfo->pad_len
               + AUTH_HEADER_LEN;
  }

/* malloc the main buffer */

  total = len + sizeof(struct sap_header) + auth_len + newlen;
  buf = (char *)malloc(total);

  writelog(printf("write_auth: malloced: len(%d) + sap_hdr(%d) + auth_len(%d) + newlen(%d) = total(%d)\n",len,sizeof(struct sap_header),auth_len,newlen,total);)

/* write the data (starting "n=...v=...z=\n"to the buffer */

  memcpy(buf,data,len);

/* Note that we now write the full sap packet to the cache as well */
/* ie sap_header, auth_header, payload                             */

/* write the sap header into the buffer                            */

  sap_hdr = addata->sap_hdr;

  if( sap_hdr == NULL) {

    sap_hdr = (struct sap_header *)malloc(sizeof(struct sap_header));
    sap_hdr->version  = 1;
    sap_hdr->authlen  = auth_len /4;	
    sap_hdr->enc      = 0;
    sap_hdr->compress = 0;
    sap_hdr->msgid    = 0;
    sap_hdr->src      = htonl(hostaddr);

    memcpy(buf+len,sap_hdr,sizeof(struct sap_header));
    len += sizeof(struct sap_header);
    free(sap_hdr);

  } else {
    memcpy(buf+len,sap_hdr,sizeof(struct sap_header));
    len += sizeof(struct sap_header);
  }

  if (auth_len !=0) {

/* copy auth header to buffer */

    memcpy(buf+len,&auth_hdr,AUTH_HEADER_LEN);
    len += AUTH_HEADER_LEN;

/* copy signature to buffer */

    memcpy(buf+len,addata->authinfo->signature,addata->authinfo->sig_len);
    len += addata->authinfo->sig_len;

/* copy key certificate to buffer */
/* obsolete - will be removed     */

    if(addata->authinfo->auth_type==authPGPC ) {
      memcpy(buf+len,addata->authinfo->keycertificate,addata->authinfo->key_len);
      len+=addata->authinfo->key_len;
    }

/* copy padding to the buffer */

    if (addata->authinfo->pad_len != 0) {
      for (i=0; i<(addata->authinfo->pad_len-1); ++i) {
	buf[len+i] = 0;
      }
      buf[len+i] = addata->authinfo->pad_len;
      len += addata->authinfo->pad_len;
    }

  }

/* copy data to the buffer */

  memcpy(buf+len,newbuf,newlen);
  len += newlen;
  free(newbuf);

/* set up and open file for output */

  strcpy(tmpfilename,filename);
  strcat(tmpfilename, ".tmp");
  file=fopen(tmpfilename, "w");

#ifdef WIN32
  chmod(tmpfilename, _S_IREAD|_S_IWRITE);
#else
  chmod(tmpfilename, S_IRUSR|S_IWUSR);
#endif

/* make very sure we've really succeeded in writing this...*/

  if (file==NULL) {
    return -1;
  }

  if (fwrite(buf, 1, len, file)!=len) {
    return -1;
  }

  if (fclose(file)!=0) {
    return -1;
  }

/* can now get rid of the buffer */

  free(buf);

#ifdef WIN32   /* need to remove file first on windows or rename fails */
  if (stat(filename, &sbuf) != -1) {
    remove(filename);
  }
  rename(tmpfilename, filename);
  Tcl_DStringFree(&buffer);
#else
  rename(tmpfilename, filename);
#endif
  return 0;
}

/* --------------------------------------------------------------------- */
/* write_encryption    - used for storing the encryption info of         */
/*                       encrypted (asymm) announcements in the cache    */
/*                       also writes auth info for these announcements   */
/* shouldn't be in sd_listen.c - move to polluted.c                      */
/* --------------------------------------------------------------------- */
int write_encryption(char *afilename, char *data, int len , char *auth_type, char *enc_type,char *advertid)
{
  FILE *file;
  struct sap_header *bp=NULL;
  struct advert_data *addata=NULL;
  struct priv_header *sapenc_p=NULL;
  struct auth_header *auth_hdr=NULL;
  struct auth_info *authinfo=NULL;
  char *filename;
  char tmpfilename[MAXFILENAMELEN];
  char *buf=NULL;
  int i=0, auth_len=0;
  int hdr_len=0;
  int orglen;
  int packetlength=0;
  struct advert_data *get_advert_info();

#ifdef WIN32  /* need to sort out the ~ on windows */
  struct stat sbuf;
  Tcl_DString buffer;
  filename = Tcl_TildeSubst(interp, afilename, &buffer);
#else
  filename = afilename;
#endif

  writelog(printf(" -- entered write_encryption (filename = %s)\n",afilename);)

/* get the information for the advert */

  addata = get_advert_info(advertid);
  if (addata  == NULL) {
    writelog(printf( "write_enc: error: addata = NULL\n");)
#ifdef WIN32
  Tcl_DStringFree(&buffer);
#endif
    return 1;
  }

/* set up authentication header and length */

  authinfo = addata->authinfo; 

  if (authinfo != NULL) {
    auth_len = authinfo->key_len+authinfo->sig_len+authinfo->pad_len+AUTH_HEADER_LEN;
    auth_hdr = (struct  auth_header *)malloc(AUTH_HEADER_LEN);
    auth_hdr->auth_type = authinfo->auth_type;
    auth_hdr->padding   = authinfo->padding;
    auth_hdr->version   = authinfo->version;
    auth_hdr->siglen    = authinfo->siglen;
  }

/* set up privacy header and length */

  sapenc_p = addata->sapenc_p;
  hdr_len  = sapenc_p->hdr_len * 4;

/* malloc the output buffer - not we have the plain data followed by the */
/* full SAP packet                                                       */

  packetlength = sizeof(struct sap_header)+auth_len+TIMEOUT+hdr_len;
  buf = (char *)malloc(len+packetlength);

/* debug */

  writelog(printf("write_enc: malloced: len(%d) + sizeof sap_hdr(%d) + auth_len(%d) + T/O(%d) + hdr_len(%d) = %d\n",len,sizeof(struct sap_header),auth_len,TIMEOUT,hdr_len,(len+sizeof(struct sap_header)+auth_len+TIMEOUT+hdr_len));)

/* copy plain data to the buffer */

  memcpy(buf,data,len);

/* set up sap header */

  bp = addata->sap_hdr;

  if (bp == NULL) {
    bp=malloc(sizeof(struct sap_header));
    bp->version  = 1;
    bp->authlen  = auth_len /4;	
    bp->enc      = 1;
    bp->compress = 0;
    bp->msgid    = 0;
    bp->src      = (unsigned long)htonl(hostaddr);
  }

/* debug */

  writelog(printf("write_enc: bp: version=%d type=%d enc=%d compress=%d authlen=%d msgid=%d src=%lu\n",bp->version, bp->type, bp->enc, bp->compress, bp->authlen, bp->msgid, bp->src);)

/* copy sap header to the buffer */

  memcpy((char *)buf+len,(char *)bp,sizeof(struct sap_header));

  orglen = len;
  len += sizeof(struct sap_header);

/* copy authentication info to the buffer */

  if(auth_len != 0) {

/* auth header */

    memcpy(buf+len,auth_hdr,AUTH_HEADER_LEN);
    len += AUTH_HEADER_LEN;
    free(auth_hdr);

/* signature */

    memcpy(buf+len, authinfo->signature,authinfo->sig_len);
    len += authinfo->sig_len;

/* certificate - obsolete and will be removed */

    if(authinfo->auth_type==authPGPC || authinfo->auth_type==authX509C) {
      memcpy(buf+len,authinfo->keycertificate,authinfo->key_len);
      len += authinfo->key_len;
    }

/* padding for auth header */

    if (authinfo->pad_len != 0) {
      for (i=0; i<(authinfo->pad_len-1); ++i) {
        buf[len+i] = 0;
      }                          
    } 

    buf[len+i] = authinfo->pad_len;
    len += authinfo->pad_len;
  }

/* Authentication information has been added               */ 
/* Now add the timeout field - always 0 at the moment      */

  for (i=0; i<4; i++) {
    buf[orglen+sizeof(struct sap_header)+auth_len+i]=0;
  }
  len += TIMEOUT;

/* copy the generic privacy header */

  memcpy(buf+len, sapenc_p, ENC_HEADER_LEN);
  len += ENC_HEADER_LEN;

/* copy the encrypted data */

  memcpy(buf+len, sapenc_p->enc_data, sapenc_p->encd_len+sapenc_p->pad_len);
  len += sapenc_p->encd_len+sapenc_p->pad_len;

/* I think the padding bytes etc are already in sapenc_p->enc_data   */

/* set up the output filename and open it */

  strcpy(tmpfilename, filename);
  strcat(tmpfilename, ".tmp");
  file=fopen(tmpfilename, "w");
#ifdef WIN32
  chmod(tmpfilename, _S_IREAD|_S_IWRITE);
#else
  chmod(tmpfilename, S_IRUSR|S_IWUSR);
#endif

/* make very sure we've really succeeded in writing this */

  if (file==NULL) return -1;
    if (fwrite(buf, 1, len, file)!=len) {
      printf("error - 1\n");
      return -1;
    }
    if (fclose(file)!=0) return -1;
#ifdef WIN32   
/* need to remove file first on windows or rename fails */
  if (stat(filename, &sbuf) != -1) {
    remove(filename);
  }
  rename(tmpfilename, filename);
  Tcl_DStringFree(&buffer);
#else
  rename(tmpfilename, filename);
#endif
  return 0;
}
