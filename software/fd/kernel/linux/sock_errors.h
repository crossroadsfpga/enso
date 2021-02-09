#ifndef __sock_errors_h_
#define __sock_errors_h_

#define FOREACH_SOCK_ERR(SOCK_ERR) \
        SOCK_ERR(too_many_socks_err) \
        SOCK_ERR(too_many_descs_err) \
        SOCK_ERR(no_queue_avail) \
        SOCK_ERR(other_err) \

#define GENERATE_ENUM(ENUM) ENUM,
#define GENERATE_STRING(STRING) #STRING,

enum SOCK_ERR_ENUM {
    FOREACH_SOCK_ERR(GENERATE_ENUM)
};

static const char *SOCK_ERR_STRING[] = {
    FOREACH_SOCK_ERR(GENERATE_STRING)
};

#define err_str(x) #x
#define sock_err_str(x) err_str(x)

#endif
