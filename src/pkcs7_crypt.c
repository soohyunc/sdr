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
#ifndef WIN32
#include <fcntl.h>
#endif


extern struct keydata* keylist;
extern char passphrase[MAXKEYLEN];
extern Tcl_Interp *interp;
/*#define DEBUG*/
#ifdef AUTH
char *x509txt_fname="txt";
char *x509sig_fname="sig";
char *x509key_fname="cert";
char *x509bdy_fname="btxt";
char *sx509txt_fname="txt";
char *sx509enc_fname="sym";
#endif


#ifdef AUTH
/* ---------------------------------------------------------------------- */
/* generate_x509_authentication_info - creates the authentication signature    */
/*                                and extracts the key certificate and    */
/*                                places them in separate files           */
/* ---------------------------------------------------------------------- */
int generate_x509_authentication_info(char *data,int len, char *authstatus, int irand, char *authmessage)
{
    FILE *txt_fd=NULL;
    char *code=NULL;
    char *homedir, fulltxt[MAXFILENAMELEN]="";
    char irandstr[10]="";
    char *auth_message=NULL;
    int messagelen;

   writelog(printf("++ debug ++ > entered generate_authentication_x509_info\n");)
 
    homedir=(char *)getenv("HOME");
#ifdef WIN32
    sprintf(fulltxt, "%s\\sdr\\%d.%s", homedir, irand, x509txt_fname);
#else
    sprintf(fulltxt, "%s/.sdr/%d.%s", homedir, irand, x509txt_fname);
#endif

    sprintf(irandstr, "%d", irand);

    writelog(printf("++ debug ++ filename is %s\n",fulltxt);)
    writelog(printf("++ debug ++ filename is %s\n",x509txt_fname);)

    txt_fd=fopen(fulltxt, "w");
     if (txt_fd == NULL)
    {
     printf (" cannot open %s\n", fulltxt);
     fclose(txt_fd);
     memcpy(authstatus, "failed",6);
     return 0;
    }

    fwrite(data, 1, len, txt_fd);
    fclose(txt_fd);
 
    /* Executes the TCL script that calls PGP */
    Tcl_VarEval(interp, "pkcs7_create_signature ",  &irandstr, NULL);
     code = Tcl_GetVar(interp, "recv_result", TCL_GLOBAL_ONLY);
/*    if (strcmp(code,"1") != 0 )
    {
        printf("INCORRECT Signature File not been created\n");
        Tcl_VarEval(interp, "pkcs7_cleanup  ", &irandstr, NULL);
        return 0;
    } */
    memcpy(authstatus, "Authenticated",13);

  auth_message = Tcl_GetVar(interp, "recv_authmessage", TCL_GLOBAL_ONLY);
    messagelen = strlen(auth_message);
   memcpy(authmessage,auth_message,messagelen);

    /* check_for_the signature_file */
    
    return 1;
}
 
/* ---------------------------------------------------------------------- */
/* check_authentication - processes incoming authentication info for      */
/*                        integrity and assurance of originator           */
/* ---------------------------------------------------------------------- */
char *check_x509_authentication(struct auth_header *auth_p, char *authinfo,
                         char *data, int data_len, int auth_len,
                         char *asym_keyid, int irand,char *authmessage)
{
  FILE *sig_fd=NULL, *auth_fd=NULL;
  int sig_len;
  int pad_len;
  char *key_id=NULL;
  char *auth_status=NULL;
  char *auth_message=NULL;
  int messagelen;

  char *homedir;
 char fulltxt[MAXFILENAMELEN]="", fullsig[MAXFILENAMELEN]="", fullbdy[MAXFILENAMELEN]="";

  char irandstr[10]="";
/*  printf("data= %s\n", data); */
  writelog(printf("This packet contains authentication information\n");)
   sig_len= auth_p->siglen * 4;
 
  sig_len=auth_len  - 2;
  /* remove padding, if necessary */
  if ( auth_p->padding )
  {
    pad_len = *(authinfo+(auth_len-2)-1);
    sig_len-=pad_len;
    writelog(printf("Padding Length=%d\n", *(authinfo+(auth_len-2)-1));)
  }
 
  writelog(printf("Key Certificate=%d bytes\n", key_len);)
 
  /* Extract the signature and key certificate from the packet and
     store in files. */

  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(fulltxt, "%s\\sdr\\%d.%s", homedir, irand, x509txt_fname);
  sprintf(fullsig, "%s\\sdr\\%d.%s", homedir, irand,x509sig_fname);
  sprintf(fullbdy, "%s\\sdr\\%d.%s", homedir, irand,x509bdy_fname);
#else
  sprintf(fulltxt, "%s/.sdr/%d.%s", homedir, irand, x509txt_fname);
  sprintf(fullsig, "%s/.sdr/%d.%s", homedir, irand,x509sig_fname);
  sprintf(fullbdy, "%s/.sdr/%d.%s", homedir, irand,x509bdy_fname);
#endif

   sprintf(irandstr, "%d", irand);


  sig_fd=fopen(fullsig, "w");
  if (sig_fd == NULL)
  {
    printf("Cannot open %s\n", fullsig);
    fclose(sig_fd);
    Tcl_VarEval(interp, "pkcs7_cleanup ", &irandstr, NULL);
    return ("failed");
  }
  if ( fwrite(authinfo, 1, sig_len, sig_fd) < sig_len )
  {
    printf("Error writing signature to file\n\r");
    fclose(sig_fd);
    Tcl_VarEval(interp, "pkcs7_cleanup ", &irandstr, NULL);
    return ("failed");
  }
  fclose(sig_fd);
 
  auth_fd=fopen(fulltxt, "w");
  if (auth_fd == NULL)
  {
    printf("Cannot open %s\n", fulltxt);
    fclose(auth_fd);
    Tcl_VarEval(interp, "pkcs7_cleanup ", &irandstr, NULL);
    return ("failed");
  }
 

 writelog( printf(" check AUTH_p->auth_type %d\n",auth_p->auth_type);
)
  /* REMINDER: need to store end_time and keyid too if encrypted session
     Refer to SAP specification for encrypted announcements with
     authentication! */
  if ( fwrite(data, 1, data_len, auth_fd) < data_len )
  {
    printf("Error writing SDP data to file\n\r");
    fclose(auth_fd);
    Tcl_VarEval(interp, "pkcs7_cleanup ", &irandstr, NULL);
    return ("failed");
  }
 
  fclose(auth_fd);
 
 
  /* Executes a TCL script that invokes PGP to check signature info */
    writelog(printf("writing SDP data to file\n\r");)
  Tcl_VarEval(interp, "pkcs7_check_authentication ", &irandstr, NULL);
 
  key_id = Tcl_GetVar(interp, "recv_asym_keyid", TCL_GLOBAL_ONLY);
    writelog(printf("writing SDP data to file\n\r");)
  if (key_id !=NULL)
  memcpy(asym_keyid, key_id,strlen(key_id));
  auth_status = Tcl_GetVar(interp, "recv_authstatus", TCL_GLOBAL_ONLY);
auth_message = Tcl_GetVar(interp, "recv_authmessage", TCL_GLOBAL_ONLY);
  if(auth_message !=NULL)
   {
   messagelen = strlen(auth_message);
   memcpy(authmessage,auth_message,messagelen);
  } else {
 printf(" The Message is empty string %s \n" ,interp->result);
    memcpy(authmessage,"No mesage were produced",24);
 }
  return (auth_status);
}
 
/* ---------------------------------------------------------------------- */
/* store_authentication_in_memory - reads the key certificate and         */
/*                                  signature information from the local  */
/*                                  files and places them in memory, in   */
/*                                  an advert_data structure              */
/* ---------------------------------------------------------------------- */
int store_x509_authentication_in_memory(struct advert_data *addata, char *auth_type , int irand)
{
#ifndef AUTH
  int sig_len;
  int key_len;
#endif
  FILE *sig_fd=NULL;
  struct stat sbuf;
  char *encsig;
  struct auth_header *sapauth_p;
  char *homedir;
  char fullsig[MAXFILENAMELEN]="";
  char irandstr[10]="";
  int test_len;
 

 
  writelog(printf("++ debug ++ > entered store_authentication_in_memory\n");)

/* Open all files and read data */

  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(fullsig, "%s\\sdr\\%d.%s", homedir, irand, x509sig_fname);
#else
  sprintf(fullsig, "%s/.sdr/%d.%s", homedir, irand, x509sig_fname);
#endif
    sprintf(irandstr, "%d", irand);

  sapauth_p = addata->sapauth_p;
  sapauth_p->version = 1;
  sig_fd=fopen(fullsig, "r");
  if (sig_fd == NULL)
  {
      printf("Cannot open %s\n", fullsig);
      Tcl_VarEval(interp, "pkcs7_cleanup ", &irandstr, NULL);
      fclose(sig_fd);

      return 0;
  }
 stat(fullsig,&sbuf);
 encsig = (char *)malloc(sbuf.st_size);
 if(( fread(encsig,1,  sbuf.st_size ,sig_fd))!= sbuf.st_size)
   {
	fclose(sig_fd);
        free(encsig);
        
   }
/*    printf(" Signature data %s \n", encsig); */
    sapauth_p->sig_len = sbuf.st_size;
        sapauth_p->signature = malloc(sapauth_p->sig_len);
        memcpy (sapauth_p->signature, encsig,sapauth_p->sig_len);
 
  fclose(sig_fd);

       sapauth_p->key_len =0;
       sapauth_p->keycertificate=NULL;

/* Toadd the authetication used pgp or X509 Plus the certificate*/
  if (memcmp(auth_type,"cx50",4) == 0)
    sapauth_p->auth_type = 4;
   else  if (memcmp(auth_type,"x509",4) == 0)
   sapauth_p->auth_type = 2;
   else
	printf("something is wrong auth_type is not pgp or x509\n");	
   writelog(printf("authe_tyoe = %s \n", auth_type);)
     
  /* Padding is required to ensure that the authentication info is aligned
     to a 32-bit boundary */
  sapauth_p->pad_len = 4-((sapauth_p->sig_len+2) % 4);
  	sapauth_p->siglen = (sapauth_p->sig_len + sapauth_p->pad_len) / 4 ;
  if (sapauth_p->pad_len != 0)
  {
      sapauth_p->padding = 1;
  }
   test_len = (sapauth_p->sig_len+2+sapauth_p->pad_len) /4;
   sapauth_p->autlen = test_len;
   if (sapauth_p->autlen != test_len) {
     printf ("authentication Header is Two big %d %d \n",sapauth_p->autlen , test_len);
     return 2;
  }

  Tcl_VarEval(interp, "pkcs7_cleanup ", &irandstr, NULL);
        free(encsig);

  return 1;
}


int generate_x509_encryption_info(char *data, char *encstatus, int irand,char *encmessage)
{
    FILE *txt_fd=NULL;
    FILE *enc_fd=NULL;
    char  *code=NULL;
    char *homedir, sx509fulltxt[MAXFILENAMELEN]="";
    char sx509fullenc[MAXFILENAMELEN]="" ;
    char irandstr[10]="";
    char *enc_message=NULL;
    int messagelen;

 
   writelog(printf("++ debug ++ > entered generate_authentication_info\n");)
 
    homedir=(char *)getenv("HOME");
#ifdef WIN32
    sprintf(sx509fulltxt, "%s\\sdr\\%d.%s", homedir, irand, sx509txt_fname);
sprintf(sx509fullenc, "%s\\sdr\\%d.%s", homedir, irand, sx509enc_fname);
#else
    sprintf(sx509fulltxt, "%s/.sdr/%d.%s", homedir, irand, sx509txt_fname);
    sprintf(sx509fullenc, "%s/.sdr/%d.%s", homedir, irand, sx509enc_fname);
#endif
    sprintf(irandstr, "%d", irand);
 
    txt_fd=fopen(sx509fulltxt, "w");
    if (txt_fd == NULL)
    {
     printf (" cannot open %s\n", sx509fulltxt);
     fclose(txt_fd);
    memcpy(encstatus, "failed",6);
     return 0;
    }

    fwrite(data, 1, strlen(data), txt_fd);
    fclose(txt_fd);

 
    /* Executes the TCL script that calls PGP */
    Tcl_VarEval(interp, "pkcs7_create_encryption ", &irandstr, NULL);
     code = Tcl_GetVar(interp, "recv_result", TCL_GLOBAL_ONLY);
     if (strcmp(code,"1") != 0 )
    {
        printf("File has not been created\n");
        Tcl_VarEval(interp, "enc_pkcs7_cleanup  ", &irandstr, NULL);
        return 0;
    }

/*    printf("\nReturn Code= %d\n", code); */
      enc_message = Tcl_GetVar(interp, "recv_encmessage", TCL_GLOBAL_ONLY);
  if(enc_message !=NULL)
   {
   messagelen = strlen(enc_message);
   memcpy(encmessage,enc_message,messagelen);
  } else {
 printf(" The Message is empty string %s \n" ,interp->result);
    memcpy(encmessage,"No mesage were produced",24);
 }
 
    /* It either works or fails */
    memcpy(encstatus, "Encrypted",9);

     enc_fd= fopen(sx509fullenc,"r");
   if (enc_fd == NULL)
  {
      printf("Cannot open %s\n", sx509fullenc);
      Tcl_VarEval(interp, "enc_pkcs7_cleanup ", &irandstr, NULL);
      fclose(enc_fd);
 
      fclose(enc_fd);
 
      return 0;
  }
    
    return 1;
}
char *check_x509_encryption(struct priv_header *enc_p, char *encinfo,
                         char *data, int data_len, int hdr_len,
                         char *enc_asym_keyid, int irand,char *encmessage)
{
  FILE  *enc_fd=NULL;
  char *enc_status=NULL;
  char *enc_message=NULL;
  char *key_id;
   char irandstr[10]="";
 
  char *homedir;
  char sx509fulltxt[MAXFILENAMELEN]="", sx509fullenc[MAXFILENAMELEN]="";

  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(sx509fulltxt, "%s\\sdr\\%d.%s", homedir, irand, sx509txt_fname);
  sprintf(sx509fullenc, "%s\\sdr\\%d.%s", homedir, irand, sx509enc_fname);
 
#else
  sprintf(sx509fulltxt, "%s/.sdr/%d.%s", homedir, irand, sx509txt_fname);
  sprintf(sx509fullenc, "%s/.sdr/%d.%s", homedir, irand, sx509enc_fname);
#endif

  sprintf(irandstr, "%d", irand);
 
 
/*  printf("data= %s\n", data); */
 
  /* remove padding, if necessary */
  if ( enc_p->padding )
  {
    writelog(printf("Padding Length=%d\n", *(encinfo+hdr_len-2));)
    writelog(printf("Padding Length=%d\n", *(encinfo+hdr_len-1));)
    writelog(printf("Padding Length=%d\n", *(encinfo+hdr_len));)
    hdr_len= (hdr_len-2) - (*(encinfo+hdr_len-1)) ;
  }
 
 
  /* Extract the signature and key certificate from the packet and
     store in files. */
 
 
  enc_fd=fopen(sx509fullenc, "w");
  if (enc_fd == NULL)
  {
    printf("Cannot open %s\n", sx509fullenc);
 
     fclose(enc_fd);
    Tcl_VarEval(interp, "enc_pkcs7_cleanup ", &irandstr, NULL);

    return ("failed");
  }
 
  if ( fwrite(data, 1, hdr_len, enc_fd) < hdr_len )
  {
    printf("Error writing SDP data to file\n\r");
    fclose(enc_fd);
    Tcl_VarEval(interp, "enc_pkcs7_cleanup ", &irandstr, NULL);

    return ("failed");
  }
 
  fclose(enc_fd);
 
 
  /* Executes a TCL script that invokes PGP to check  info */
    writelog(printf("writing SDP data to file\n\r");)
  Tcl_VarEval(interp, "pkcs7_check_encryption ", &irandstr, NULL);
  enc_status = Tcl_GetVar(interp, "recv_encstatus", TCL_GLOBAL_ONLY);
  key_id = Tcl_GetVar(interp, "recv_enc_asym_keyid", TCL_GLOBAL_ONLY);
    writelog(printf("writing SDP data to file\n\r");)
  if(key_id != NULL)
  memcpy(enc_asym_keyid, key_id,strlen(key_id));
   enc_message = Tcl_GetVar(interp, "recv_encmessage", TCL_GLOBAL_ONLY);
  if(enc_message != NULL)
  memcpy(encmessage,enc_message,strlen(enc_message));
  else {
        printf("The Decryption didnot produce any message %s\n",interp->result);
        memcpy(encmessage,"No Encryption Message",20);
	return("failed");
  }

  writelog(printf(" encstatus %s",enc_status);)

  return (enc_status);
}
int store_x509_encryption_in_memory(struct advert_data *addata, char *enc_type, int irand)
{
  FILE *enc_fd=NULL;
  FILE *txt_fd=NULL;
  struct stat sbuf;
  struct stat sbufd;
  char *encbuf=NULL,*ac;
  struct priv_header *sapenc_p;
  char *decrypt=NULL;
  char *homedir;
 char sx509fulltxt[MAXFILENAMELEN]="", sx509fullenc[MAXFILENAMELEN]="";

  char irandstr[10]="";
  int i;
 
  writelog(printf("++ debug ++ > entered store_encryption\n");)
 
/* Open all files and read data */
 
  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(sx509fulltxt, "%s\\sdr\\%d.%s", homedir, irand, sx509txt_fname);
  sprintf(sx509fullenc, "%s\\sdr\\%d.%s", homedir, irand, sx509enc_fname);
 
#else
  sprintf(sx509fulltxt, "%s/.sdr/%d.%s", homedir, irand, sx509txt_fname);
  sprintf(sx509fullenc, "%s/.sdr/%d.%s", homedir, irand, sx509enc_fname);
#endif
  sprintf(irandstr, "%d", irand);
 
  sapenc_p = addata->sapenc_p;
  sapenc_p->version = 1;
 
/* Toadd the encryption used pgp or X509 */
  if (strcmp(enc_type,"x509") == 0)
    sapenc_p->enc_type = PKCS7;
  else  if (strcmp(enc_type,"pgp") == 0)
    sapenc_p->enc_type = PGP;
  else
   sapenc_p->enc_type = 0;
   writelog(printf("enc_type = %s \n", enc_type);)
 
  enc_fd= fopen(sx509fullenc,"r");
   if (enc_fd == NULL)
  {
      printf("Cannot open %s\n", sx509fullenc);
      Tcl_VarEval(interp, "enc_pkcs7_cleanup ", &irandstr, NULL);
      fclose(enc_fd);
      return 0;
  }
  stat(sx509fullenc, &sbuf);
   encbuf =(char *)malloc(sbuf.st_size);
   if(( fread(encbuf,1,  sbuf.st_size ,enc_fd))!= sbuf.st_size)
   {
   fclose(enc_fd);
    free(encbuf);
 
    }
  fclose(enc_fd);

  txt_fd= fopen(sx509fulltxt,"r");
   if (txt_fd == NULL)
  {
      printf("Cannot open %s\n", sx509fulltxt);
      Tcl_VarEval(interp, "enc_pkcs7_cleanup ", &irandstr, NULL);
      fclose(txt_fd);
 
      return 0;
  }
   writelog(printf(" encrypted data %s \n", encbuf);)
   sapenc_p->encd_len=sbuf.st_size;
   writelog(printf(" sapenc_p->encd_len = %d \n", sapenc_p->encd_len);)
   stat(sx509fulltxt, &sbufd);
   decrypt = (char *)malloc(sbufd.st_size);
    if(( fread(decrypt,1,  sbufd.st_size ,txt_fd))!= sbufd.st_size)
   {
   fclose(txt_fd);
    free(decrypt);
    }
 
   sapenc_p->txt_len= sbufd.st_size;
  sapenc_p->txt_data = (char *)malloc(sapenc_p->txt_len);
  memcpy(sapenc_p->txt_data, decrypt, sapenc_p->txt_len);

  fclose(txt_fd);
   
  sapenc_p->pad_len = 4-((sapenc_p->encd_len+2) % 4);
  if (sapenc_p->pad_len != 0)
  {
      sapenc_p->padding = 1;
  }
   sapenc_p->hdr_len = (sapenc_p->pad_len +  sapenc_p->encd_len +2) / 4;
   writelog(printf(" sapenc_p->hdr_len = %d \n", sapenc_p->hdr_len);)
    sapenc_p->enc_data =(char *)malloc(sapenc_p->pad_len +  sapenc_p->encd_len);
   memcpy(sapenc_p->enc_data,encbuf, sapenc_p->encd_len);
   ac=(char *)(sapenc_p->enc_data)+sapenc_p->encd_len;
   if (sapenc_p->pad_len != 0)
        {
                for (i=0; i<(sapenc_p->pad_len-1); ++i)
                {
                        ac[i] = 0;
                }
 
                ac[i] = sapenc_p->pad_len;
        }
   writelog(printf(" encrypted data %s \n", sapenc_p->enc_data);)
  free(encbuf);
  free(decrypt);
  Tcl_VarEval(interp, "enc_pkcs7_cleanup ", &irandstr, NULL);
 

  return 1;
}
#endif
