char *get_session_name(hash_t aid);
int compare_session_names(hash_t *aid1, hash_t *aid2);
int compare_start_times(hash_t *aid1, hash_t *aid2);
unsigned int get_session_starttime(hash_t aid);

/*origins of session data*/
#define UNKNOWN 0
#define LOCAL_WWW 1
#define LOCAL_CLIENT 2
#define REMOTE 3

struct stored_entry {
  hash_t hash;
  struct session *sess;
  int length;
  u_char origin;
  struct scope *scope;
  char buf[MAXADSIZE];
  struct stored_entry *next;
};

struct  entry_list {
  struct stored_entry *first_entry;
  int no_of_entries;
  unsigned int first_timeout;
};
