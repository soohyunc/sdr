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

#define MAX_TCL_MODULE 10

const char *modname[MAX_TCL_MODULE]=
{"tcl_generic", "tcl_www", "tcl_new", "tcl_start_tools",
 "tcl_parsed_plugins", "tcl_plugins", "tcl_sip", "tcl_sdp", "tcl_cache",
 "tcl_sdr"};

const char *modvar[MAX_TCL_MODULE]=
{tcl_generic, tcl_www, tcl_new, tcl_start_tools,
 tcl_parsed_plugins, tcl_plugins, tcl_sip, tcl_sdp, tcl_cache,
 tcl_sdr};

#define MAX_UI_FN 20

const char *ui_fn_name[MAX_UI_FN]=
{
  "ui_generate_port",
  "generate_id",
  "ui_generate_address",
  "getemailaddress",
  "createsession",
  "checkaddress",
  "gethostaddr",
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
  "getpid"
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
  ui_getpid
};
