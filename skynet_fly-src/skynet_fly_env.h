#ifndef skynet_fly_env_H
#define skynet_fly_env_H

const char * skynet_fly_getenv(const char *key);
void skynet_fly_setenv(const char *key, const char *value);
void skynet_fly_resetenv(const char *key, const char *value);

void skynet_fly_env_init();

#endif
