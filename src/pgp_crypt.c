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


struct keydata* keylist;
char passphrase[MAXKEYLEN];
extern Tcl_Interp *interp;
/*#define DEBUG*/
#ifdef AUTH
char *authtxt_fname="txt";
char *authsig_fname="sig";
char *authkey_fname="pgp";
char *enctxt_fname="txt";
char *sapenc_fname="pgp";

#endif


#ifdef AUTH
/* ---------------------------------------------------------------------- */
/* generate_authentication_info - creates the authentication signature    */
/*                                and extracts the key certificate and    */
/*                                places them in separate files           */
/* ---------------------------------------------------------------------- */
int generate_authentication_info(char *data,int len, char *authstatus, int irand,char *authmessage)
{
    FILE *auth_fd=NULL;
    char *code=NULL;
    char *homedir, fulltxt[MAXFILENAMELEN]="";
    char irandstr[10]="";
    char *auth_message=NULL;
  int messagelen;

   AUTHDEB(printf("++ debug ++ > entered generate_authentication_info\n");)

 
    homedir=(char *)getenv("HOME");
#ifdef WIN32
    sprintf(fulltxt, "%s\\sdr\\%d.%s", homedir, irand, authtxt_fname);
#else
    sprintf(fulltxt, "%s/.sdr/%d.%s", homedir, irand, authtxt_fname);
#endif
    sprintf(irandstr, "%d", irand);

    AUTHDEB(printf("++ debug ++ filename is %s\n",fulltxt);)
    AUTHDEB(printf("++ debug ++ filename is %s\n",authtxt_fname);)

/*    auth_fd=fopen(authtxt_fname, "w");  */
    auth_fd=fopen(fulltxt, "w");
    if (auth_fd == NULL)
    {
     printf (" cannot open %s\n", fulltxt);
     fclose(auth_fd);
     memcpy(authstatus, "failed",6);
        Tcl_VarEval(interp, "pgp_cleanup  ", &irandstr, NULL);
     return 0;
    }
    fwrite(data, 1, len, auth_fd);
    fclose(auth_fd);
 
    /* Executes the TCL script that calls PGP */
    Tcl_VarEval(interp, "pgp_create_signature ",  &irandstr, NULL);
    code = Tcl_GetVar(interp, "recv_result", TCL_GLOBAL_ONLY); 
//    printf("\nReturn Code= %d\n", code);
    if (strcmp(code,"1") != 0 )
    {
        printf("INCORRECT PASSWORD OR File not created\n");
        Tcl_VarEval(interp, "pgp_cleanup  ", &irandstr, NULL);
        return 0;
    }
    auth_message = Tcl_GetVar(interp, "recv_authmessage", TCL_GLOBAL_ONLY);
    messagelen = strlen(auth_message);
    authmessage=malloc(messagelen);
   memcpy(authmessage,auth_message,messagelen);
 
    memcpy(authstatus, "Authenticated",13);

    return 1;
}
 
/* ---------------------------------------------------------------------- */
/* check_authentication - processes incoming authentication info for      */
/*                        integrity and assurance of originator           */
char *check_authentication(struct auth_header *auth_p, char *authinfo,
                         char *data, int data_len, int auth_len,
                         char *asym_keyid, int irand,char *authmessage)
{
  FILE *sig_fd=NULL, *key_fd=NULL, *auth_fd=NULL;
  int sig_len;
  int key_len;
  int pad_len;
  char *key_id;
  char *auth_status;
  char *auth_message;
  int messagelen;

  char *homedir;
  char fulltxt[MAXFILENAMELEN]="", fullsig[MAXFILENAMELEN]="", fullkey[MAXFILENAMELEN]="";
  char irandstr[10]="";

  AUTHDEB(printf("This packet contains authentication information\n");)
   sig_len= auth_p->siglen * 4;
 
  key_len=auth_len - sig_len - 2;
  // remove padding, if necessary
  if ( auth_p->padding )
  {
    pad_len = *(authinfo+(auth_len-2)-1);
    key_len-=pad_len;
    AUTHDEB(printf("Padding Length=%d\n", *(authinfo+(auth_len-2)-1));)
  }
 
  AUTHDEB(printf("Key Certificate=%d bytes\n", key_len);)
 
  // Extract the signature and key certificate from the packet and
  // store in files.

  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(fulltxt, "%s\\sdr\\%d.%s", homedir, irand, authtxt_fname);
  sprintf(fullsig, "%s\\sdr\\%d.%s", homedir, irand,authsig_fname);
  sprintf(fullkey, "%s\\sdr\\%d.%s", homedir, irand,authkey_fname);
#else
  sprintf(fulltxt, "%s/.sdr/%d.%s", homedir, irand, authtxt_fname);
  sprintf(fullsig, "%s/.sdr/%d.%s", homedir, irand,authsig_fname);
  sprintf(fullkey, "%s/.sdr/%d.%s", homedir, irand,authkey_fname);
#endif
   sprintf(irandstr, "%d", irand);

  sig_fd=fopen(fullsig, "w");
  if (sig_fd == NULL)
  {
    printf("Cannot open %s\n", fullsig);
    fclose(sig_fd);
    Tcl_VarEval(interp, "pgp_cleanup ", &irandstr, NULL);
    return ("failed");
  }
  if ( fwrite(authinfo, 1, sig_len, sig_fd) < sig_len )
  {
    printf("Error writing signature to file\n\r");
    fclose(sig_fd);

    Tcl_VarEval(interp, "pgp_cleanup ", &irandstr, NULL);
    return ("failed");
  }
  fclose(sig_fd);
 
  key_fd=fopen(fullkey, "w");
  if (key_fd == NULL)
  {
    printf("Cannot open %s\n", fullkey);
    fclose(sig_fd);
    fclose(key_fd);
    Tcl_VarEval(interp, "pgp_cleanup ", &irandstr, NULL);
    return ("failed");
  }
 

 AUTHDEB( printf(" check AUTH_p->auth_type %d\n",auth_p->auth_type);)
  if (auth_p->auth_type == 3 || auth_p->auth_type == 4)
  {
  authinfo += sig_len;
  if ( fwrite(authinfo, 1, key_len, key_fd) < key_len )
  {
    AUTHDEB(printf("Error writing key certificate to file\n\r");)
    fclose(key_fd);
    Tcl_VarEval(interp, "pgp_cleanup ", &irandstr, NULL);
    return ("failed");
  }
  }
  fclose(key_fd);
 
  // REMINDER: need to store end_time and keyid too if encrypted session
  /* Refer to SAP specification for encrypted announcements with
     authentication! */
  auth_fd=fopen(fulltxt, "w");
  if (auth_fd == NULL)
  {
    printf("Cannot open %s\n", fulltxt);
    fclose(auth_fd);
    Tcl_VarEval(interp, "pgp_cleanup ", &irandstr, NULL);
    return ("failed");
  }
  if ( fwrite(data, 1, data_len, auth_fd) < data_len )
  {
    printf("Error writing SDP data to file\n\r");
    fclose(auth_fd);
    Tcl_VarEval(interp, "pgp_cleanup ", &irandstr, NULL);
    return ("failed");
  }
 
  fclose(auth_fd);
 
  /* Executes a TCL script that invokes PGP to check signature info */
    AUTHDEB(printf("writing SDP data to file\n\r");)
  Tcl_VarEval(interp, "pgp_check_authentication ", &irandstr, NULL);
 
  /* The script returns the (PGP)Key ID used and the authentication
     status (either FAILED, INTEGRITY (only), or TRUSTWORTHY) */
  key_id = Tcl_GetVar(interp, "recv_asym_keyid", TCL_GLOBAL_ONLY);
    AUTHDEB(printf("writing SDP data to file\n\r");)
  if (key_id != NULL)
  memcpy(asym_keyid, key_id,8);
  auth_status = Tcl_GetVar(interp, "recv_authstatus", TCL_GLOBAL_ONLY);
  auth_message = Tcl_GetVar(interp, "recv_authmessage", TCL_GLOBAL_ONLY);
  if(auth_message !=NULL)
   {
   messagelen = strlen(auth_message);
   memcpy(authmessage,auth_message,messagelen);
  } else {
 printf(" The Message is empty string %s \n" ,interp->result);
    memcpy(authmessage,"No mesage were produced",24);
    return ("failed");
 }
  AUTHDEB(printf("authstatus e..%s\n",auth_status);)
#ifdef WIN32
#endif
  return (auth_status);
}
 
/* ---------------------------------------------------------------------- */
/* store_authentication_in_memory - reads the key certificate and         */
/*                                  signature information from the local  */
/*                                  files and places them in memory, in   */
/*                                  an advert_data structure              */
/* ---------------------------------------------------------------------- */
int store_authentication_in_memory(struct advert_data *addata, char *auth_type , int irand)
{
#ifndef AUTH
  int sig_len;
  int key_len;
#endif
  FILE *sig_fd=NULL;
  FILE *key_fd=NULL;
  struct stat sbuf;
  struct stat sbufk;
  char *encsig=NULL;
  struct auth_header *sapauth_p;
  char *keycert=NULL;
  char *homedir;
  char irandstr[10]="";
  char fullsig[MAXFILENAMELEN]="", fullkey[MAXFILENAMELEN]="";
  int test_len;
 
  AUTHDEB(printf("++ debug ++ > entered store_authentication_in_memory\n");)

/* Open all files and read data */

  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(fullsig, "%s\\sdr\\%d.%s", homedir, irand, authsig_fname);
  sprintf(fullkey, "%s\\sdr\\%d.%s", homedir, irand, authkey_fname);
#else
  sprintf(fullsig, "%s/.sdr/%d.%s", homedir, irand, authsig_fname);
  sprintf(fullkey, "%s/.sdr/%d.%s", homedir, irand, authkey_fname);
#endif

    sprintf(irandstr, "%d", irand);

  sapauth_p = addata->sapauth_p;
  sapauth_p->version = 1;
  sig_fd=fopen(fullsig, "r");
  if (sig_fd == NULL)
  {
      printf("Cannot open %s\n", fullsig);
      Tcl_VarEval(interp, "pgp_cleanup ", &irandstr, NULL);
      fclose(sig_fd);

      return 0;
  }
 stat(fullsig,&sbuf);
 encsig = (char *)malloc(sbuf.st_size);
 if(( fread(encsig,1,  sbuf.st_size ,sig_fd))!= sbuf.st_size)
   {
	fclose(sig_fd);
	return 0;
   }
    sapauth_p->sig_len = sbuf.st_size;
     if ((sapauth_p->siglen) % 4 != 0)
  	{
  	sapauth_p->siglen = (sapauth_p->sig_len +1) / 4 ;
        sapauth_p->signature = malloc(sapauth_p->sig_len+1);
        memcpy (sapauth_p->signature, encsig,sapauth_p->sig_len);
        memcpy(sapauth_p->signature+1,'\0',1);
  	printf( " Signature is not a Multiple of 4 someting is wrong");
  	}
 	else
         {
  	sapauth_p->siglen = (sapauth_p->sig_len) / 4 ;
        sapauth_p->signature = malloc(sapauth_p->sig_len);
        memcpy (sapauth_p->signature, encsig,sapauth_p->sig_len);
        }
 
 /* sapauth_p->sig_len=fread(&signature_, 1, MAXSIGSIZE, sig_fd);
  (char *)sapauth_p->signature=(char *)malloc(sapauth_p->sig_len);
  memcpy(sapauth_p->signature, &signature_, sapauth_p->sig_len); */
//  printf("%d chars read of signature\n", sapauth_p->sig_len);
  fclose(sig_fd);

   free(encsig);
  if( strncmp(auth_type,"cpgp",4) == 0 || strncmp(auth_type,"cx509",5) == 0)
  { 
  key_fd=fopen(fullkey, "r");
  if (key_fd == NULL)
  {
      printf("Cannot open %s\n", fullkey);
     Tcl_VarEval(interp, "pgp_cleanup ", &irandstr, NULL);
      fclose(key_fd);
      return 0;
  }
  stat(fullkey,&sbufk);
  keycert = (char *)malloc(sbufk.st_size);
  if(( fread(keycert,1,  sbufk.st_size ,key_fd))!= sbufk.st_size)
   {
        fclose(key_fd);
        free(keycert);
   }
   sapauth_p->key_len = sbufk.st_size;
   sapauth_p->keycertificate=(char *)malloc(sapauth_p->key_len);
    memcpy(sapauth_p->keycertificate,keycert,sapauth_p->key_len);

  if (sapauth_p->key_len > 1024 )
  {
      printf("Sorry, Key Certificate is too large...\n");
      sapauth_p->key_len = 0;
  }
//  printf("%d chars read of key certificate\n\r", sapauth_p->key_len);
  fclose(key_fd);
    free(keycert);
  }
else
{
       sapauth_p->key_len =0;
       sapauth_p->keycertificate=NULL;
}

/* Toadd the authetication used pgp or X509 Plus the certificate*/
  if (memcmp(auth_type,"cpgp",4) == 0)
    sapauth_p->auth_type = 3;
  else  if (memcmp(auth_type,"cx509",5) == 0)
    sapauth_p->auth_type = 4;
   else  if (memcmp(auth_type,"pgp",3) == 0)
   sapauth_p->auth_type = 1;
   else  if (memcmp(auth_type,"x509",4) == 0)
   sapauth_p->auth_type = 2;
   else
	printf("something is wrong auth_type isnot pgp or x509\n");	
   AUTHDEB(printf("authe_tyoe = %s \n", auth_type);)
     
  /* There actually needs to be a better check here: if the total length of
     the SAP packet (including SAP header, data, encryption info, and
     authentication info) exceeds the MAXADSIZE value, then the entire
     key certificate should be transmitted in a separated packet.  This
     requires a new header specification or modification to the SAP spec.
     The alternative is to allow fragmentation of the single SAP packet, or
     to disallow long key certs (limit to max 3 signatories and 512-bit
     keys. */
 
  /* Padding is required to ensure that the authentication info is aligned
     to a 32-bit boundary */
  if(sapauth_p->auth_type==1 || sapauth_p->auth_type==2)
  sapauth_p->pad_len = 4-((sapauth_p->sig_len+2) % 4);
  else
  sapauth_p->pad_len = 4-((sapauth_p->sig_len+sapauth_p->key_len+2) % 4);
  if (sapauth_p->pad_len != 0)
  {
      sapauth_p->padding = 1;
  }
  
  if(sapauth_p->auth_type==1 || sapauth_p->auth_type==2)
  test_len = (sapauth_p->sig_len+2+sapauth_p->pad_len) /4;
  else
  test_len = (sapauth_p->sig_len+sapauth_p->key_len+2+sapauth_p->pad_len) / 4;
  sapauth_p->autlen = test_len;
   
  if (sapauth_p->autlen != test_len) {
     printf ("authentication Header is Two big %d , %d \n", test_len ,sapauth_p->autlen);
     return 2;
  }
  Tcl_VarEval(interp, "pgp_cleanup ", &irandstr, NULL);

  return 1;
}
/* ---------------------------------------------------------------------- */
int generate_encryption_info(char *data, char *encstatus, int irand,char *encmessage)
{
    FILE *enc_fd=NULL;
    FILE *auth_fd=NULL;
    char *code;
    char *homedir, encfulltxt[MAXFILENAMELEN]="";
    char encfullenc[MAXFILENAMELEN]="";
  char *enc_message=NULL;
     int messagelen;

    char irandstr[10]="";
 
   AUTHDEB(printf("++ debug ++ > entered generate_authentication_info\n");)
 
    homedir=(char *)getenv("HOME");
#ifdef WIN32
    sprintf(encfulltxt, "%s\\sdr\\%d.%s", homedir, irand, enctxt_fname);
   sprintf(encfullenc, "%s\\sdr\\%d.%s", homedir, irand, sapenc_fname);
#else
    sprintf(encfulltxt, "%s/.sdr/%d.%s", homedir, irand, enctxt_fname);
    sprintf(encfullenc, "%s/.sdr/%d.%s", homedir, irand, sapenc_fname);
#endif
    sprintf(irandstr, "%d", irand);
 
    auth_fd=fopen(encfulltxt, "w");
    if (auth_fd == NULL)
    {
     printf (" cannot open %s\n", encfulltxt);
     fclose(auth_fd);
    memcpy(encstatus, "failed",6);
      Tcl_VarEval(interp, "enc_pgp_cleanup ", &irandstr, NULL);
     return 0;
    }
    fwrite(data, 1, strlen(data), auth_fd);
    fclose(auth_fd);
 
    /* Executes the TCL script that calls PGP */
    Tcl_VarEval(interp, "pgp_create_encryption ", &irandstr, NULL);
     code = Tcl_GetVar(interp, "recv_result", TCL_GLOBAL_ONLY);
//    printf("\nReturn Code= %d\n", code);
     if (strcmp(interp->result,"1") != 0 )
    {
        printf("File has not been created\n");
        Tcl_VarEval(interp, "enc_pgp_cleanup  ", &irandstr, NULL);
        return 0;
    }
    /* It either works or fails */

    enc_message = Tcl_GetVar(interp, "recv_encmessage", TCL_GLOBAL_ONLY);
  if(enc_message !=NULL)
   {
   messagelen = strlen(enc_message);
   memcpy(encmessage,enc_message,messagelen);
  } else {
 printf(" The Message is empty string %s \n" ,interp->result);
    memcpy(encmessage,"No mesage were produced",24);
 }

    memcpy(encstatus, "Encrypted",9);
     enc_fd= fopen(encfullenc,"r");
/* check to see if it has encrypted the file */
   if (enc_fd == NULL)
  {
      printf("Cannot open %s\n", encfullenc);
      Tcl_VarEval(interp, "enc_pgp_cleanup ", &irandstr, NULL);
      fclose(enc_fd);
 
      return 0;
  }
      fclose(enc_fd);
    return 1;
}
char *check_encryption(struct priv_header *enc_p, char *encinfo,
                         char *data, int data_len, int hdr_len,
                         char *enc_asym_keyid, int irand,char *encmessage)
{
  FILE *enc_fd=NULL;
  char *enc_status=NULL;
  char *enc_message=NULL;
  char *key_id;
   char irandstr[10]="";
 
  char *homedir;
  char encfulltxt[MAXFILENAMELEN]="", encfullenc[MAXFILENAMELEN]="";
 
  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(encfulltxt, "%s\\sdr\\%d.%s", homedir, irand, enctxt_fname);
  sprintf(encfullenc, "%s\\sdr\\%d.%s", homedir, irand, sapenc_fname);
#else
  sprintf(encfulltxt, "%s/.sdr/%d.%s", homedir, irand, enctxt_fname);
  sprintf(encfullenc, "%s/.sdr/%d.%s", homedir, irand, sapenc_fname);
#endif
  sprintf(irandstr, "%d", irand);
 
 
//  printf("data= %s\n", data);
 
  // remove padding, if necessary
  if ( enc_p->padding )
  {
    AUTHDEB(printf("Padding Length=%d\n", *(encinfo+hdr_len-2));)
    AUTHDEB(printf("Padding Length=%d\n", *(encinfo+hdr_len-1));)
    AUTHDEB(printf("Padding Length=%d\n", *(encinfo+hdr_len));)
    hdr_len= (hdr_len-2) - (*(encinfo+hdr_len-1)) ;
  }
 
 
  // Extract the signature and key certificate from the packet and
  // store in files.
 
 
  enc_fd=fopen(encfullenc, "w");
  if (enc_fd == NULL)
  {
    printf("Cannot open %s\n", encfullenc);
 
    fclose(enc_fd);
    Tcl_VarEval(interp, "enc_pgp_cleanup ", &irandstr, NULL);
    return ("failed");
  }
 
  if ( fwrite(data, 1, hdr_len, enc_fd) < hdr_len )
  {
    printf("Error writing SDP data to file\n\r");
    fclose(enc_fd);
    Tcl_VarEval(interp, "enc_pgp_cleanup ", &irandstr, NULL);
    return ("failed");
  }
 
  fclose(enc_fd);
 
 
  /* Executes a TCL script that invokes PGP to check  info */
    AUTHDEB(printf("writing SDP data to file\n\r");)
  Tcl_VarEval(interp, "pgp_check_encryption ", &irandstr, NULL);
  enc_status = Tcl_GetVar(interp, "recv_encstatus", TCL_GLOBAL_ONLY);
  key_id = Tcl_GetVar(interp, "recv_enc_asym_keyid", TCL_GLOBAL_ONLY);
    AUTHDEB(printf("writing SDP data to file\n\r");)
  if(key_id != NULL)
  memcpy(enc_asym_keyid, key_id,8);
  enc_message = Tcl_GetVar(interp, "recv_encmessage", TCL_GLOBAL_ONLY);
  if(enc_message != NULL) 
  memcpy(encmessage,enc_message,strlen(enc_message));
  else {
	printf("The Decryption didnot produce any message %s\n",interp->result);
        memcpy(encmessage,"No Encryption Message",20);
  }
  AUTHDEB(printf(" encstatus %s",enc_status);)
  return (enc_status);
}
int store_encryption_in_memory(struct advert_data *addata, char *enc_type, int irand)
{
  FILE *enc_fd=NULL,*auth_fd=NULL;
  struct stat sbuf;
  struct stat sbufd;
  char *encbuf=NULL,*ac;
  struct priv_header *sapenc_p;
  char *decrypt=NULL;
  char *homedir;
  char encfullenc[MAXFILENAMELEN]="";
  char encfulltxt[MAXFILENAMELEN]="";
  char irandstr[10]="";
  int i;
 
  AUTHDEB(printf("++ debug ++ > entered store_encryption\n");)
 
/* Open all files and read data */
 
  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(encfullenc, "%s\\sdr\\%d.%s", homedir, irand, sapenc_fname);
  sprintf(encfulltxt, "%s\\sdr\\%d.%s", homedir, irand, enctxt_fname);
#else
  sprintf(encfullenc, "%s/.sdr/%d.%s", homedir, irand, sapenc_fname);
  sprintf(encfulltxt, "%s/.sdr/%d.%s", homedir, irand, enctxt_fname);
#endif
  sprintf(irandstr, "%d", irand);
 
  sapenc_p = addata->sapenc_p;
  sapenc_p->version = 1;
 
/* Toadd the encryption used pgp or X509 */
  if (strcmp(enc_type,"pgp") == 0)
    sapenc_p->enc_type = PGP;
  else  if (strcmp(enc_type,"x509") == 0)
    sapenc_p->enc_type = PKCS7;
  else
   sapenc_p->enc_type = 0;
   AUTHDEB(printf("enc_type = %s \n", enc_type);)
 
  enc_fd= fopen(encfullenc,"r");
   if (enc_fd == NULL)
  {
      printf("Cannot open %s\n", encfullenc);
      Tcl_VarEval(interp, "enc_pgp_cleanup ", &irandstr, NULL);
      fclose(enc_fd);

      return 0;
  }
  auth_fd= fopen(encfulltxt,"r");
   if (auth_fd == NULL)
  {
      printf("Cannot open %s\n", encfulltxt);
      Tcl_VarEval(interp, "enc_pgp_cleanup ", &irandstr, NULL);
      fclose(auth_fd);
      return 0;
  }
  stat(encfullenc, &sbuf);
   encbuf =(char *)malloc(sbuf.st_size);
   if(( fread(encbuf,1,  sbuf.st_size ,enc_fd))!= sbuf.st_size)
   {
   fclose(enc_fd);
    free(encbuf);
    }
   AUTHDEB(printf(" encrypted data %s \n", encbuf);)
   sapenc_p->encd_len=sbuf.st_size;
   AUTHDEB(printf(" sapenc_p->encd_len = %d \n", sapenc_p->encd_len);)
   stat(encfulltxt, &sbufd);
   decrypt = (char *)malloc(sbufd.st_size);
    if(( fread(decrypt,1,  sbufd.st_size ,auth_fd))!= sbufd.st_size)
   {
   fclose(auth_fd);
    free(decrypt);
    }

   sapenc_p->txt_len= sbufd.st_size;
  (char *)sapenc_p->txt_data=(char *)malloc(sapenc_p->txt_len);
  memcpy(sapenc_p->txt_data, decrypt, sapenc_p->txt_len);
  fclose(enc_fd);
  fclose(auth_fd);
   
  sapenc_p->pad_len = 4-((sapenc_p->encd_len+2) % 4);
  if (sapenc_p->pad_len != 0)
  {
      sapenc_p->padding = 1;
  }
   sapenc_p->hdr_len = (sapenc_p->pad_len +  sapenc_p->encd_len +2) / 4;
   AUTHDEB(printf(" sapenc_p->hdr_len = %d \n", sapenc_p->hdr_len);)
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
   AUTHDEB(printf(" encrypted data %s \n", sapenc_p->enc_data);)
  free(encbuf);
  free(decrypt);
  Tcl_VarEval(interp, "enc_pgp_cleanup ", &irandstr, NULL);
  return 1;
}
 
#endif
