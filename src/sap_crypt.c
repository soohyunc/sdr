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

int encrypt_announcement(char *srcbuf, char **dstbuf, int *length,
                         char *key)
{
  Set_Key(key);
#ifdef DEBUG
  printf("pre-encr len: %d\n", *length);
#endif
  *dstbuf=(u_char*)Encrypt(srcbuf, length);
#ifdef DEBUG
  printf("post-encr len: %d\n", *length);
#endif
  return 0;
}
int parse_privhdr(char *buf, int *len, char *recvkey)
{
  struct enc_header *enchead;
  struct priv_header *priv_hdr=NULL;
  char *tmpbuf;
  int hdrlen, padlen, rc;
 
  tmpbuf=(char *)malloc(*len);
  memcpy(tmpbuf,buf,*len);
 
  enchead=(struct enc_header *)tmpbuf;
#ifdef DEBUG
  printf("timeout: %d\n", enchead->timeout);
#endif
 
/* deal with the privacy header */
  priv_hdr = (struct priv_header *) (tmpbuf + sizeof(struct enc_header) );
 
#ifdef DEBUG
  printf("Privacy Header received: version = %d, padding = %d, enctype = %d, hdr
_len = %d\n",priv_hdr->version, priv_hdr->padding, priv_hdr->enctype, (u_int)pri
v_hdr->hdr_len);
#endif
 
/* check version of privacy header - only deal with it if it is version 1 */
  if (priv_hdr->version != 1) {
#ifdef DEBUG
    fprintf(stderr, "Privacy Header version should be 1. It is %d.\n",priv_hdr->version);
#endif
    return -1;
  }
 
  hdrlen = ((int)priv_hdr->hdr_len) *4 ;
  padlen = (int)(tmpbuf[sizeof(struct enc_header)+hdrlen-1]);
 
#ifdef DEBUG
  printf("privacy header: hdrlen = %d and padlen = %d\n",hdrlen, padlen);
#endif
 
  switch (priv_hdr->enc_type) {
    case DES:
      *len -= sizeof(struct enc_header) + hdrlen;
      rc =  (decrypt_announcement(tmpbuf+sizeof(struct enc_header)+hdrlen, len,
recvkey));
      memcpy(buf,tmpbuf+sizeof(struct enc_header)+hdrlen,*len);
      free(tmpbuf);
      return rc;
 
    case DES3: case PGP: case PKCS7: default:
#ifdef DEBUG
      fprintf(stderr,"Unsupported Privacy Header type %d (1:3DES,2:PGP,3:PKCS#7)
\n",priv_hdr->enctype);
#endif
      return -1;
  }
 
}


int decrypt_announcement(char *buf, int *len, char *recvkey)
{
  char key[MAXKEYLEN];
  char *dstbuf, *origbuf;
  struct enc_header *enchead;
  struct keydata *tmpkey=keylist;
  int length=0;
#ifdef DEBUG
  int i;
#endif

/* should now have buf pointing to start of encrypted payload */
/* and len being the length of this payload                   */

  origbuf=malloc(*len);
  memcpy(origbuf,buf,*len);          /* decrypt splats buffer so save it */
  enchead=(struct enc_header *)buf;

#ifdef DEBUG
  printf("timeout: %d\n", enchead->timeout);
#endif

/* No longer have key id so loop through all keys trying to decrypt buffer */

  while(tmpkey != NULL)
  {
    strncpy(key, tmpkey->key, MAXKEYLEN);
    memcpy(buf,origbuf,*len);

#ifdef DEBUG
    printf("setting key: %s\n", key);
    Set_Key(key);
    printf("..done\n");
#else
    Set_Key(key);
#endif

    dstbuf=malloc(*len);

#ifdef DEBUG
    printf("pre-decrypt     len: %d\n", *len-4);
#endif
    length=Decrypt(buf+4, dstbuf, (*len)-4);
#ifdef DEBUG
    printf("post-decrypt length: %d\n", length);
    for(i=0;i<16;i++)
      printf("%d,", dstbuf[i]);
    printf("\n");
#endif

    if (length != -1) {
      if (strncmp(dstbuf, "v=", 2)==0) {
#ifdef DEBUG
        printf("         ... decryption was successful\n");
#endif
        *len = length;
        strncpy(recvkey, key, MAXKEYLEN);
        memcpy(buf, dstbuf, *len);
        buf[*len]='\0';
        free(origbuf);
        return 0;
      }
    } 
    tmpkey=tmpkey->next;
  }

/* if reach here then decryption has failed */
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
#ifdef AUTH
  write_crypted_file(keyfilename, buf,
                     no_of_keys*(sizeof(struct keyfile)), passphrase,
                     "none", NULL);
#else

  write_crypted_file(keyfilename, buf, no_of_keys*(sizeof(struct keyfile)), passphrase);
#endif
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
#ifdef AUTH
extern unsigned long hostaddr;

int write_crypted_file(char *afilename, char *data, int len, char *key,
                       char *auth_type, char *advertid)
#else
int write_crypted_file(char *afilename, char *data, int len, char *key) 
#endif
{
  char *buf=NULL, *encbuf=NULL, *p=NULL;
  FILE *file;
  struct timeval tv;
  char tmpfilename[MAXFILENAMELEN];
  MD5_CTX context;
  u_char hash[16];
#ifdef AUTH
  int auth_len=0,bplen,i=0;
  struct advert_data *addata=NULL;
  struct  advert_data *get_encryption_info();	
  struct auth_header *sapauth_p=NULL;
  struct sap_header *bp=NULL;
#endif
  char *filename;
#ifdef WIN32  /* need to sort out the ~ on windows */
  struct stat sbuf;
  Tcl_DString buffer;
  filename = Tcl_TildeSubst(interp, afilename, &buffer);
#else
  filename = afilename;
#endif

  /*no passphrase was entered - don't save!*/
  if (strcmp(key, "")==0) return 0;
#ifdef DEBUG
  printf("passphrase: %s\n", key);
#endif
#ifdef AUTH
  /* If the announcement contains authentication information then write
     this data to the file, before it is encrypted. */
 
  if (strcmp(auth_type, "none") !=0 )
  {
 
        /* Obtains the key certificate and signature info for the advert */
         addata = get_encryption_info(advertid);
	  if( addata  == NULL)
                 {
                 printf( "something is wrong\n");
                 return 1;
                 }
            sapauth_p = addata->sapauth_p;
 		bp = addata->sap_p;
              if( sapauth_p != NULL)
        	 if(sapauth_p->auth_type  == 3 )
		{
                auth_len = sapauth_p->key_len + sapauth_p->sig_len 
					+sapauth_p->pad_len+2;
		} else
                auth_len = sapauth_p->sig_len+sapauth_p->pad_len+2;
              if( bp == NULL)
                {
              bp=malloc(sizeof(struct sap_header));
              bp->version = 1;
              bp->authlen = auth_len /4;
              bp->enc = 1;
  	      bp->compress = 0;
              bp->msgid=0;
              bp->src=htonl(hostaddr);
	     }
 
        AUTHDEB( printf(" write sapauth_p->auth_type %d",sapauth_p->auth_type);)
        buf=malloc(len+24+sizeof(struct sap_header)+auth_len+4+addata->length);
        memcpy(buf+24, data, len);
        memcpy(buf+24+len, bp,sizeof(struct sap_header));
        bplen = sizeof(struct sap_header);
        memcpy(buf+24+len+bplen, (char *)sapauth_p, 2);
        memcpy(buf+24+len+bplen+2, sapauth_p->signature, sapauth_p->sig_len);
        if(sapauth_p->auth_type  == 3 )
        {
        memcpy(buf+24+len+bplen+2+sapauth_p->sig_len, sapauth_p->keycertificate,
                sapauth_p->key_len);
        len+=(bplen+sapauth_p->sig_len+sapauth_p->key_len+2);
        }
        else
        len+=(bplen+sapauth_p->sig_len+2);
	if (sapauth_p->pad_len != 0)
        for (i=0; i<(sapauth_p->pad_len-1); ++i)
                               {
 
                                        buf[len+24+i] = 0;
                                }
 
                                buf[len+24+i] = sapauth_p->pad_len;
                                 len+=sapauth_p->pad_len;
         /**(u_int*)(buf+24+len)=0; */
        for (i=0; i<4; i++)
                 buf[len+24+i]=0;
        memcpy(buf+24+len+4,addata->data,addata->length);
        len+=addata->length+4;
  }
  else
  {
    buf=malloc(len+24+8);
    memcpy(buf+24, data, len);
  }
#else

  buf=malloc(len+24+8);
  memcpy(buf+24, data, len);
#endif
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

  /*Add the MD5 hash to ensure that when we decrypt we know it was the
    correct pass_phrase*/
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

#ifdef DEBUG
  printf("loading file: %s\n", filename);
#endif

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
  printf("len=%d\n", sbuf.st_size);
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

/* change the last == to be \0= so we have a string terminator. Actually leave */
/* off the last character as it is always A,w,Q or g as the last 4 bits of the */
/* final 6 bit value are 0                                                     */
 
    newkey[21] = '\0';
 
/* now check the key doesn't have any "/" in it as vat doesn't like them       */
/* some tools don't like other characters eg ",\,` and $ but as this is base64 */
/* encoded we don't have them anyway and we check the key again later on       */
 
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

/* ---------------------------------------------------------------------------- */
/*  Function:      ToBase64                                                     */
/*                                                                              */
/*  Description:   Encode u_chars in Base64 as per MIME (RFC-1521)              */
/*                 The routine will read as much of the input as is needed      */
/*                 to fill the output, advancing the pointers in the input      */
/*                 as it is used. Note that if you wish to call this with       */
/*                 more than one input buffer, each call should provide         */
/*                 a multiple of 3 u_chars, otherwise you will get padding      */
/*                 at an intermediate stage.                                    */
/*                                                                              */
/*                 The output buffer is only filled with 4 character sets.      */
/*                                                                              */
/*  Parameters:    Pointer to pointer into input buffer                         */
/*                 Pointer to length of input buffer remaining                  */
/*                 Pointer to output buffer                                     */
/*                 Length of output buffer                                      */
/*                                                                              */
/*  Return Value:  Number of u_chars written to output buffer                   */
/*                                                                              */
/* ---------------------------------------------------------------------------- */
 
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
 
/* ---------------------------------------------------------------------------- */
/*  bin_to_b64_aux                                                              */
/*                                                                              */
/* Conversion routine to Base-64 : 3 binary octets to 4 Base-64 chars           */
/*                                                                              */
/* in           input binary data                                               */
/* inlen        length of input in u_chars                                      */
/* cpp          where to place pointer to newly alloc'd return data             */
/*                                                                              */
/* returns number of output u_chars (not including zero terminator),            */
/* or 0 on error (*cpp not valid)                                               */
/* ---------------------------------------------------------------------------- */
 
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

