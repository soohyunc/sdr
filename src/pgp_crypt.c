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

#include <assert.h>
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
#define MAXMSGLEN 1024
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
    char *homedir=NULL, *fulltxt=NULL;
    char *irandstr=NULL;
    char *auth_message=NULL;
    int messagelen;

    writelog(printf("*** edmund  entered generate_authentication_info\n");)

    irandstr = (char *)malloc(10);
    fulltxt = (char *)malloc(MAXFILENAMELEN);
  
    homedir=(char *)getenv("HOME");
#ifdef WIN32
    sprintf(fulltxt, "%s\\sdr\\%d.%s", homedir, irand, authtxt_fname);
#else
    sprintf(fulltxt, "%s/.sdr/%d.%s", homedir, irand, authtxt_fname);
#endif
    sprintf(irandstr, "%d", irand);

    writelog(printf("generate_authentication_info filename is %s\n",fulltxt);)

    auth_fd=fopen(fulltxt, "w");
    if (auth_fd == NULL) {
     writelog(printf (" cannot open %s\n", fulltxt);)
     fclose(auth_fd);
     memcpy(authstatus, "failed",6);
     Tcl_VarEval(interp, "pgp_cleanup  ", irandstr, NULL);
     return 0;
    }
    fwrite(data, 1, len, auth_fd);
    fclose(auth_fd);
 
    /* Executes the TCL script that calls PGP */
    Tcl_VarEval(interp, "pgp_create_signature ",  irandstr, NULL);
    code = Tcl_GetVar(interp, "recv_result", TCL_GLOBAL_ONLY); 
    writelog(printf("\nReturn Code= %s\n", code);)
    if (strcmp(code,"1") != 0 ) {
        writelog(printf("INCORRECT PASSWORD OR File not created\n"); )
        Tcl_VarEval(interp, "pgp_cleanup  ", irandstr, NULL);
        return 0;
    }
    auth_message = Tcl_GetVar(interp, "recv_authmessage", TCL_GLOBAL_ONLY);
    messagelen = strlen(auth_message);
 
    strcpy(authmessage,auth_message);
    strcpy(authstatus, "Authenticated");

    writelog(printf("generate_authentication_info: authmessage = \n%s\n",auth_message);)
    writelog(printf("generate_authentication_info: authstatus  = %s",authstatus);)

    free(irandstr);
    free(fulltxt);
    return 1;
}
 
/* ---------------------------------------------------------------------- */
/* check_authentication - processes incoming authentication info for      */
/*                        integrity and assurance of originator           */
/* ---------------------------------------------------------------------- */
char *check_authentication(struct auth_header *auth_p, char *authinfo,
                         char *data, int data_len, int auth_len,
                         char *asym_keyid, int irand,char *authmessage)
{
  FILE *sig_fd=NULL, *key_fd=NULL, *auth_fd=NULL;
  int sig_len, key_len, pad_len, messagelen;
  char *key_id=NULL, *auth_status=NULL, *auth_message=NULL;
  char *homedir=NULL;
  char *fulltxt=NULL, *fullsig=NULL, *fullkey=NULL, *irandstr=NULL;

  fulltxt  = (char *)malloc(MAXFILENAMELEN);
  fullsig  = (char *)malloc(MAXFILENAMELEN);
  fullkey  = (char *)malloc(MAXFILENAMELEN);
  irandstr = (char *)malloc(10);
 
  writelog(printf("entered check_authentication\n");)
  writelog(printf("check_auth: auth_p      = %d\n",&auth_p);)
  writelog(printf("check_auth: authinfo    = %s\n",authinfo);)
  writelog(printf("check_auth: data        = %s\n",data);)
  writelog(printf("check_auth: data_len    = %d\n",data_len);)
  writelog(printf("check_auth: auth_len    = %d\n",auth_len);)
  writelog(printf("check_auth: asym_keyid  = %s\n",asym_keyid);)
  writelog(printf("check_auth: irand       = %d\n",irand);)
  writelog(printf("check_auth: authmessage = %s\n",authmessage);)

  sig_len = auth_p->siglen * 4;
  key_len = auth_len - sig_len - 2;

/* remove padding, if necessary */

  if ( auth_p->padding )
  {
    pad_len  = *(authinfo+(auth_len-2)-1);
    key_len -= pad_len;
    writelog(printf("Padding Length=%d\n", *(authinfo+(auth_len-2)-1));)
  }
 
/* quick check to see if things look okay */

  if ( auth_p->auth_type == 1 && key_len != 0 ) {
    writelog(printf("check_auth: Error: have authtype %d and key_len %d\n",auth_p->auth_type,key_len);)
    return("failed");

  }

  writelog(printf("Key Certificate=%d bytes\n", key_len);)
 
  /* Extract the signature and key certificate from the packet and */
  /* store in files. */

  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(fulltxt, "%s\\sdr\\%d.%s", homedir, irand, authtxt_fname);
  sprintf(fullsig, "%s\\sdr\\%d.%s", homedir, irand, authsig_fname);
  sprintf(fullkey, "%s\\sdr\\%d.%s", homedir, irand, authkey_fname);
#else
  sprintf(fulltxt, "%s/.sdr/%d.%s", homedir, irand, authtxt_fname);
  sprintf(fullsig, "%s/.sdr/%d.%s", homedir, irand, authsig_fname);
  sprintf(fullkey, "%s/.sdr/%d.%s", homedir, irand, authkey_fname);
#endif
  sprintf(irandstr, "%d", irand);

/* signature file */

  sig_fd=fopen(fullsig, "w");
  if (sig_fd == NULL)
  {
    writelog(printf("Cannot open %s\n", fullsig);)
    fclose(sig_fd);
    Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
    return ("failed");
  } else {
    if ( fwrite(authinfo, 1, sig_len, sig_fd) < sig_len )
    {
      writelog(printf("Error writing signature to file\n\r");)
      fclose(sig_fd);
      Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
      return ("failed");
    }
    fclose(sig_fd);
  }
  free(fullsig);

/* key file */
 
  key_fd=fopen(fullkey, "w");
  if (key_fd == NULL)
  {
    writelog(printf("Cannot open %s\n", fullkey);)
    fclose(key_fd);
    Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
    return ("failed");
  } else {
    writelog(printf(" check auth_p->auth_type %d\n",auth_p->auth_type);)
    if (auth_p->auth_type == 3 || auth_p->auth_type == 4)
    {
      authinfo += sig_len;
      if ( fwrite(authinfo, 1, key_len, key_fd) < key_len )
      {
        writelog(printf("Error writing key certificate to file\n\r");)
        fclose(key_fd);
        Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
        return ("failed");
      } else {
        fclose(key_fd);
      }
    }
  }
  free(fullkey);
 
/* REMINDER: need to store end_time and keyid too if encrypted session    */
/* Refer to SAP spec for encrypted announcements with authentication!     */

/* authentication file */

  auth_fd=fopen(fulltxt, "w");
  if (auth_fd == NULL)
  {
    writelog(printf("Cannot open %s\n", fulltxt);)
    fclose(auth_fd);
    Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
    return ("failed");
  } else {
    if ( fwrite(data, 1, data_len, auth_fd) < data_len )
    {
      writelog(printf("Error writing SDP data to file\n\r");)
      fclose(auth_fd);
      Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
      return ("failed");
    } else {
      fclose(auth_fd);
    }
  }
  free(fulltxt);
 
/* Executes a TCL script that invokes PGP to check signature info */

  Tcl_VarEval(interp, "pgp_check_authentication ", irandstr, NULL);
 
/* The script returns the (PGP)Key ID used and the authentication status  */
/* (either FAILED, INTEGRITY (only), or TRUSTWORTHY)                      */

  key_id = Tcl_GetVar(interp, "recv_asym_keyid", TCL_GLOBAL_ONLY);
  if (key_id != NULL) {
    memcpy(asym_keyid, key_id, 8);
  }

  auth_status  = Tcl_GetVar(interp, "recv_authstatus",  TCL_GLOBAL_ONLY);
  auth_message = Tcl_GetVar(interp, "recv_authmessage", TCL_GLOBAL_ONLY);

  if(auth_message != NULL) {
    messagelen = strlen(auth_message);
    writelog(printf("edmund:c_a: messagelen   = %d\n",messagelen);)
    writelog(printf("edmund:c_a: auth_message = %s\n",auth_message);)
    writelog(printf("edmund:c_a: auth_status  = %s\n",auth_status);)
    memcpy(authmessage,auth_message,messagelen);
  } else {
    writelog(printf("edmund:c_a: auth_message is NULL (error was %s)\n",interp->result);)
    strcpy(authmessage,"No message was produced");
    return ("failed");
 }

  writelog(printf("edmund: c_a: authstatus at return = %s\n",auth_status);)
  free(irandstr);
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
  FILE *sig_fd=NULL, *key_fd=NULL;
  struct stat sbuf;
  struct stat sbufk;
  struct auth_header *sapauth_p;
  char *keycert=NULL,*homedir=NULL,*irandstr=NULL;
  char *fullsig=NULL,*fullkey=NULL, *encsig=NULL;
  int test_len;
 
  writelog(printf("Entered store_authentication_in_memory\n");)

/* Open all files and read data */

  fullsig  = (char *)malloc(MAXFILENAMELEN);
  fullkey  = (char *)malloc(MAXFILENAMELEN);
  irandstr = (char *)malloc(10);

  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(fullsig, "%s\\sdr\\%d.%s", homedir, irand, authsig_fname);
  sprintf(fullkey, "%s\\sdr\\%d.%s", homedir, irand, authkey_fname);
#else
  sprintf(fullsig, "%s/.sdr/%d.%s",  homedir, irand, authsig_fname);
  sprintf(fullkey, "%s/.sdr/%d.%s",  homedir, irand, authkey_fname);
#endif

  sprintf(irandstr, "%d", irand);

  writelog(printf("store_auth: fullsig = %s\n",fullsig);)
  writelog(printf("store_auth: fullkey = %s\n",fullkey);)

  sapauth_p = addata->sapauth_p;
  sapauth_p->version = 1;

/* signature file */

  sig_fd=fopen(fullsig, "r");
  if (sig_fd == NULL) {
    writelog(printf("Cannot open %s\n", fullsig);)
    Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
    fclose(sig_fd);
    return 0;
  } else {
    stat(fullsig,&sbuf);
/* set up temporary signature memory */
    encsig = (char *)malloc(sbuf.st_size);
    if(( fread(encsig,1,  sbuf.st_size ,sig_fd))!= sbuf.st_size) {
      writelog(printf("store_auth: problem reading in sig file\n");)
      fclose(sig_fd);
      return 0;
    }
    sapauth_p->sig_len = sbuf.st_size;
    if ((sapauth_p->siglen) % 4 != 0) {
      writelog(printf( " Signature is not a Multiple of 4\n");)
      sapauth_p->siglen = (sapauth_p->sig_len +1) / 4 ;
      sapauth_p->signature = (char *)malloc(sapauth_p->sig_len+1);
      memcpy (sapauth_p->signature, encsig,sapauth_p->sig_len);
      memcpy(sapauth_p->signature+1,'\0',1);
    } else {
      sapauth_p->siglen = (sapauth_p->sig_len) / 4 ;
      writelog(printf( "signature length is %d\n",sapauth_p->siglen);)
      sapauth_p->signature = (char *)malloc(sapauth_p->sig_len);
      memcpy (sapauth_p->signature, encsig,sapauth_p->sig_len);
    }
    writelog(printf("%d chars read of signature\n", sapauth_p->sig_len);)
    fclose(sig_fd);
    free(encsig);
  }
  free(fullsig);

/* read in key file */

  if( strncmp(auth_type,"cpgp",4) == 0 || strncmp(auth_type,"cx50",4) == 0) { 
    key_fd=fopen(fullkey, "r");
    if (key_fd == NULL) {
      writelog(printf("Cannot open %s\n", fullkey);)
      Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
      fclose(key_fd);
      return 0;
    } else {
/* set yp temporary key memory */
      stat(fullkey,&sbufk);
      keycert = (char *)malloc(sbufk.st_size);
      if(( fread(keycert,1,  sbufk.st_size ,key_fd))!= sbufk.st_size) {
        writelog(printf("problem reading in key file for authentication\n");)
        fclose(key_fd);
        free(keycert);
      } else {
        sapauth_p->key_len = sbufk.st_size;
        sapauth_p->keycertificate=(char *)malloc(sapauth_p->key_len);
        memcpy(sapauth_p->keycertificate,keycert,sapauth_p->key_len);

        if (sapauth_p->key_len > 1024 ) {
          writelog(printf("Sorry, Key Certificate is too large...\n");)
          sapauth_p->key_len = 0;
        }
        writelog(printf("%d chars read of key certificate\n\r", sapauth_p->key_len);)
        fclose(key_fd);
        free(keycert);
      }
    }
  } else {
    sapauth_p->key_len =0;
    sapauth_p->keycertificate=NULL;
  }
  free(fullkey);

/* To add the authetication used pgp or X509 Plus the certificate*/

  if (memcmp(auth_type,"cpgp",4) == 0) {
    sapauth_p->auth_type = 3;
  } else  if (memcmp(auth_type,"cx50",4) == 0) {
    sapauth_p->auth_type = 4;
  } else  if (memcmp(auth_type,"pgp", 3) == 0) {
    sapauth_p->auth_type = 1;
  } else  if (memcmp(auth_type,"x509",4) == 0) {
    sapauth_p->auth_type = 2;
  } else {
    writelog(printf("something is wrong auth_type isnot pgp or x509\n");)
  }
  writelog(printf("auth_type = %s \n", auth_type);)
     
/* There actually needs to be a better check here: if the total length of  */
/* the SAP packet (including SAP header, data, encryption info, and        */
/* authentication info) exceeds the MAXADSIZE value, then the entire       */
/* key certificate should be transmitted in a separated packet.  This      */
/* requires a new header specification or modification to the SAP spec.    */
/* The alternative is to allow fragmentation of the single SAP packet, or  */
/* to disallow long key certs (limit to max 3 signatories and 512-bit keys */
 
/* Padding is required to ensure that auth info aligned to 32-bit boundary */

  if(sapauth_p->auth_type==1 || sapauth_p->auth_type==2) {
    sapauth_p->pad_len = 4-((sapauth_p->sig_len+2) % 4);
  } else {
    sapauth_p->pad_len = 4-((sapauth_p->sig_len+sapauth_p->key_len+2) % 4);
  }

  if (sapauth_p->pad_len != 0) {
      sapauth_p->padding = 1;
  }
  
  if(sapauth_p->auth_type==1 || sapauth_p->auth_type==2) {
    test_len = (sapauth_p->sig_len+2+sapauth_p->pad_len) /4;
  } else {
    test_len = (sapauth_p->sig_len+sapauth_p->key_len+2+sapauth_p->pad_len) / 4;
  }

  sapauth_p->autlen = test_len;
  if (sapauth_p->autlen != test_len) {
    writelog(printf ("auth header too big %d , %d \n", test_len ,sapauth_p->autlen);)
    return 2;
  }

  Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
  free(irandstr);
  return 1;
}
/* ---------------------------------------------------------------------- */
int generate_encryption_info(char *data, char *encstatus, int irand,char *encmessage)
{
    FILE *enc_fd=NULL;
    FILE *auth_fd=NULL;
    char *code;
    char *homedir=NULL, *encfulltxt=NULL, *encfullenc=NULL;
    char *irandstr=NULL;
    char *enc_message=NULL;
    int  messagelen;
 
    writelog(printf("entered generate_encryption\n");)
 
    encfulltxt  = (char *)malloc(MAXFILENAMELEN);
    encfullenc  = (char *)malloc(MAXFILENAMELEN);
    irandstr    = (char *)malloc(10);

    homedir=(char *)getenv("HOME");
#ifdef WIN32
    sprintf(encfulltxt, "%s\\sdr\\%d.%s", homedir, irand, enctxt_fname);
    sprintf(encfullenc, "%s\\sdr\\%d.%s", homedir, irand, sapenc_fname);
#else
    sprintf(encfulltxt, "%s/.sdr/%d.%s", homedir, irand, enctxt_fname);
    sprintf(encfullenc, "%s/.sdr/%d.%s", homedir, irand, sapenc_fname);
#endif
    sprintf(irandstr, "%d", irand);

    writelog(printf("gen_enc: encfulltxt = %s\n",encfulltxt);)
    writelog(printf("gen_enc: encfullenc = %s\n",encfullenc);)
 
/* encryption file */

    auth_fd=fopen(encfulltxt, "w");
    if (auth_fd == NULL) {
     writelog(printf(" cannot open %s\n", encfulltxt);)
     fclose(auth_fd);
     memcpy(encstatus, "failed",6);
     Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
     return 0;
    } else {
      fwrite(data, 1, strlen(data), auth_fd);
      fclose(auth_fd);
    }
 
/* Executes the TCL script that calls PGP */

    Tcl_VarEval(interp, "pgp_create_encryption ", irandstr, NULL);

    code = Tcl_GetVar(interp, "recv_result", TCL_GLOBAL_ONLY);
    if (strcmp(interp->result,"1") != 0 ) {
      /* printf("File has not been created\n"); */
      Tcl_VarEval(interp, "enc_pgp_cleanup  ", irandstr, NULL);
      return 0;
    }

/* It either works or fails */

    enc_message = Tcl_GetVar(interp, "recv_encmessage", TCL_GLOBAL_ONLY);
    if(enc_message !=NULL) {
     messagelen = strlen(enc_message);
     memcpy(encmessage,enc_message,messagelen);
    } else {
     writelog(printf(" The Message is empty string, Result is %s \n" ,interp->result);)
     memcpy(encmessage,"No mesage were produced",24);
    }

    memcpy(encstatus, "Encrypted",9);

/* check to see if it has encrypted the file */

    enc_fd= fopen(encfullenc,"r");
    if (enc_fd == NULL) {
      writelog(printf("Cannot open %s\n", encfullenc);)
      Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
      fclose(enc_fd);
      return 0;
    }
    fclose(enc_fd);

    free(irandstr);
    free(encfullenc);
    free(encfulltxt);

    return 1;
}
char *check_encryption(struct priv_header *enc_p, char *encinfo,
                         char *data, int data_len, int hdr_len,
                         char *enc_asym_keyid, int irand,char *encmessage)
{
  FILE *enc_fd=NULL;
  char *enc_status_p=NULL, enc_status[10];
  char *enc_message=NULL, *key_id=NULL, *irandstr=NULL, *homedir=NULL;
  char *encfulltxt=NULL, *encfullenc=NULL;
 
  writelog(printf("*** edmund entered check_encryption");)
  homedir=getenv("HOME");
  writelog(printf("check_encryption: homedir = %s ; irand = %d\n",homedir,irand);)

  encfulltxt = (char *)malloc(MAXFILENAMELEN);
  encfullenc = (char *)malloc(MAXFILENAMELEN);
  irandstr   = (char *)malloc(10);

#ifdef WIN32
  sprintf(encfulltxt, "%s\\sdr\\%d.%s", homedir, irand, enctxt_fname);
  sprintf(encfullenc, "%s\\sdr\\%d.%s", homedir, irand, sapenc_fname);
#else
  sprintf(encfulltxt, "%s/.sdr/%d.%s", homedir, irand, enctxt_fname);
  sprintf(encfullenc, "%s/.sdr/%d.%s", homedir, irand, sapenc_fname);
#endif
  sprintf(irandstr, "%d", irand);
 
  writelog(printf("edmund: check_encryption: encfulltxt = %s\n",encfulltxt);)
  writelog(printf("edmund: check_encryption: encfullenc = %s\n",encfullenc);)

/* remove padding, if necessary */

  if ( enc_p->padding )
  {
    writelog(printf("Padding Length=%d\n", *(encinfo+hdr_len-2));)
    writelog(printf("Padding Length=%d\n", *(encinfo+hdr_len-1));)
    writelog(printf("Padding Length=%d\n", *(encinfo+hdr_len));)
    hdr_len= (hdr_len-2) - (*(encinfo+hdr_len-1)) ;
  }
 
/* Extract signature and certificate from packet and store in files  */
 
  enc_fd=fopen(encfullenc, "w");
  if (enc_fd == NULL)
  {
    writelog(printf("Cannot open %s\n", encfullenc);)
    fclose(enc_fd);
    Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
    return ("failed");
  }
 
  if ( fwrite(data, 1, hdr_len, enc_fd) < hdr_len )
  {
    writelog(printf("Error writing SDP data to file\n\r");)
    fclose(enc_fd);
    Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
    return ("failed");
  }
  fclose(enc_fd);
 
/* Executes a TCL script that invokes PGP to check  info */

  writelog(printf("edmund: check_encryption: calling pgp_check_encryption \n");)

  Tcl_VarEval(interp, "pgp_check_encryption ", irandstr, NULL);
  enc_status_p = Tcl_GetVar(interp, "recv_encstatus", TCL_GLOBAL_ONLY);
  if (enc_status_p == NULL) {
    return ("failed");
  } else {
    writelog(printf("edmund:c_e: strlen(enc_status_p) = %d\n",strlen(enc_status_p));)
    memcpy(enc_status,enc_status_p,strlen(enc_status_p));
    writelog(printf("edmund:c_e: enc_status = %s\n",enc_status);)
  }

  key_id = Tcl_GetVar(interp, "recv_enc_asym_keyid", TCL_GLOBAL_ONLY);
  if (key_id == NULL) {
    return ("failed");
  } else {
    assert(strlen(key_id) < 9);
    memcpy(enc_asym_keyid, key_id, strlen(key_id));
    writelog(printf("edmund: c_e: enc_asym_keyid = %s\n",enc_asym_keyid);)
  }

  enc_message = Tcl_GetVar(interp, "recv_encmessage", TCL_GLOBAL_ONLY);
  if (enc_message == NULL) {
    writelog(printf("The Decryption did not produce any message %s\n",interp->result);)
    strcpy(encmessage,"No Encryption Message");
    return ("failed");
  } else {
    writelog(printf("strlen(enc_message) = %d\n",strlen(enc_message));)
    memcpy(encmessage,enc_message,strlen(enc_message));
    writelog(printf("edmund:c_e: encmessage = %s\n",encmessage);)
  }

  writelog(printf("edmund:c_e: encstatus %s\n",enc_status);)

  free(encfullenc);
  free(encfulltxt);
  free(irandstr);

/* enc_status is not a well terminated string - should be sorted out earlier */
/* but as a quick fix just look at the first 7 characters :)                 */
  if ( strncmp(enc_status, "success",7) == 0 ) {
    return ("success");
  } else {
    return ("failed");
  }

}
int store_encryption_in_memory(struct advert_data *addata, char *enc_type, int irand)
{
  FILE *enc_fd=NULL,*auth_fd=NULL;
  struct stat sbuf;
  struct stat sbufd;
  char *encbuf=NULL,*ac;
  struct priv_header *sapenc_p;
  char *decrypt=NULL;
  char *homedir=NULL;
  char *encfullenc=NULL, *encfulltxt=NULL;
  char *irandstr=NULL;
  int i;
 
  writelog(printf("entered store_encryption\n");)
 
/* Open all files and read data */
 
  encfullenc = (char *)malloc(MAXFILENAMELEN);
  encfulltxt = (char *)malloc(MAXFILENAMELEN);
  irandstr   = (char *)malloc(10);

  homedir=(char *)getenv("HOME");
#ifdef WIN32
  sprintf(encfullenc, "%s\\sdr\\%d.%s", homedir, irand, sapenc_fname);
  sprintf(encfulltxt, "%s\\sdr\\%d.%s", homedir, irand, enctxt_fname);
#else
  sprintf(encfullenc, "%s/.sdr/%d.%s", homedir, irand, sapenc_fname);
  sprintf(encfulltxt, "%s/.sdr/%d.%s", homedir, irand, enctxt_fname);
#endif
  sprintf(irandstr, "%d", irand);
 
  writelog(printf("edmund: store_enc: encfulltxt = %s\n",encfulltxt);)
  writelog(printf("edmund: store_enc: encfullenc = %s\n",encfullenc);)

  sapenc_p = addata->sapenc_p;
  sapenc_p->version = 1;
 
/* set up the encryption type */

  if (strcmp(enc_type,"pgp") == 0) {
    sapenc_p->enc_type = PGP;
  } else  if (strcmp(enc_type,"x509") == 0) {
    sapenc_p->enc_type = PKCS7;
  } else {
   sapenc_p->enc_type = 0;
  }
  writelog(printf("store_enc: enc_type = %s \n", enc_type);)
 
/* open encryption file */

  enc_fd= fopen(encfullenc,"r");
  if (enc_fd == NULL) {
    writelog(printf("Cannot open %s\n", encfullenc);)
    Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
    fclose(enc_fd);
    return 0;
  }

/* open txt file */

  auth_fd= fopen(encfulltxt,"r");
  if (auth_fd == NULL) {
    writelog(printf("Cannot open %s\n", encfulltxt);)
    Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
    fclose(auth_fd);
    return 0;
  }

/* read encrypted data in */

  stat(encfullenc, &sbuf);
  encbuf =(char *)malloc(sbuf.st_size);
  if(( fread(encbuf,1,  sbuf.st_size ,enc_fd))!= sbuf.st_size) {
    writelog(printf("store_enc: problem reading encrypted file\n");)
    fclose(enc_fd);
    free(encbuf);
   }
#ifdef EDNEVER
   writelog(printf(" encrypted data %s \n", encbuf);)
#endif
   sapenc_p->encd_len=sbuf.st_size;
   writelog(printf("store_enc:  sapenc_p->encd_len = %d \n", sapenc_p->encd_len);)

/* read txt file in */

   stat(encfulltxt, &sbufd);
   decrypt = (char *)malloc(sbufd.st_size);
   if(( fread(decrypt,1,  sbufd.st_size ,auth_fd))!= sbufd.st_size) {
     writelog(printf("store_enc: problem reading plaintext file\n");)
     fclose(auth_fd);
     free(decrypt);
   }

  sapenc_p->txt_len= sbufd.st_size;
/*  sapenc_p->txt_data=(char *)malloc(sapenc_p->txt_len); */
  sapenc_p->txt_data=(char *)malloc(sbufd.st_size);
  memcpy(sapenc_p->txt_data, decrypt, sbufd.st_size);

/* close the files */

  fclose(enc_fd);
  fclose(auth_fd);
   
  sapenc_p->pad_len = 4-((sapenc_p->encd_len+2) % 4);
  if (sapenc_p->pad_len != 0) {
      sapenc_p->padding = 1;
  }

  sapenc_p->hdr_len = (sapenc_p->pad_len +  sapenc_p->encd_len +2) / 4;
  writelog(printf("store_enc:  sapenc_p->hdr_len = %d \n", sapenc_p->hdr_len);)
  sapenc_p->enc_data =(char *)malloc(sapenc_p->pad_len +  sapenc_p->encd_len);
  memcpy(sapenc_p->enc_data,encbuf, sapenc_p->encd_len);
  ac=(char *)(sapenc_p->enc_data)+sapenc_p->encd_len;

  if (sapenc_p->pad_len != 0) {
    for (i=0; i<(sapenc_p->pad_len-1); ++i) {
      ac[i] = 0;
    }
    ac[i] = sapenc_p->pad_len;
  }
  writelog(printf("store_enc: encrypted data %s \n", sapenc_p->enc_data);)

  free(encbuf);
  free(decrypt);

  Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
  free(encfullenc);
  free(encfulltxt);
  free(irandstr);

  return 1;
}
 
#endif
