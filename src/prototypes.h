#include "generic_prototypes.h"
#include "www_prototypes.h"

/*load_file.c*/
int aux_load_file(char *buf, char *name, char *flag);
int parse_announcement(int enc, char *data, int length,
                   u_long src, u_long hfrom, char *rx_sock_addr,
                   int rx_sock_port, int sec);
int build_packet(char *buf, char *adstr, int len, u_int keyid);
int store_data_to_announce(struct advert_data *addata, char *adstr,
			   char *keyname);

/*bus.c*/
int bus_recv();
int bus_send(char *msg, int len);
int bus_listen();
int is_a_bus_message(char *buf);
void parse_bus_message(char *buf, int len);
int bus_send_new_app();

/*random*/
#ifndef NORANDPROTO
void srandom(int seed);
int random();
#endif

/*sip_register.c*/
int sip_register();

/*sip_common.c*/
int sip_send_udp(char *dst, int ttl, char *msg);
int sip_send_tcp(char *dst, char *msg);
struct in_addr look_up_address(char *hostname);
int sip_listen(char *address, int port);
int is_a_sip_request(char *msg);
int is_a_sip_reply(char *msg);
int parse_sip_reply(char *msg, char *addr);
char *sip_get_dstname(char *msg);

/*sip.c*/
int sip_recv();
int sip_tx_init(char *address, int port, char ttl);
int parse_sip_success(char *msg, char *addr);
int parse_sip_progress(char *msg, char *addr);
int parse_sip_fail(char *msg, char *addr);
int parse_sip_fa(char *msg, char *addr);
int parse_sip_ringing(char *msg, char *addr);
int parse_sip_trying(char *msg, char *addr);
int sip_send(char *msg, int len, struct sockaddr_in *dst, int ttl);

/*ui_fns.c*/
int ui_quit();
int ui_sip_send_msg(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_set_sipalias(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_lookup_host(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_sd_listen(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_generate_port();
int ui_generate_address();
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
int ui_gethostname(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_getpid(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
int ui_stop_session_ad(ClientData dummy, Tcl_Interp *interp, int argc, char **argv);
void initnames();


/*generate_ids*/
int generate_port(char *s);
int store_address(struct in_addr *addr, unsigned long endtime);
struct in_addr generate_address();
int check_address(struct in_addr *addr);


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
int sd_listen(char *address, int port, int *rxsock, int *no_of_socks, int fatal);
void recv_packets();
int timed_send_advert(ClientData cd);
int send_advert(char *adstr, int sock, unsigned char ttl, u_int keyid, 
		u_int len);
int queue_ad_for_sending(char *aid, char *adstr, int interval, long end_time, char * address, int port, unsigned char ttl, char * keyname);
int stop_session_ad(char *aid);
void clean_up_and_die();
void force_numeric(char *str);
void splat_tcl_special_chars(char *str);
void warn_tcl_special_chars(char *str);
unsigned long parse_entry(char *advertid, char *data, int length,
            unsigned long src, unsigned long hfrom,
            char *sd_addr, int port, time_t t, char *trust, char *recvkey);
void read_old_style_cache();
#ifdef LISTEN_FOR_SD
void read_sd_cache();
#endif
int extract_ttl(char *addrstr);
int check_net_type(char *in, char *ip);

/* iohandler.c */
void linksocket(int fd, int mask, Tcl_FileProc* callback);
void unlinksocket(int fd);
