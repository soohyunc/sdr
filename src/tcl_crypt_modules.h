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

#define MAX_TCL_MODULE 11

const char *modname[MAX_TCL_MODULE]=
{"tcl_generic", "tcl_www", "tcl_new", "tcl_start_tools",
 "tcl_parsed_plugins", "tcl_plugins", "tcl_sip", "tcl_sdp", "tcl_cache",
 "tcl_sdr", "tcl_sap_crypt"};

const char *modvar[MAX_TCL_MODULE]=
{tcl_generic, tcl_www, tcl_new, tcl_start_tools,
 tcl_parsed_plugins, tcl_plugins, tcl_sip, tcl_sdp, tcl_cache,
 tcl_sdr, tcl_sap_crypt};

#define MAX_UI_FN 29

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
  "sip_send_msg",
  "ui_quit",
  "set_sipalias",
  "getpid",
  "set_passphrase",
  "get_passphrase",
  "add_key",
  "delete_key",
  "find_key_by_name",
  "load_keys",
  "save_keys",
  "write_crypted_file",
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
  ui_sip_send_msg,
  ui_quit,
  ui_set_sipalias,
  ui_getpid,
  ui_set_passphrase,
  ui_get_passphrase,
  ui_add_key,
  ui_delete_key,
  ui_find_key_by_name,
  ui_load_keys,
  ui_save_keys,
  ui_write_crypted_file,
};
