#include "config_unix.h"
#include "config_win32.h"
#include "crypt_random.h"
#include "generic_prototypes.h"
#include "www_prototypes.h"
#include "generate_ids.h"

/*cli.c*/
int init_cli();
int do_cli(ClientData clientData, int mask);

/*load_file.c*/
int aux_load_file(char *buf, char *name, char *flag);
int parse_announcement(int enc, char *data, int length,
                   u_long src, u_long hfrom, char *rx_sock_addr,
                   int rx_sock_port, int sec);
int build_packet(char *buf, char *adstr, int addr_fam, int len, int encrypt,
                 u_int auth_len, u_int hdr_len,
                 struct auth_info *authinfo, struct priv_header *sapenc_p);

int store_data_to_announce(struct advert_data *addata, char *adstr,
			   char *keyname);

/*bus.c*/
int bus_recv();
int bus_send(char *msg, int len);
int bus_listen();
int is_a_bus_message(char *buf);
void parse_bus_message(char *buf, int len);
int bus_send_new_app();

#ifdef SIP_MODULE
/*sip_register.c*/
int sip_register();
int sip_send_mcast_register(const char *host, const char *maddr, int port,
                            int ttl, const char *user_data);
int sip_send_udp_register(const char *host, int port, char *user_data);
int sip_send_tcp_register(char *host, int port, char *user_data);

/*sip_common.c*/
int sip_send_udp(char *dst, int ttl, int port, char *msg);
int sip_send_tcp_request(int fd, const char *host, int port, char *msg, int wait);
int sip_send_tcp_reply(int fd, const char *callid, char *host, int port, char *msg);
struct in_addr look_up_address(const char *hostname);
int sip_close_tcp_connnection(const char *callid);
int sip_listen(const char *address, int port);
int is_a_sip_request(const char *msg);
int is_a_sip_reply(const char *msg);
int parse_sip_reply(int fd, char *msg, char *addr);
char *sip_get_dstname(const char *msg);
char *sip_get_callid(const char *msg);
int sip_get_method(const char *msg);
int sip_udp_listen(const char *address, int port);
int sip_tcp_listen(int port);
int sip_tcp_accept(connection conns[]);
void sip_tcp_free(connection *conn);
int sip_request_ready(char *buf, int len);
int extract_field(char *buf, char *field_ret, int retlen, char *field);
int extract_parts(char *buf, char *method, char *url, char *via, char *rest);
int is_a_sip_url(const char *url);
int parse_sip_url(const char *url, char* user, char *passwd, char *host,
                  int *port, int *transport, int *ttl, char *maddr,
                  char *tag, char *others);
int parse_sip_path (char *path, char *version, int *transport,
                    char *host, int *port, int *ttl);
int sip_finished_reading_tcp(char *data, int len);
char *find_end_of_header(char *data, int len);
struct in_addr look_up_address(const char *hostname);

/*sip.c*/
int sip_recv_udp();
int sip_recv_tcp();
int sip_parse_recvd_data(char *buf, int length, int sipfd, char *srcaddr);
int sip_readfrom_tcp();
int sip_tx_init(const char *address, int port, char ttl);
int parse_sip_success(int fd, char *msg, char *addr);
int parse_sip_progress(int fd, char *msg, char *addr);
int parse_sip_fail(int fd, char *msg, char *addr);
int parse_sip_fa(char *msg, char *addr);
int parse_sip_ringing(int fd, char *msg, char *addr);
int parse_sip_trying(int fd, char *msg, char *addr);
int parse_sip_redirect(int fd, char *msg, char *addr);
int sip_send(char *msg, int len, struct sockaddr_in *dst, unsigned char ttl);
void sdr_update_ui();
char *sip_generate_callid();
#endif

/*ui_fns.c*/
int ui_quit();
int ui_sip_send_udp(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_sip_send_tcp_request(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_sip_send_tcp_reply(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_set_sipalias(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_lookup_host(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_sd_listen(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_verify_ipv6_stack(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_generate_port();
int ui_generate_address();
int ui_generate_v6_address(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_generate_id();
int ui_check_address(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_getdayname(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_getmonname(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_gettime(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);

int ui_getemailaddress(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_gettimeofday();
int ui_createsession(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_getusername(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_gethostaddr(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_get_v6_hostaddr(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_gethostname(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_getpid(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_stop_session_ad(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_sip_parse_url(ClientData dummy, Tcl_Interp *interp, 
			   int argc, char **argv);
int ui_sip_parse_path(ClientData dummy, Tcl_Interp *interp, 
			   int argc, char **argv);
int ui_sip_close_tcp_connection(ClientData dummy, Tcl_Interp *interp, 
			   int argc, char **argv);
int ui_run_program(ClientData dummy, Tcl_Interp *interp, 
			   int argc, char **argv);
void initnames();


/*generate_ids*/
int generate_port(const char *s);
int delete_address(struct addr_list *test);
int store_address(struct in_addr *addr, int addr_type, unsigned long endtime);
struct in_addr generate_address();
int check_address(struct in_addr *addr, int addr_type);
#ifdef HAVE_IPv6
struct in6_addr *generate_v6_address(struct in6_addr *baseaddr, int netmask,
                                     struct in6_addr *newaddr);
#endif



/*byte_fns.c*/
#ifdef SYSV
void bcopy(char *s1, char *s2, int len);
void bzero(char *str, int len);
#endif

/*bitmaps.c*/
void init_bitmaps();

/*ui_init.c*/
int ui_create_interface();
int ui_init(int *argc, char **argv);
int announce_error(int code, char *command);

/*sd_listen.c*/
void rebuild_interface();
void remove_interface();
int xremove_interface(Display *d);
int sd_listen(char *address, int port, int addr_fam, int *rxsock, 
              int *no_of_socks, int fatal);
int verify_ipv6_stack();
void recv_packets();
int timed_send_advert(ClientData cd);
#ifdef AUTH

int send_advert(char *adstr, int sock, int addr_fam,
                unsigned char ttl, int encrypt, 
                u_int len, u_int auth_len, struct auth_info *sapauth_h,
                u_int hdr_len, struct priv_header *sapenc_h,
                struct sap_header **sap_hdr);
 
 
int queue_ad_for_sending(char *aid, char *adstr, int interval, long end_time, 
                         char * address, int addr_fam, int port, 
                         unsigned char ttl, 
                         char * keyname, char *auth_type, 
                         char *authstatus, char *enctype, char *encstatus, 
                         struct advert_data *addata);

unsigned long parse_entry(char *advertid, char *data, int length, 
                          /* unsigned long src, unsigned long hfrom, */
                          char *src, char *hfrom,
                          char *sap_addr, int port, time_t t, char *trust, 
                          char * recvkey, char *authtype, char *authstatus, 
                          int *authinfo, char *asym_keyid, char *enctype, 
                          char *encstatus,int *encinfo, char *enc_asym_keyid,
                          char *authmessage,char *encmessage);
#else
int send_advert(char *adstr, int sock, unsigned char ttl, int encrypt, 
		u_int len);
int queue_ad_for_sending(char *aid, char *adstr, int interval, long end_time, char * address, int port, unsigned char ttl, char * keyname);
unsigned long parse_entry(char *advertid, char *data, int length,
            unsigned long src, unsigned long hfrom,
            char *sd_addr, int port, time_t t, char *trust, char *recvkey);
#endif
int stop_session_ad(char *aid);
void clean_up_and_die();
void force_numeric(char *str);
void splat_tcl_special_chars(char *str);
void warn_tcl_special_chars(char *str);
void read_old_style_cache();
int extract_ttl(char *addrstr);
int extract_layers(char *addrstr);
int check_net_type(char *in, char *ip, char *addr);
int run_program(char *args);

/* iohandler.c */
void linksocket(int fd, int mask, Tcl_FileProc* callback);
void unlinksocket(int fd);

// Macro for comparing IPv6 addresses
#define IPV6_ADDR_EQUAL(x, y) \
               ((memcmp((char *)x, (char *)y, 16)) == 0)
