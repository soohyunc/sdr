/*sap_crypt.c*/
int encrypt_announcement(char *srcbuf, char **dstbuf, int *length, char *key);
int decrypt_announcement(char *buf, int *len, char *recvkey);
int load_crypted_file(char *filename, char *buf, char *key);
int write_crypted_file(char *filename, char *data, int len, char *key);
char *get_pass_phrase();
int load_keys();
int save_keys();
int get_sdr_home(char *str);
int find_key_by_name(char *keyname, u_int *keyid, char *key);
int set_pass_phrase(char *newphrase);
int register_key(char *key, char *keyname, u_int keyid);
int delete_key(char *keyname);

/* ui_fns_crypt.c */
int ui_set_passphrase(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_get_passphrase(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_add_key(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_delete_key(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_find_key_by_name(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_write_crypted_file(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_load_keys(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_save_keys();
 
int init_security();

