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
#include "prototypes_crypt.h"

struct keydata* keylist;
char passphrase[MAXKEYLEN];
extern Tcl_Interp *interp;

#ifdef WIN32
/* need to set this so can handle binary files okay */
extern int _fmode=_O_BINARY;
#endif

/* #define DEBUG */

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
  printf("Privacy Header received: version = %d, padding = %d, enctype = %d, hdr_len = %d\n",priv_hdr->version, priv_hdr->padding, priv_hdr->enctype, (u_int)priv_hdr->hdr_len);
#endif

/* check version of privacy header - only deal with it if it is version 1 */
  if (priv_hdr->version != 1) {
    fprintf(stderr, "Privacy Header version should be 1. It is %d.\n",priv_hdr->version);
    return -1;
  }

  hdrlen = ((int)priv_hdr->hdr_len) *4 ;
  padlen = (int)(tmpbuf[sizeof(struct enc_header)+hdrlen-1]);

#ifdef DEBUG
  printf("privacy header: hdrlen = %d and padlen = %d\n",hdrlen, padlen);
#endif

  switch (priv_hdr->enctype) {
    case DES:
      *len -= sizeof(struct enc_header) + hdrlen;
      rc =  (decrypt_announcement(tmpbuf+sizeof(struct enc_header)+hdrlen, len, recvkey));
      memcpy(buf,tmpbuf+sizeof(struct enc_header)+hdrlen,*len);
      free(tmpbuf); 
      return rc;

    case DES3: case PGP: case PKCS7: default:
#ifdef DEBUG
      fprintf(stderr,"Unsupported Privacy Header type %d (1:3DES,2:PGP,3:PKCS#7)\n",priv_hdr->enctype);
#endif
      return -1;
  }

}

int decrypt_announcement(char *buf, int *len, char *recvkey)
{
  char key[MAXKEYLEN];
  char *dstbuf, *origbuf;
  struct keydata *tmpkey=keylist;
  int length=0;
#ifdef DEBUG
  int i;
#endif

/* should now have buf pointing to start of encrypted payload */
/* and len being the length of this payload                   */

  origbuf=malloc(*len);
  memcpy(origbuf,buf,*len);          /* decrypt splats buffer so save it */

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
    printf("pre-decrypt     len: %d\n",*len);
#endif
    length=Decrypt(buf,dstbuf,*len);
#ifdef DEBUG
    printf("post-decrypt length: %d\n",length);
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

  write_crypted_file(keyfilename, buf, no_of_keys*(sizeof(struct keyfile)), passphrase);
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

int write_crypted_file(char *afilename, char *data, int len, char *key) 
{
  char *buf, *encbuf, *p;
  FILE *file;
  struct timeval tv;
  char tmpfilename[MAXFILENAMELEN];
  MD5_CTX context;
  u_char hash[16];
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

  buf=malloc(len+24+8);
  memcpy(buf+24, data, len);
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
  char *p;
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
