/*
 * Copyright (c) 1996 University College London
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by the Computer Science
 *      Department at University College London
 * 4. Neither the name of the University nor of the Department may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE UNIVERSITY OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/types.h>
#include "sdr.h"
#include "sap_crypt.h"
#include "crypt.h"
#include "md5.h"
#include "prototypes.h"
#ifdef AUTH
#include "prototypes_crypt.h"
#endif

static int getseed();
static int goodkey(char *key, int *seed);
static int isgoodkey(char key[8]);

static struct {
        u_char key[8];
}       keytable[] = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
 
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
        0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE,
 
        0x1F, 0x1F, 0x1F, 0x1F, 0x0E, 0x0E, 0x0E, 0x0E,
        0xE0, 0xE0, 0xE0, 0xE0, 0xF1, 0xF1, 0xF1, 0xF1,
 
        0x01, 0xFE, 0x01, 0xFE, 0x01, 0xFE, 0x01, 0xFE,
        0xFE, 0x01, 0xFE, 0x01, 0xFE, 0x01, 0xFE, 0x01,
 
        0x1F, 0xE0, 0x1F, 0xE0, 0x0E, 0xF1, 0x0E, 0xF1,
        0xE0, 0x1F, 0xE0, 0x1F, 0xF1, 0x0E, 0xF1, 0x0E,
 
        0x01, 0xE0, 0x01, 0xE0, 0x01, 0xF1, 0x01, 0xF1,
        0xE0, 0x01, 0xE0, 0x01, 0xF1, 0x01, 0xF1, 0x01,
  
        0x1F, 0xFE, 0x1F, 0xFE, 0x0E, 0xFE, 0x0E, 0xFE,
        0xFE, 0x1F, 0xFE, 0x1F, 0xFE, 0x0E, 0xFE, 0x0E,
 
        0x01, 0x1F, 0x01, 0x1F, 0x01, 0x0E, 0x01, 0x0E,
        0x1F, 0x01, 0x1F, 0x01, 0x0E, 0x01, 0x0E, 0x01,
 
        0xE0, 0xFE, 0xE0, 0xFE, 0xF1, 0xFE, 0xF1, 0xFE,
        0xFE, 0xE0, 0xFE, 0xE0, 0xFE, 0xF1, 0xFE, 0xF1
};

struct keydata* keylist;
char passphrase[MAXKEYLEN];
extern Tcl_Interp *interp;

#ifdef WIN32
/* need to set this so can handle binary files okay */
extern int _fmode=_O_BINARY;
#endif

/*#define DEBUG*/

int set_pass_phrase(char *newphrase)
{
  strncpy(passphrase, newphrase, MAXKEYLEN);
  return 0;
}

char *get_pass_phrase()
{
  return passphrase;
}

/* ----------------------------------------------------------------- */
/* encrypt_announcement: DES encryption - calls Encrypt()            */
/* ----------------------------------------------------------------- */
int encrypt_announcement(char *srcbuf, char **dstbuf, int *length,
                         char *key)
{

  writelog(printf(" -- entered encrypt_announcement --\n");)

/* set the encryption key */

  Set_Key(key);

/* do the encryption */

  writelog(printf("pre-encr len: %d\n", *length);)
  *dstbuf=(u_char*)Encrypt(srcbuf, length);
  writelog(printf("post-encr len: %d\n", *length);)

  return 0;
}

/* ----------------------------------------------------------------- */
/* decrypt_announcement: DES decryption - calls Decrypt()            */
/* ----------------------------------------------------------------- */
int decrypt_announcement(char *buf, int *len, char *recvkey)
{
  char key[MAXKEYLEN];
  char *dstbuf, *origbuf;
  struct enc_header *enchead;
  struct keydata *tmpkey=keylist;
  int length=0;

  writelog(printf(" -- entered decrypt_announcement --\n");)

/* should now have buf pointing to start of encrypted payload */
/* and len being the length of this payload                   */

  origbuf=(char *)malloc(*len);
  memcpy(origbuf,buf,*len);          /* decrypt splats buffer so save it */
  enchead=(struct enc_header *)buf;

/* No longer have key id so loop through all keys trying to decrypt buffer */

  while(tmpkey != NULL) {
    strncpy(key, tmpkey->key, MAXKEYLEN);
    memcpy(buf,origbuf,*len);

    writelog(printf("setting key: %s\n", key);)
    Set_Key(key);
    writelog(printf("..done\n");)

    dstbuf=malloc(*len);

/* DES: need +4 to skip the generic priv_hdr (2 bytes) + 2 padding bytes */

    writelog(printf("pre-decrypt     len: %d\n", *len-4);)
    length=Decrypt(buf+4, dstbuf, (*len)-4);
    writelog(printf("post-decrypt length: %d\n", length);)

    if (length != -1) {
      if (strncmp(dstbuf, "v=", 2)==0) {
        writelog(printf(" ** decryption succeeded with key >%s< **\n",key);)
        *len = length;
        strncpy(recvkey, key, MAXKEYLEN);
        memcpy(buf, dstbuf, *len);
        buf[*len]='\0';
        free(origbuf);
        return 0;
      } else {
        writelog(printf(" ** decryption failed with key >%s< **\n",key);)
      }
    } 
    tmpkey=tmpkey->next;
  }

/* if reach here then decryption has failed */

  writelog(printf("** decryption failed with all keys - returning -1 **\n");)
  return -1;
}
 
int get_sdr_home(char str[])
{
#ifdef WIN32
/* need to take care of the ~ on Windows */
  char *filename, *tmpstr;
  Tcl_DString buffer;
  filename = malloc(MAXFILENAMELEN);
 
  announce_error(Tcl_GlobalEval(interp, "resource sdrHome"),
             "resource sdrHome");
  strcpy(filename, interp->result);
  tmpstr = Tcl_TildeSubst(interp, filename, &buffer);
  str = strcpy(str, tmpstr);
  Tcl_DStringFree(&buffer);
  free(filename);
#else
  announce_error(Tcl_GlobalEval(interp, "resource sdrHome"),
		 "resource sdrHome");
  strcpy(str, interp->result);
#endif
  return 0;
}

/* ------------------------------------------------------------------- */
/* find_keyname_by_key - have key, find keyname                        */ 
/* ------------------------------------------------------------------- */
int find_keyname_by_key(char *key, char *keyname)
{  
  struct keydata *tmpkey=keylist;
 
  while(tmpkey!=NULL)
    {
      if (strncmp(tmpkey->key,key, MAXKEYLEN)==0)
        {
          strncpy(keyname, tmpkey->keyname, MAXKEYLEN);
          return 0;
        }
      tmpkey=tmpkey->next;
    }
  return -1;
}

/* ------------------------------------------------------------------- */
/* find_key_by_name - have keyname, find key                           */ 
/* ------------------------------------------------------------------- */
int find_key_by_name(char *keyname, char *key)
{
  struct keydata *tmpkey=keylist;

  while(tmpkey!=NULL)
    {
      if (strncmp(tmpkey->keyname,keyname, MAXKEYLEN)==0)
	{
	  strncpy(key, tmpkey->key, MAXKEYLEN);
	  return 0;
	}
      tmpkey=tmpkey->next;
    }
  return -1;
}


int register_key(char *key, char *keyname)
{
  struct keydata *tmpkey=keylist;
#ifdef DEBUG
  printf("key: %s\nkeyname:%s\n", key, keyname);
#endif

  /*Check that there isn't already a key with this name*/
  while(tmpkey!=NULL)
    {
      if (strcmp(tmpkey->keyname, keyname)==0)
	{
	  fprintf(stderr, "Duplicate Key Register attempt: %s\n",
		  tmpkey->keyname);
	  return -1;
	}
      tmpkey=tmpkey->next;
    }

  if (keylist==NULL)
    {
      keylist=malloc(sizeof(struct keydata));
      keylist->next=NULL;
      keylist->prev=NULL;
    }
  else
    {
      keylist->prev=malloc(sizeof(struct keydata));
      keylist->prev->next=keylist;
      keylist->prev->prev=NULL;
      keylist=keylist->prev;
    }
  memset(keylist->keyname, MAXKEYLEN, 0);
  memset(keylist->key, MAXKEYLEN, 0);
  strncpy(keylist->keyname, keyname, MAXKEYLEN);
  strncpy(keylist->key, key, MAXKEYLEN);
  keylist->starttime=1;
  keylist->endtime=2;
  keylist->keyversion=3;
  return 0;
}


int delete_key(char *keyname) 
{
  struct keydata *tmpkey=keylist;

  while(tmpkey!=NULL)
    {
      if (strcmp(tmpkey->keyname, keyname)==0)
	{
	  if (tmpkey->prev!=NULL) 
	    tmpkey->prev->next = tmpkey->next;
	  if (tmpkey->next!=NULL) 
	    tmpkey->next->prev = tmpkey->prev;
	  if (tmpkey==keylist)
	    keylist=tmpkey->next;
	  free(tmpkey);
	  save_keys();
	  return 0;
	}
      tmpkey=tmpkey->next;
    }
  return -1;
}

int save_keys(void)
{
  char *buf;
  struct keyfile *p;
  struct keydata *tmpkey=keylist;
  int no_of_keys=0;
  char keyfilename[MAXFILENAMELEN];
  int len, i;

  /*no passphrase was entered - don't save!*/
  if (strcmp(passphrase, "")==0) return 0;
#ifdef DEBUG
  printf("passphrase: %s\n", passphrase);
#endif

  /*how many keys do we have*/
  while(tmpkey!=NULL)
    {
      no_of_keys++;
      tmpkey=tmpkey->next;
    }
#ifdef DEBUG
  printf("saving %d keys\n", no_of_keys);
#endif
  if (no_of_keys==0) return 0;
  len=24+(no_of_keys*(sizeof(struct keyfile)));
  buf=malloc(len);
#ifdef DEBUG
  printf("len=%d\n", len);
#endif
  p=(struct keyfile *)buf;
  tmpkey=keylist;
  for(i=0;i<no_of_keys;i++)
    {
      p->keyversion = htonl(tmpkey->keyversion);
      p->starttime = htonl(tmpkey->starttime);
      p->endtime = htonl(tmpkey->endtime);
      memcpy(p->key, tmpkey->key, MAXKEYLEN);
      memcpy(p->keyname, tmpkey->keyname, MAXKEYLEN);
      p++;
      tmpkey=tmpkey->next;
    }

  get_sdr_home(keyfilename);
#ifdef WIN32
  strcat(keyfilename, "\\keys");
#else
  strcat(keyfilename, "/keys");
#endif

  write_crypted_file(keyfilename, buf,
                     no_of_keys*(sizeof(struct keyfile)), passphrase,
                     "none", NULL);

  free(buf);
  load_keys();
  return 0;
}

int load_keys(void)
{
  struct keydata *delkey, *tmpkey=keylist, *addkey;
  char keyfilename[MAXFILENAMELEN];
  struct stat sbuf;
  int i, len;
  u_char *buf;
  struct keyfile *p;

#ifdef DEBUG
  printf("loading keys...\n");
#endif

  get_sdr_home(keyfilename);
#ifdef WIN32
  strcat(keyfilename, "\\keys");
#else
  strcat(keyfilename, "/keys");
#endif

  stat(keyfilename, &sbuf);
  buf=malloc(sbuf.st_size);

  len=load_crypted_file(keyfilename, buf, passphrase);
  if (len<0)
    return -1;

  p=(struct keyfile *)buf;
  /*if this is a re-load, clear out state first*/
  if (keylist!=NULL) 
    {
      while(tmpkey!=NULL)
	{
	  delkey=tmpkey;
	  tmpkey=tmpkey->next;
	  free(delkey);
	}
    }
  keylist=NULL;
  tmpkey=NULL;
  for(i=0;i<len/(sizeof(struct keyfile));i++)
    {
      addkey=malloc(sizeof(struct keydata));
      if(tmpkey!=NULL) 
	tmpkey->next=addkey;
      else   
	keylist=addkey;
      addkey->prev=tmpkey;
      addkey->next=NULL;
      addkey->keyversion=htonl(p[i].keyversion);
      addkey->starttime=htonl(p[i].starttime);
      addkey->endtime=htonl(p[i].endtime);
      memcpy(addkey->key, p[i].key, MAXKEYLEN);
      memcpy(addkey->keyname, p[i].keyname, MAXKEYLEN);
#ifdef DEBUG
      printf("key: %s\n", p[i].key);
      printf("keyname: %s\n", p[i].keyname);
#endif
      announce_error(Tcl_VarEval(interp, "install_key \"", 
				 addkey->keyname, "\"", NULL), "install_key");
      tmpkey=addkey;
    }
  free(buf);
  return 0;
}
extern unsigned long hostaddr;

/* ---------------------------------------------------------------------- */
/* write_crypted_file - writes encrypted file to cache or keyfile         */
/* can this not be simplified a lot by calling build_packet() ?           */
/* ---------------------------------------------------------------------- */
int write_crypted_file(char *afilename, char *data, int len, char *key,
                       char *auth_type, char *advertid)
{
  FILE *file;
  MD5_CTX context;
  struct timeval tv;
  struct advert_data *addata=NULL;
  struct  advert_data *get_advert_info();	
  struct auth_info *authinfo=NULL;
  struct auth_header *auth_hdr;
  struct sap_header *bp=NULL;
  struct priv_header *priv_hdr=NULL;

  char *ap=NULL;
  char *filename;
  char *buf=NULL, *encbuf=NULL, *p=NULL;
  char tmpfilename[MAXFILENAMELEN];
  u_char hash[16];

  int auth_len=0,bplen,i=0;
  int des_enc_hdrlen;
  int orglen;

#ifdef WIN32  /* need to sort out the ~ on windows */
  struct stat sbuf;
  Tcl_DString buffer;
  filename = Tcl_TildeSubst(interp, afilename, &buffer);
#else
  filename = afilename;
#endif

  writelog(printf(" -- entered write_crypted_file (filename = %s) --\n",afilename);)

/*  no passphrase was entered - don't save!  */

  if (strcmp(key, "")==0) {
    return 0;
  }

  writelog(printf("passphrase: %s\n", key);)

/* If the announcement contains authentication information then write    */
/* this data to the file, before it is encrypted.                        */
 
  if (strcmp(auth_type, "none") !=0 ) {
 
/* Obtains the key certificate and signature info for the advert */

    addata = get_advert_info(advertid);
    if (addata  == NULL) {
      writelog(printf( "write_crypted_file: error: addata is NULL\n");)
      return 1;
    }
    authinfo = addata->authinfo;

/* if debugging have a look at the auth header */

    writelog(printf("wcf: auth_hdr: version = %d, padding = %d, auth_type = %d, siglen = %d\n",authinfo->version, authinfo->padding, authinfo->auth_type, authinfo->siglen);)

/* authPGPC is obsolete and will be removed */

    if (authinfo != NULL) {
      auth_len = authinfo->sig_len+authinfo->pad_len+AUTH_HEADER_LEN;
    }

/* set up the sap header */

    bp = addata->sap_hdr;

    if (bp == NULL) {
      bp=malloc(sizeof(struct sap_header));
      bp->version  = 1;
      bp->authlen  = auth_len /4;
      bp->enc      = 1;
      bp->compress = 0;
      bp->msgid    = 0;
      bp->src      = htonl(hostaddr);
    }

/* if debugging have a look at the sap header */

    writelog(printf("wcf: bp: version=%d type=%d enc=%d compress=%d authlen=%d msgid=%d src=%lu\n",bp->version, bp->type, bp->enc, bp->compress, bp->authlen, bp->msgid, bp->src);)

/* des encryption header is 4 - 2 bytes for enc header and 2 padding bytes */

    des_enc_hdrlen = 4;

/* malloc the buffer */

    orglen = len;
    buf = (char *)malloc(len+24+sizeof(struct sap_header)+auth_len+TIMEOUT+des_enc_hdrlen+addata->length);

/* copy data to buf - note 1st 24 bytes are for checksum   */
/* data is "n=......k=keyhere\nv=0......\nz="              */
/* also note that a full sap packet is appended after z=\n */

    memcpy(buf+24, data, len);

/* copy sap_header following "z="   */

    memcpy(buf+24+len, bp,sizeof(struct sap_header));
    bplen = sizeof(struct sap_header);

/* copy authentication header (2nd byte = signature length) */

    auth_hdr = (struct auth_header *)malloc(AUTH_HEADER_LEN);

    auth_hdr->version   = authinfo->version;
    auth_hdr->padding   = authinfo->padding;
    auth_hdr->auth_type = authinfo->auth_type;
    auth_hdr->siglen    = authinfo->siglen;

    memcpy(buf+24+len+bplen, (char *)auth_hdr, AUTH_HEADER_LEN);
    free(auth_hdr);

/* copy signature to buf */

    memcpy(buf+24+len+bplen+AUTH_HEADER_LEN, authinfo->signature, authinfo->sig_len);
    len+=(bplen+AUTH_HEADER_LEN+authinfo->sig_len);

/* add the padding */

    if (authinfo->pad_len != 0) {
      for (i=0; i<(authinfo->pad_len-1); ++i) {
	buf[len+24+i] = 0;
      }
    }
    buf[len+24+i] = authinfo->pad_len;
    len+=authinfo->pad_len;

/* add a 4 byte timeout field as the data is encrypted (this should be */
/* changed to a proper timeout instead of 0 sometime                   */

    for (i=0; i<4; i++) {
      buf[len+24+i]=0;
    }
    len += 4;

/* add the privacy header */

    priv_hdr = (struct priv_header *)malloc(sizeof(struct priv_header));
    priv_hdr->version  = 1;
    priv_hdr->padding  = 1;
    priv_hdr->enc_type = DES;
    priv_hdr->hdr_len  = 1;    /* No. of 32 bit words in privacy header   */

    memcpy(buf+24+len,priv_hdr,ENC_HEADER_LEN);
    free(priv_hdr);

/* add the padding bytes for the des header */

    ap = (char *)buf+24+len+ENC_HEADER_LEN;
    ap[0] = 0;
    ap[1] = 2;

    len += des_enc_hdrlen;

/* add the data */

    memcpy(buf+24+len,addata->data,addata->length);
    len += addata->length;

  } else {

/* if there is no authentication just copy the data */

    buf=malloc(len+24+8);
    memcpy(buf+24, data, len);
  }

  p=(buf+24);

  /*We need as much unpredictable information as possible to serve to
    assist the IV (OK, so the IV should be unpredictable anyway as we
    get it from the pass phrase, but this doesn't hurt any, and may
    help with weak choices of pass phrase).  Time is predictable to a
    degree so not useful by itself.  The keys in the file aren't, so
    MD5 this lot together, then XOR in any other randomness we can
    collect along the way (particularly from user inputs).*/

  gettimeofday(&tv, NULL);
  MD5Init(&context);
  MD5Update(&context, (u_char*)p, len);
  MD5Final((u_char *)hash, &context);
  memcpy(buf, hash, 8);
  ((int*)buf)[0]^=tv.tv_usec;

/* Add the MD5 hash so that when we decrypt we know it was the correct */
/* pass_phrase                                                         */

  memcpy(buf+8, hash, 16);

  Set_Key(passphrase);

#ifdef NOTDEF
  if ((len&0x07)!=0) 
    padding=1;
  else
    padding=0;
  buf[0]=(buf[0]&0xfe)|padding;
#ifdef DEBUG
  printf("encrypted padding=%d\n", padding);
#endif
#endif

  len+=24;

  encbuf=Encrypt(buf, &len);
  free(buf);
#ifdef NOTDEF
  printf("encrypted len=%d, padding=%d\n",len, padding);
#endif

  /*save to a tmp file first to prevent corruption in the case we get
    killed before we finish*/
  strcpy(tmpfilename, filename);
  strcat(tmpfilename, ".tmp");
  file=fopen(tmpfilename, "w");

#ifdef WIN32
  chmod(tmpfilename, _S_IREAD|_S_IWRITE);
#else
  chmod(tmpfilename, S_IRUSR|S_IWUSR);
#endif

  /*make very sure we've really succeeded in writing this...*/
  if (file==NULL) return -1;
  if (fwrite(encbuf, 1, len, file)!=len) return -1;
  if (fclose(file)!=0) return -1;
  
  /*move install the new keyfile (should be atomic on Unix...)*/
  /*I could check the return from this, but I don't really know
    what recovery I can take if it actually fails!*/

#ifdef WIN32   /* need to remove file first on windows or rename fails */
  if (stat(filename, &sbuf) != -1)
  {
    remove(filename);
  }
  rename(tmpfilename, filename);
  Tcl_DStringFree(&buffer);
#else
  rename(tmpfilename, filename);
#endif

  return 0;
}

/* ----------------------------------------------------------------------- */
/* load_crypted_file - load a crypted file - either keyfile or cache       */
/* ----------------------------------------------------------------------- */
int load_crypted_file(char *afilename, char *buf, char *key)
{
  FILE *file;
  struct stat sbuf;
  int i, correct, len;
  u_char hash[16];
  u_char *encbuf;
  u_char *clearbuf;
  char *p=NULL;
  char *filename;
  MD5_CTX context;
#ifdef WIN32  /* need to sort out the ~ on windows */
  Tcl_DString buffer;
  filename = Tcl_TildeSubst(interp, afilename, &buffer);
#else
  filename = afilename;
#endif

  writelog(printf(" -- entered load_crypted_file (filename = %s) -- \n",filename);)

  file=fopen(filename, "r");
  if (file==NULL) return -1;
  stat(filename, &sbuf);
  encbuf=malloc(sbuf.st_size);
  if (fread(encbuf, 1, sbuf.st_size, file)!=sbuf.st_size)
    {
      fclose(file);
      free(encbuf);
      return -1;
    }
  fclose(file);

#ifdef WIN32
  Tcl_DStringFree(&buffer);
#endif

  Set_Key(key);
  clearbuf=malloc(sbuf.st_size);
#ifdef DEBUG
  printf("len=%d\n", (int)sbuf.st_size);
#endif
  len=Decrypt(encbuf, clearbuf, sbuf.st_size);

  if (len>0) 
    {
      p=clearbuf+24;
      len-=24;
      /*Check that the passphrase given was correct*/
      MD5Init(&context);
      MD5Update(&context, (u_char*)p, len);
      MD5Final((u_char *)hash, &context);
      correct=1;
      for(i=0;i<16;i++)
	if (hash[i]!=clearbuf[i+8]) correct=0;
    }
  else 
    {
      /*don't need to check the MD5 hash - the padding told Decrypt that
        the key was wrong*/
      correct=0;
    }

  if (correct==0)
    {
      strcpy(passphrase, "");
#ifdef DEBUG
      printf("passphrase incorrect\n");      
#endif
      return -1;
    }
  memcpy(buf, p, len);
  free(clearbuf);
  free(encbuf);
  return len;
}

int make_random_key()
{
  u_char hash[16];
  int seed, havegoodkey=0;
  char *key, *newkey;
  MD5_CTX context;

  key    = (char *)malloc(16);
  newkey = (char *)malloc(24);

  while (havegoodkey == 0 ){

/* get random 16 byte key */

    seed = getseed();
    (void) goodkey(&key[0], &seed);
    (void) goodkey(&key[8], &seed);
 
/* take MD5 hash of the 16 bit key */

    MD5Init(&context);
    MD5Update(&context, (u_char *)key, (u_int)16);
    MD5Final((u_char *)hash, &context);

/* convert the 16 byte hash to base 64 */

    bin_to_b64_aux(hash, 16, &newkey);

/*change the last == to be \0= so we have a string terminator. Actually leave */
/*off the last character as it is always A,w,Q or g as the last 4 bits of the */
/*final 6 bit value are 0                                                     */
 
    newkey[21] = '\0';
 
/*now check the key doesn't have any "/" in it as vat doesn't like them       */
/*some tools don't like other characters eg ",\,` and $ but as this is base64 */
/*encoded we don't have them anyway and we check the key again later on       */
 
    if ( strchr((const char *)newkey, '/') == NULL ) {
        havegoodkey = 1;
    }
 
  }
/* now have a good key so set the tcl $tempkey variable up and tidy up */

  Tcl_SetVar(interp, "tempkey", newkey, TCL_GLOBAL_ONLY);

  free (key);
  free (newkey);

  return OK;
 
}

static int getseed()
{
  int    prid, seed;
  time_t curtime, time();
 
  prid = getpid();
  (void) time(&curtime);
  seed = (int) curtime;
 
  seed = (seed & ~0x0000) | (prid << 16);
  return (seed);
}
 
static int goodkey(char *key, int *seed)
{
  (void) sec_randomkey((char *)key, seed);
  while (isgoodkey(key) == NOTOK)
    (void) sec_randomkey((char *)key, seed);
 
  return (OK);
}
 
/* Weed out bad keys or keys with '*' in them */
 
static int isgoodkey(key)
   char            key[8];
{
   int             i;
   int             j;
 
   for (i = 0; i < 18; i++) {
     for (j=0; j<8;j++){
     }
     if (strncmp((char *)key, (char *)(keytable[i].key), 8) == 0) {
       return (NOTOK);
     }
   }
   for (i = 0; i < 8; i++) {
     if (key[i] == '*')
       return (NOTOK);
   }
   return (OK);
}

/* ------------------------------------------------------------------------- */
/* Function:      ToBase64                                                   */
/*                                                                           */
/* Description:   Encode u_chars in Base64 as per MIME (RFC-1521)            */
/*                The routine will read as much of the input as is needed    */
/*                to fill the output, advancing the pointers in the input    */
/*                as it is used. Note that if you wish to call this with     */
/*                more than one input buffer, each call should provide       */
/*                a multiple of 3 u_chars, otherwise you will get padding    */
/*                at an intermediate stage.                                  */
/*                                                                           */
/*                The output buffer is only filled with 4 character sets.    */
/*                                                                           */
/* Parameters:    Pointer to pointer into input buffer                       */
/*                Pointer to length of input buffer remaining                */
/*                Pointer to output buffer                                   */
/*                Length of output buffer                                    */
/*                                                                           */
/* Return Value:  Number of u_chars written to output buffer                 */
/*                                                                           */
/* ------------------------------------------------------------------------- */
 
int ToBase64(
    unsigned char **inbp, /* pointer to pointer into input buffer */
    int *ilen,            /* pointer to number of u_chars remaining input */
    char *outbuff,        /* pointer to output buffer */
    int olen              /* max size of output buffer */
)
{
    unsigned char *bp = *inbp;
    int len   = *ilen;
    int count;
 
    static char Base64[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
 
#define PAD64 '='
 
    olen -= 4;
 
    for ( count = 0; len > 0 && count <= olen; count += 4, outbuff += 4 ) {
        unsigned long val;
 
        val = (*bp++) << 8;
        len -= 2;
        if ( len >= 0 )
            val += *bp++;
        val <<= 8;
        if ( --len >= 0 )
            val += *bp++;
 
        outbuff[3] = Base64[val & 0x3f];
        val >>= 6;
        outbuff[2] = Base64[val & 0x3f];
        val >>= 6;
        outbuff[1] = Base64[val & 0x3f];
        val >>= 6;
        outbuff[0] = Base64[val & 0x3f];
    }

 
    /* Adjust at end of source */
    switch ( len ) {
    case -2:
        outbuff[-2] = PAD64;
        /* falls through */
    case -1:
        outbuff[-1] = PAD64;
        len = 0;
        break;
    }
 
    *ilen = len;
    *inbp = bp;
 
    return count;
}
 
/* ------------------------------------------------------------------------- */
/*  bin_to_b64_aux                                                           */
/*                                                                           */
/* Conversion routine to Base-64 : 3 binary octets to 4 Base-64 chars        */
/*                                                                           */
/* in           input binary data                                            */
/* inlen        length of input in u_chars                                   */
/* cpp          where to place pointer to newly alloc'd return data          */
/*                                                                           */
/* returns number of output u_chars (not including zero terminator),         */
/* or 0 on error (*cpp not valid)                                            */
/* ------------------------------------------------------------------------- */
int bin_to_b64_aux(u_char *in,int inlen,char **cpp /* Returned */)
{
  int             nc;
  int             b64len = ((inlen + 2)/3) * 4 ;
  char           *cp;
 
  cp = (char *)calloc(1, (unsigned)b64len+1);
 
  if (cp == NULL) {
    printf("bin_to_b64_aux() out of memory\n");
    *cpp = NULL;
    return 0;
  }
 
  nc = ToBase64(&in, &inlen, cp, b64len);
 
  if (nc == 0) {
    free(cp);      /* no use to us, free it */
    *cpp = NULL;
  } else {
    cp[nc] = '\0'; /* zero terminator */
    *cpp = cp;
  }
 
  return nc;
}

