#include "prototypes_crypt.h"

extern const char tcl_libs[];
extern const char tcl_generic[];
extern const char tcl_www[];
extern const char tcl_new[];
extern const char tcl_start_tools[];
extern const char tcl_parsed_plugins[];
extern const char tcl_plugins[];
extern const char tcl_sip[];
extern const char tcl_sdp[];
extern const char tcl_sdr[];
extern const char tcl_cache[];
extern const char tcl_sap_crypt[];
extern const char tcl_pgp_crypt[];
extern const char tcl_pkcs7_crypt[];
extern const char tcl_cli[];

#define MAX_TCL_MODULE 15

const char *modname[MAX_TCL_MODULE]=
{"tcl_generic", "tcl_www", "tcl_new", "tcl_start_tools",
 "tcl_parsed_plugins", "tcl_plugins", "tcl_sip", "tcl_sdp", "tcl_cache",
 "tcl_sdr", "tcl_sap_crypt", "tcl_pgp_crypt", "tcl_pkcs7_crypt", "tcl_cli"};

const char *modvar[MAX_TCL_MODULE]=
{tcl_generic, tcl_www, tcl_new, tcl_start_tools,
 tcl_parsed_plugins, tcl_plugins, tcl_sip, tcl_sdp, tcl_cache,
 tcl_sdr, tcl_sap_crypt, tcl_pgp_crypt, tcl_pkcs7_crypt, tcl_cli};
#ifdef AUTH
#define MAX_UI_FN 40
#else
#define MAX_UI_FN 38
#endif

const char *ui_fn_name[MAX_UI_FN]=
{
  "ui_generate_port",
  "generate_id",
  "ui_generate_address",
  "getemailaddress",
  "createsession",
  "checkaddress",
  "gethostaddr",
  "gethostname",
  "getusername",
  "ui_stop_session_ad",
  "getdayname",
  "getmonname",
  "webto",
  "save_www_data_to_file",
  "stop_www_loading",
  "sd_listen",
  "lookup_host",
  "sip_send_udp",
  "sip_send_tcp_request",
  "sip_send_tcp_reply",
  "sip_close_tcp_connection",
  "sip_parse_url",
  "sip_parse_path",
  "ui_quit",
  "set_sipalias",
  "getpid",
  "set_passphrase",
  "get_passphrase",
  "add_key",
  "delete_key",
  "find_key_by_name",
  "find_keyname_by_key",
  "load_keys",
  "save_keys",
  "write_crypted_file",
  "make_random_key",
  "run_program",
#ifdef AUTH
  "write_authentication",
  "write_encryption",
#endif
  "verify_ipv6_stack"
};

void *ui_fn[MAX_UI_FN]=
{
  ui_generate_port,
  ui_generate_id,
  ui_generate_address,
  ui_getemailaddress,
  ui_createsession,
  ui_check_address,
  ui_gethostaddr,
  ui_gethostname,
  ui_getusername,
  ui_stop_session_ad,
  ui_getdayname,
  ui_getmonname,
  ui_webto,
  ui_save_www_data_to_file,
  ui_stop_www_loading,
  ui_sd_listen,
  ui_lookup_host,
  ui_sip_send_udp,
  ui_sip_send_tcp_request,
  ui_sip_send_tcp_reply,
  ui_sip_close_tcp_connection,
  ui_sip_parse_url,
  ui_sip_parse_path,
  ui_quit,
  ui_set_sipalias,
  ui_getpid,
  ui_set_passphrase,
  ui_get_passphrase,
  ui_add_key,
  ui_delete_key,
  ui_find_key_by_name,
  ui_find_keyname_by_key,
  ui_load_keys,
  ui_save_keys,
  ui_write_crypted_file,
  ui_make_random_key,
  ui_run_program,
#ifdef AUTH
  ui_write_authentication,
  ui_write_encryption,
#endif
  ui_verify_ipv6_stack
};
