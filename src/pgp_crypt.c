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
#ifndef WIN32
#include <fcntl.h>
#endif

extern struct keydata* keylist;
extern char passphrase[MAXKEYLEN];
extern Tcl_Interp *interp;

/*#define DEBUG*/

#define MAXMSGLEN 1024
char *authtxt_fname="txt";
char *authsig_fname="sig";
char *authkey_fname="pgp";
char *enctxt_fname="txt";
char *sapenc_fname="pgp";

/* ---------------------------------------------------------------------- */
/* generate_authentication_info                                           */
/*                                                                        */
/* 1) write data to file - irand.txt                                      */
/* 2) call pgp_create_signature - output written to irand.sig             */
/* 3) read in irand.sig and store this in the addata->authinfo struture   */
/* 4) fill in the rest of the advert_data->authinfo structure             */
/*                                                                        */
/* ---------------------------------------------------------------------- */
int generate_authentication_info(char *data,
                                  int len, 
                                 char *authstatus, 
                                 char *authmessage,
				  int authmessagelen,
                   struct advert_data *addata,
                                 char *auth_type)
{
    FILE *auth_fd=NULL, *sig_fd=NULL;

    struct auth_info *authinfo;
    struct stat sbuf;
    char *fulltxt=NULL, *fullsig=NULL;
    char *homedir=NULL;
    char *irandstr=NULL;
    char *code=NULL;
    char *auth_message=NULL;
    char *encsig=NULL;
    int  irand;
    int tmplength;

    writelog(printf("entered generate_authentication_info\n");)

/* generate a random number to be used as a unique file identifier */

    irand    = (lbl_random()&0xffff);

/* malloc the filename space */

    fulltxt  = (char *)malloc(MAXFILENAMELEN);
    fullsig  = (char *)malloc(MAXFILENAMELEN);

#ifdef WIN32
	homedir  = (char *)getenv("HOMEDIR");
    sprintf(fulltxt, "%s\\sdr\\%d.%s", homedir, irand, authtxt_fname);
    sprintf(fullsig, "%s\\sdr\\%d.%s", homedir, irand, authsig_fname);
#else
    homedir  = (char *)getenv("HOME");
    sprintf(fulltxt, "%s/.sdr/%d.%s",  homedir, irand, authtxt_fname);
    sprintf(fullsig, "%s/.sdr/%d.%s",  homedir, irand, authsig_fname);
#endif

    writelog(printf("gen_auth_info fulltxt is %s\n",fulltxt);)
    writelog(printf("gen_auth_info fullsig is %s\n",fullsig);)

/* need the random number as a string for use in tcl code (pgp) */

    irandstr = (char *)malloc(10);
    sprintf(irandstr, "%d", irand);

/* open a file (irand.txt) and write the data to it for use by PGP */

    auth_fd=fopen(fulltxt, "w");
    if (auth_fd == NULL) {
      writelog(printf ("Cannot open %s\n", fulltxt);)
      strcpy(authstatus, "failed");
      Tcl_VarEval(interp, "pgp_cleanup  ", irandstr, NULL);
      return 1;
    } else {
      fwrite(data, 1, len, auth_fd);
      fclose(auth_fd);
    }
    free(fulltxt);

/* Call PGP to generate the signature file (irand.sig) */

    Tcl_VarEval(interp, "pgp_create_signature ", irandstr, NULL);
    code = Tcl_GetVar(interp, "recv_result", TCL_GLOBAL_ONLY); 
    writelog(printf("rc from pgp_create_signature = %s\n", code);)

/* Check return code - 0 = okay, 1 = problem */

    if (strncmp(code,"0",1) != 0 ) {
      writelog(printf("PGP file not created or incorrect PGP password\n"); )
      Tcl_VarEval(interp, "pgp_cleanup  ", irandstr, NULL);
      return 1;
    } else {
      auth_message = Tcl_GetVar(interp, "recv_authmessage", TCL_GLOBAL_ONLY);
      strncpy(authmessage,auth_message, authmessagelen);
      strcpy(authstatus, "Authenticated");
    }

    writelog(printf("gen_auth_info: authmessage :\n%s\n",authmessage);)
    writelog(printf("gen_auth_info: authstatus  = %s\n",authstatus);)

/* now we want to read the signature and possibly key into advert_data      */
/* set authinfo to point to the authinfo part of main advert_data structure */

    authinfo = addata->authinfo;

/* open the file which should have been output by PGP (irand.sig) */

    sig_fd = fopen(fullsig, "r");

    if (sig_fd == NULL) {
      writelog(printf("gen_auth_info: cannot open %s\n", fullsig);)
      Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
      return 1;
    } else { 

/* read in file to temporary signature memory */
/* checking that read in the whole file       */

      stat(fullsig,&sbuf);
      encsig = (char *)malloc(sbuf.st_size);

      if (( fread(encsig,1,  sbuf.st_size ,sig_fd))== sbuf.st_size) {
        authinfo->sig_len = sbuf.st_size;
        writelog(printf("gen_auth_info: sig_len = %d\n", authinfo->sig_len);)

/* check the signature is a multiple of 4 bytes and divide by 4 to get */
/* size in words to include in the SAP header (space constraints)      */
/* how does adding 1 guarantee it is divisible by 4 ?                  */

        if ((authinfo->sig_len % 4) != 0) {
          writelog(printf( "gen_auth_info: signature not a multiple of 4\n");)
#ifdef NEVER
          authinfo->siglen = (authinfo->sig_len +1) / 4 ;
          authinfo->signature = (char *)malloc(authinfo->sig_len+1);
          memcpy (authinfo->signature, encsig,authinfo->sig_len);
#else
/* siglen needed so know where certificate starts - the cert is no longer */
/* sent so always set this to 0                                           */

          authinfo->siglen = 0;
          authinfo->signature = (char *)malloc(authinfo->sig_len);
          memcpy (authinfo->signature, encsig,authinfo->sig_len);
#endif

        } else {

#ifdef NEVER
          authinfo->siglen    = (authinfo->sig_len) / 4 ;
#else
          authinfo->siglen    = 0;                   /* see comment above */
#endif
          tmplength = (int)authinfo->sig_len;
          authinfo->signature = (char *)malloc(tmplength);
          memcpy (authinfo->signature, encsig, authinfo->sig_len);
        }
        fclose(sig_fd);
        free(encsig);

      } else {
/* amount read in doesn't match length of file */
        writelog(printf("gen_auth_info: problem reading in sig file\n");)
        fclose(sig_fd);
        Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
        return 1;
      }
    }

    free(fullsig);

/* have now read in sig file into the advert_data structure */
/* Now fill in the rest of the advert_data -> authinfo      */

/* auth_type */

  if (memcmp(auth_type,"pgp",3) == 0) {
    authinfo->auth_type = 1;
  } else {
    writelog(printf("gen_auth_info: unknown auth_type: (%s)\n", auth_type);)
  }

/* padding - must be aligned to 32-bit boundary and                      */
/* there is a 2 byte auth_header - 2nd byte is signature length. This is */
/* not in agreement with the spec as the sig length shouldn't be there   */

  authinfo->pad_len = 4-((authinfo->sig_len+AUTH_HEADER_LEN) % 4);
  if (authinfo->pad_len == 4) {
    authinfo->pad_len = 0;
  }
  authinfo->autlen  = (authinfo->sig_len+2+authinfo->pad_len) / 4 ;

/* padding bit */

  if (authinfo->pad_len != 0) {
      authinfo->padding = 1;
  }

/* version - always 1 at moment */

  authinfo->version = 1;

/* clean up the PGP files */

  Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
  free(irandstr);

  return 0;
}

/* ---------------------------------------------------------------------- */
/* check_authentication - processes incoming authentication info for      */
/*                        integrity and assurance of originator           */
/* ---------------------------------------------------------------------- */
char *check_authentication(struct auth_header *auth_p, 
                        char *data, 
			int  data_len, 
			int  auth_len,
                        char *asym_keyid, 
			char *authmessage,
			int  authmessagelen,
			struct advert_data *addata, 
			char *auth_type)
{
    FILE *auth_fd=NULL, *sig_fd=NULL;
    char *fulltxt=NULL, *fullsig=NULL;
    char *homedir=NULL;
    char *irandstr=NULL;
  
    int irand, sig_len, pad_len, messagelen;
    char *key_id=NULL, *auth_status=NULL, *auth_message=NULL;
    char *tmpauth_status=NULL;

    struct auth_info *authinfo;
  
    writelog(printf("entered check_authentication\n");)

/* generate a random number to be used as a unique file identifier */

    irand    = (lbl_random()&0xffff);

/* malloc the filename space */

    fulltxt  = (char *)malloc(MAXFILENAMELEN);
    fullsig  = (char *)malloc(MAXFILENAMELEN);

#ifdef WIN32
    homedir  = (char *)getenv("HOMEDIR");
    sprintf(fulltxt, "%s\\sdr\\%d.%s", homedir, irand, authtxt_fname);
    sprintf(fullsig, "%s\\sdr\\%d.%s", homedir, irand, authsig_fname);
#else
    homedir  = (char *)getenv("HOME");
    sprintf(fulltxt, "%s/.sdr/%d.%s", homedir, irand, authtxt_fname);
    sprintf(fullsig, "%s/.sdr/%d.%s",  homedir, irand, authsig_fname);
#endif

    writelog(printf("chk_auth fulltxt is %s\n",fulltxt);)
    writelog(printf("chk_auth fullsig is %s\n",fullsig);)

/* need the random number as a string for use in tcl code (pgp) */

    irandstr = (char *)malloc(10);
    sprintf(irandstr, "%d", irand);

/* remove padding, if necessary */

    if ( auth_p->padding ) {
      pad_len = *((char *)auth_p+auth_len-1);
      writelog(printf("chk_auth: pad len=%d\n",pad_len);)
    } else {
      pad_len = 0;
    }

/* determine length of key and signature - sending key is obsolete  */

    sig_len = auth_len - pad_len - AUTH_HEADER_LEN;
    writelog(printf("sig_len = auth_len (%d) - pad_len (%d) - 2 = %d\n",auth_len,pad_len,sig_len);)

/* Extract the signature and store in files */

  Tcl_Eval(interp, "pgpstate");
  if (strcmp(interp->result,"1") == 0) {

/* signature file - irand.sig */

    sig_fd=fopen(fullsig, "w");
    if (sig_fd == NULL) {
      writelog(printf("chk_auth: cannot open %s\n", fullsig);)
      Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
      return ("failed");
    } else {
      if (sig_len > MAXADSIZE) {
        fprintf(stderr, "chk_auth: sig_len impossibly large: %d\n",sig_len);
        abort();
      }
      if ( fwrite((char *)auth_p+AUTH_HEADER_LEN, 1, sig_len, sig_fd) < sig_len ) {
        writelog(printf("chk_auth: error writing signature to file\n");)
        fclose(sig_fd);
        Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
        return ("failed");
      }
      fclose(sig_fd);
    }
    free(fullsig);
  
/* REMINDER: need to store end_time and keyid too if encrypted session    */
/* Refer to SAP spec for encrypted announcements with authentication!     */

/* authentication file - irand.txt */

    auth_fd=fopen(fulltxt, "w");
    if (auth_fd == NULL) {
      writelog(printf("chk_auth: cannot open %s\n", fulltxt);)
      Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
      return ("failed");
    } else {
      if ( fwrite(data, 1, data_len, auth_fd) < data_len ) {
        writelog(printf("chk_auth: error writing SDP data to file\n");)
        fclose(auth_fd);
        Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
        return ("failed");
      } else {
        fclose(auth_fd);
      }
    }
    free(fulltxt);
 
/* Call PGP to check signature info */

    Tcl_VarEval(interp, "pgp_check_authentication ", irandstr, NULL);
 
/* The script returns the (PGP)Key ID used and the authentication status  */
/* (either FAILED, INTEGRITY (only), or TRUSTWORTHY)                      */

    key_id = Tcl_GetVar(interp, "recv_asym_keyid", TCL_GLOBAL_ONLY);
    if (key_id != NULL) {
      memcpy(asym_keyid, key_id, 8);
    }

    tmpauth_status  = Tcl_GetVar(interp, "recv_authstatus",  TCL_GLOBAL_ONLY);
    auth_message = Tcl_GetVar(interp, "recv_authmessage", TCL_GLOBAL_ONLY);

    if(auth_message != NULL) {
      messagelen = strlen(auth_message);
      if (messagelen >= AUTHMESSAGELEN) {
        messagelen = AUTHMESSAGELEN - 1;
      }
      strncpy(authmessage,auth_message,messagelen);
      strcpy(authmessage+messagelen+1,(char *)"\0");
      writelog(printf("chk_auth: messagelen   = %d\n",messagelen);)
      writelog(printf("chk_auth: authmessage = %s\n",authmessage);)

      auth_status = (char *)malloc(AUTHSTATUSLEN);
      messagelen = strlen(tmpauth_status);
      if (messagelen >= AUTHSTATUSLEN) {
        messagelen = AUTHSTATUSLEN - 1;
      }
      strncpy(auth_status,tmpauth_status,messagelen);
      strcpy(auth_status+messagelen+1,(char *)"\0");
      writelog(printf("chk_auth: auth_status  = %s\n",auth_status);)
    } else {
      writelog(printf("chk_auth: auth_message is NULL (error was %s)\n",interp->result);)
      strncpy(authmessage,"No message was produced", authmessagelen);
      return ("failed");
   }

  } else {
   strcpy(asym_keyid,"nokey");
   auth_status = (char *)malloc(10);
   strcpy(auth_status,"unchecked");
   strcpy(authmessage,"This announcement contained a PGP digital signature which has not been checked");
   Tcl_SetVar(interp, "sess_auth_message",authmessage,TCL_GLOBAL_ONLY);
   free(fullsig);
   free(fulltxt);
  }

/* the rest of this routine was store_authentication_in_memory() */
/* want to store signature and certificate in main addata        */

   authinfo = addata->authinfo;

   authinfo->auth_type = auth_p->auth_type;
   authinfo->version   = 1;
   authinfo->siglen    = 0;
   authinfo->sig_len   = sig_len;

/* signature */

   authinfo->signature = (char *)malloc(authinfo->sig_len);
   memcpy(authinfo->signature,(char *)auth_p+AUTH_HEADER_LEN,authinfo->sig_len);

/* authentication type */
   
   authinfo->auth_type = auth_p->auth_type;

/* padding - must be aligned to 32-bit boundary and                      */
/* there is a 2 byte auth_header - 2nd byte is signature length. This is */
/* not in agreement with the spec as the sig length shouldn't be there   */

   authinfo->pad_len = 4-((authinfo->sig_len+AUTH_HEADER_LEN) % 4);
   authinfo->autlen  = (authinfo->sig_len+AUTH_HEADER_LEN+authinfo->pad_len) / 4 ;

/* padding bit */

   if (authinfo->pad_len != 0) {
     authinfo->padding = 1;
   }

/* clean up the PGP files */

    Tcl_VarEval(interp, "pgp_cleanup ", irandstr, NULL);
    free(irandstr);

/* sort out the problem with Tcl strings not being well-terminated */

  if ( (strncmp(auth_status,"trustworthy",11) == 0) ) {
    strcpy(auth_status,"trustworthy");
  } else if ( (strncmp(auth_status,"failed",6) == 0) ) {
    strcpy(auth_status,"failed");
  } else if ( (strncmp(auth_status,"integrity",9) == 0) ) {
    strcpy(auth_status,"integrity");
  }

   return (auth_status);
}
 
/* ---------------------------------------------------------------------- */
/* generate_encryption_info                                               */
/*                                                                        */
/* 1) write data to file - irand.txt                                      */
/* 2) call pgp_encrypt - output written to irand.pgp                      */
/* 3) read in irand.pgp and store this in addata->priv_header             */
/* 4) fill in the rest of the addata->priv_header structure               */
/*                                                                        */
/* ---------------------------------------------------------------------- */
int generate_encryption_info(char *data, 
                             char *encstatus, 
			     char *encmessage, 
                             int  encmessagelen,
                   struct advert_data *addata,
                                 char *enc_type)
{
    FILE *enc_fd=NULL, *txt_fd=NULL;
    struct priv_header *sapenc_p=NULL;
    struct stat sbuf;
    char *homedir=NULL, *encfulltxt=NULL, *encfullenc=NULL;
    char *code;
    char *irandstr=NULL;
    char *enc_message=NULL;
    char *encbuf=NULL, *ac=NULL;
    int  irand, i;
 
    writelog(printf("entered gen_enc_info\n");)
 
/* generate a random number to use for the unique filenames */

    irand = (lbl_random()&0xffff);

/* malloc the filename space */

    encfulltxt  = (char *)malloc(MAXFILENAMELEN);
    encfullenc  = (char *)malloc(MAXFILENAMELEN);

#ifdef WIN32
    homedir = (char *)getenv("HOMEDIR");
    sprintf(encfulltxt, "%s\\sdr\\%d.%s", homedir, irand, enctxt_fname);
    sprintf(encfullenc, "%s\\sdr\\%d.%s", homedir, irand, sapenc_fname);
#else
    homedir = (char *)getenv("HOME");
    sprintf(encfulltxt, "%s/.sdr/%d.%s", homedir, irand, enctxt_fname);
    sprintf(encfullenc, "%s/.sdr/%d.%s", homedir, irand, sapenc_fname);
#endif

    writelog(printf("gen_enc_info: encfulltxt = %s\n",encfulltxt);)
    writelog(printf("gen_enc_info: encfullenc = %s\n",encfullenc);)

/* need the random number as a string to pass to the tcl PGP code */

    irandstr = (char *)malloc(10);
    sprintf(irandstr, "%d", irand);
 
/* open a file and write data to it (irand.txt) */

    txt_fd=fopen(encfulltxt, "w");
    if (txt_fd == NULL) {
     writelog(printf(" gen_enc_info: Cannot open %s\n", encfulltxt);)
     strcpy(encstatus,"failed");
     Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
     return 1;
    } else {
      fwrite(data, 1, strlen(data), txt_fd);
      fclose(txt_fd);
    }
    free(encfulltxt);
 
/* Call PGP to encrypt the file (output to irand.pgp) */

    Tcl_VarEval(interp, "pgp_encrypt ", irandstr, NULL);
    code = Tcl_GetVar(interp, "recv_result", TCL_GLOBAL_ONLY);
    writelog(printf("rc from pgp_encrypt = %s\n", code);)

/* Check return code - 0 = okay, 1 = problem */

    if (strncmp(code,"0",1) != 0 ) {
      writelog(printf("gen_enc_info: PGP encrypted file not created\n"); )
      Tcl_VarEval(interp, "enc_pgp_cleanup  ", irandstr, NULL);
      return 1;
    } else {
      enc_message = Tcl_GetVar(interp, "recv_encmessage", TCL_GLOBAL_ONLY);
      if(enc_message != NULL) {
        strncpy(encmessage,enc_message,encmessagelen);
        strcpy(encstatus, "Encrypted");
      } else {
        writelog(printf("gen_enc_info: enc_message is empty: %s \n" ,
             interp->result);)
        strcpy(encmessage,"No message was produced");
      }
    }

/* now read in the encrypted file and fill in the advert_data->priv_header */
/* set sapenc_p to point to the priv_header in the main advert_data */

    sapenc_p = addata->sapenc_p;

/* version is always 1 at the moment */

    sapenc_p->version  = 1;
    sapenc_p->enc_type = PGP;

/* open the encrypted file which should have been written by PGP */

    enc_fd= fopen(encfullenc,"r");

    if (enc_fd == NULL) {
      writelog(printf("gen_enc_info: cannot open %s\n", encfullenc);)
      Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
      return 1;
    } else {

/* read encrypted data into buffer */

      stat(encfullenc, &sbuf);
      encbuf =(char *)malloc(sbuf.st_size);

      if (( fread(encbuf,1,  sbuf.st_size ,enc_fd))!= sbuf.st_size) {
        writelog(printf("gen_enc_info: problem reading encrypted file\n");)
        fclose(enc_fd);
        free(encbuf);
        Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
        return 1;
      }
    }

    fclose(enc_fd);

/* set priv_header->encd_len */

    sapenc_p->encd_len = sbuf.st_size;

/* don't need to read the plain text file in as we already have "data" */
/* set priv_header->txt_len and priv_header->txt_data                  */

    sapenc_p->txt_len  = strlen(data);
    sapenc_p->txt_data = (char *)malloc(sapenc_p->txt_len);
    memcpy(sapenc_p->txt_data, data, sapenc_p->txt_len);

/* set the padding length - need 2 bytes for the generic header */

    sapenc_p->pad_len = 4-(((sapenc_p->encd_len)+ENC_HEADER_LEN) % 4);
    if (sapenc_p->pad_len == 4) {
      sapenc_p->pad_len = 0;
    }
    if (sapenc_p->pad_len != 0) {
      sapenc_p->padding = 1;
    }

/* set the header length */

    sapenc_p->hdr_len = (sapenc_p->pad_len +  sapenc_p->encd_len +2) / 4;
    writelog(printf("gen_enc_info: sapenc_p->hdr_len=%d\n",sapenc_p->hdr_len);)

/* copy the encrypted data into the priv_header */

    sapenc_p->enc_data =(char *)malloc(sapenc_p->pad_len +  sapenc_p->encd_len);
    memcpy(sapenc_p->enc_data,encbuf, sapenc_p->encd_len);
    free(encbuf);

/* now sort out the extra padding bytes */

    ac = (char *)(sapenc_p->enc_data)+sapenc_p->encd_len;

    if (sapenc_p->pad_len != 0) {
      for (i=0; i<(sapenc_p->pad_len-1); ++i) {
        ac[i] = 0;
      }
      ac[i] = sapenc_p->pad_len;
    }

    Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
    free(irandstr);

    return 0;
}
/*-------------------------------------------------------------------*/
/* check the encryption: enc_p pts to the start of the priv header   */
/* - this is v. similar to generate_encryption_info except that this */
/*   starts with encrypted and ends with plain. They should really be*/
/*   one routine                                                     */
/*-------------------------------------------------------------------*/
int check_encryption(	struct priv_header *enc_p, 
	        	char *data, 
			int   data_len, 
	       		char *enc_asym_keyid,
	       		char *encmessage, 
			int   encmessagelen,
			struct advert_data *addata,
			char *enc_type)
{
  FILE *enc_fd=NULL, *txt_fd=NULL;
  struct priv_header *sapenc_p;
  struct stat sbuf;
  char *homedir=NULL, *encfulltxt=NULL, *encfullenc=NULL;
  char *code=NULL;
  char *irandstr=NULL;
  char *enc_message=NULL;
  char *decrypt=NULL, *ac;
  int   i, irand;
  int padlen;

  char *enc_status=NULL, *key_id=NULL;
  int   hdr_len;
 
  writelog(printf(" -- entered check_encryption --\n");)

/* set up shorthand */

  hdr_len = enc_p->hdr_len * 4;

/* generate a random number to use for the unique filenames */

  irand = (lbl_random()&0xffff);

/* malloc the filename space */

  encfullenc  = (char *)malloc(MAXFILENAMELEN);
  encfulltxt  = (char *)malloc(MAXFILENAMELEN);

#ifdef WIN32
  homedir = (char *)getenv("HOMEDIR");
  sprintf(encfulltxt, "%s\\sdr\\%d.%s", homedir, irand, enctxt_fname);
  sprintf(encfullenc, "%s\\sdr\\%d.%s", homedir, irand, sapenc_fname);
#else
  homedir = (char *)getenv("HOME");
  sprintf(encfulltxt, "%s/.sdr/%d.%s", homedir, irand, enctxt_fname);
  sprintf(encfullenc, "%s/.sdr/%d.%s", homedir, irand, sapenc_fname);
#endif

  writelog(printf("chk_enc: encfullenc is %s\n",encfullenc);)
  writelog(printf("chk_enc: encfulltxt is %s\n",encfulltxt);)

/* need the random number as a string for use in tcl code (pgp) */

    irandstr = (char *)malloc(10);
    sprintf(irandstr, "%d", irand);

/* look to see how much padding and figure out non-generic hdr length */
/* need to know this so we know how much data to write out            */

  if ( enc_p->padding != 0 ) {
    padlen = *((char *)enc_p+hdr_len-1);
    hdr_len = hdr_len - ENC_HEADER_LEN - padlen; 
  } else {
    hdr_len -= ENC_HEADER_LEN;
  }
 
/* open a file and write encrypted data to it (irand.pgp) */

  enc_fd=fopen(encfullenc, "w");
  if (enc_fd == NULL) {
    writelog(printf("chk_enc: cannot open %s\n", encfullenc);)
    Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
    return 1;
  } else {
    if ( fwrite((char *)data+ENC_HEADER_LEN, 1, hdr_len, enc_fd) < hdr_len ) {
      writelog(printf("chk_enc: Error writing SDP data to file\n\r");)
      fclose(enc_fd);
      Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
      return 1;
    }
  }
  free(encfullenc);
  fclose(enc_fd);
 
/* call PGP to decrypt the data */

  Tcl_VarEval(interp, "pgp_check_encryption ", irandstr, NULL);
  code = Tcl_GetVar(interp, "recv_encstatus", TCL_GLOBAL_ONLY);

/* Check return code - "success" or "failed" */

  enc_status = (char *)malloc(10);

  if (code !=NULL) {
    if (strncmp(code,"success",7) != 0 ) {
      strcpy(enc_status,"failed");
      Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
      return 1;
	} else {
      strcpy(enc_status, "success");
	}
  } else {
    strcpy(enc_status,"failed");
    Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
    return 1;
  }
/* retrieve the key_id */

  key_id = Tcl_GetVar(interp, "recv_enc_asym_keyid", TCL_GLOBAL_ONLY);

  if (key_id == NULL) {
    return 1;
  } else {
    memcpy(enc_asym_keyid, key_id, 8);
  }

/* retrieve the message */

  enc_message = Tcl_GetVar(interp, "recv_encmessage", TCL_GLOBAL_ONLY);

  if (enc_message == NULL) {
    writelog(printf("chk_enc: no message %s\n",interp->result);)
    strncpy(encmessage,"No Encryption Message", encmessagelen);
    return 1;
  } else {
    strncpy(encmessage,enc_message,encmessagelen);
    writelog(printf("chk_enc: encmessage = %s\n",encmessage);)
  }

/* enc_status is not a well terminated string - should be sorted out earlier */
/* but as a quick fix just look at the first 7 characters :)                 */

  if ( strncmp(enc_status, "success",7) != 0 ) {
    free(enc_status);
    return 1;
  }
  free(enc_status);

/* now read in the plain text file and fill in the advert_data->priv_header */

  sapenc_p = addata->sapenc_p;

/* version is always 1 at the moment */

  sapenc_p->version  = 1;
  sapenc_p->enc_type = PGP;

/* open plain text file which should have been written by PGP */

  txt_fd = fopen(encfulltxt,"r");

  if (txt_fd == NULL) {
    writelog(printf("chk_enc: cannot open %s\n", encfulltxt);)
    Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
    return 1;
  } else {

/* read plain text into buffer */

    stat(encfulltxt, &sbuf);
    decrypt = (char *)malloc(sbuf.st_size);

    if ( (fread(decrypt,1,sbuf.st_size,txt_fd)) != sbuf.st_size) {
      writelog(printf("chk_enc: problem reading %s\n",encfulltxt);)
      fclose(txt_fd);
      free(decrypt);
      Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
      return 1;
    }
  }

  free(encfulltxt);
  fclose(txt_fd);

/* set priv_header->txt_len and priv_header->txt_data */

    sapenc_p->txt_len  = sbuf.st_size;
    sapenc_p->txt_data = (char *)malloc(sbuf.st_size);
    memcpy(sapenc_p->txt_data, decrypt, sapenc_p->txt_len);

/* set up encrypted data length                                  */
/* this is the length of the data which was passed in originally */

    sapenc_p->encd_len = hdr_len;

/* set the padding length - need 2 bytes for generic header */

    sapenc_p->pad_len = 4-((sapenc_p->encd_len+ENC_HEADER_LEN) % 4);
    if (sapenc_p->pad_len == 4) {
      sapenc_p->pad_len = 0;
    }
    if (sapenc_p->pad_len != 0) {
      sapenc_p->padding = 1;
    }

/* set the header length */

    sapenc_p->hdr_len = (sapenc_p->pad_len +  sapenc_p->encd_len +2) / 4;

/* set the encrypted data up */

    sapenc_p->enc_data = (char *)malloc(sapenc_p->pad_len+sapenc_p->encd_len);
    memcpy(sapenc_p->enc_data, data+ENC_HEADER_LEN, data_len-ENC_HEADER_LEN);

/* fill in the padding */

    ac=(char *)(sapenc_p->enc_data)+sapenc_p->encd_len;

    if (sapenc_p->pad_len != 0) {
      for (i=0; i<(sapenc_p->pad_len-1); ++i) {
        ac[i] = 0;
      }
      ac[i] = sapenc_p->pad_len;
    }

/* free some space */
 
    free(decrypt);

    Tcl_VarEval(interp, "enc_pgp_cleanup ", irandstr, NULL);
    free(irandstr);

    return 0;

}
