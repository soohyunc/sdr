/* sap_crypt.c */
int encrypt_announcement(char *srcbuf, char **dstbuf, int *length, char *key);
int add_privacy_header(char *buf, int auth, struct priv_header *sapenc_p);
int decrypt_announcement(char *buf, int *len, char *recvkey);
int load_crypted_file(char *filename, char *buf, char *key);

int write_crypted_file(char *filename, char *data, int len, char *key, char *auth_type, char *advertid);
struct advert_data *get_encryption_info(char *advertid);
struct advert_data *recv_cache_data(char *data, int len,char *authstatus,char *encstatus , char *authtype,char *authmessage,char *encmessage);

char *get_pass_phrase();
int load_keys();
int save_keys();
int get_sdr_home(char *str);
int find_key_by_name(char *keyname, char *key);
int find_keyname_by_key(char *key, char *keyname);
int set_pass_phrase(char *newphrase);
int register_key(char *key, char *keyname);
int delete_key(char *keyname);
int make_random_key();

/* pgp_crypt.c */

int generate_authentication_info(char *data, int len, char *authstatus, char *authmessage, int authmessagelen, struct advert_data *addata, char *auth_type);

int generate_encryption_info(char *data, char *encstatus, char *encmessage, int encmessagelen, struct advert_data *addata, char *enc_type);

char *check_authentication(struct auth_header *auth_p,
                         char *data, int data_len, int auth_len,
                         char *asym_keyid, char *authmessage,
			 int authmessagelen, struct advert_data *addata,
			 char *auth_type);
int generate_x509_authentication_info(char *data,int len, char *authstatus, int irand,char  *authmessage, int authmessagelen);
char *check_x509_authentication(struct auth_header *auth_p, char *authinfo,
                         char *data, int data_len, int auth_len,
                         char *asym_keyid, int irand,char *authmessage,
			 int authmessagelen);
int store_x509_authentication_in_memory(struct advert_data *addata,
                         char *auth_type, int irand);


int check_encryption(struct priv_header *enc_p, char *data, int enc_data_len,
                         char *enc_asym_keyid, char *encmessage, 
                         int encmessagelen, struct advert_data *addata,
                         char *enctype);

int generate_x509_encryption_info(char *data, char *encstatus, int irand,char *encmessage, int encmessagelen);
char *check_x509_encryption(struct priv_header *enc_p, char *encinfo,
                         char *data, int enc_data_len, int hdr_len,
                         char *enc_asym_keyid, int irand,char *encmessage,
			 int encmessagelen);
int store_x509_encryption_in_memory(struct advert_data *addata, char *enc_type,
                          int irand);

/* polluted.c */

int gen_new_data(char *adstr,char *new_data, char *keyname,struct advert_data *addata );
int gen_new_auth_data(char *buf,char *newbuf,struct sapv4_header *bp,int auth_len,int len);
int write_authentication(char *filename, char *data, int len, char *advertid);
int write_encryption(char *filename,  char *data, int len, char *auth_type, char *enc_type, char *advertid);


/* ui_fns_crypt.c */
int ui_set_passphrase(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_get_passphrase(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_add_key(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_delete_key(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_find_key_by_name(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_find_keyname_by_key(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_write_crypted_file(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_load_keys(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_save_keys();
int ui_make_random_key();

int ui_write_authentication(ClientData dummy, Tcl_Interp *interp, int argc,
 char **argv);
int ui_make_random_key();
 
int ui_write_encryption(ClientData dummy, Tcl_Interp *interp, int argc, 
char **argv);
 
int init_security();

