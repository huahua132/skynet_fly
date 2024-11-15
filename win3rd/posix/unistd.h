#pragma once

#include <assert.h>
#include <stdio.h>
#include <time.h>
#include <process.h>
#include <io.h>
#include <assert.h>
#include <stdlib.h>

#ifdef POSIX_LIBRARY
    #define POSIX_API __declspec(dllexport)
#else
    #define POSIX_API __declspec(dllimport)
#endif

#define ssize_t size_t

#define random rand
#define srandom srand
#define snprintf _snprintf
#define localtime_r _localtime64_s

#define pid_t int

POSIX_API int kill(pid_t pid, int exit_code);

POSIX_API void usleep(size_t us);
POSIX_API void sleep(size_t ms);

enum { CLOCK_THREAD_CPUTIME_ID, CLOCK_REALTIME, CLOCK_MONOTONIC };
POSIX_API int clock_gettime(int what, struct timespec *ti);

enum { LOCK_EX, LOCK_NB };
POSIX_API int flock(int fd, int flag);

struct sigaction {
  void (*sa_handler)(int);
  int sa_flags;
  int sa_mask;
};
enum { SIGPIPE, SIGHUP, SA_RESTART };
POSIX_API void sigfillset(int *flag);
POSIX_API int sigemptyset(int* set);
POSIX_API void sigaction(int flag, struct sigaction *action, void* param);

POSIX_API int pipe(int fd[2]);
POSIX_API int daemon(int a, int b);

#define O_NONBLOCK 1
#define F_SETFL 0
#define F_GETFL 1

POSIX_API int fcntl(int fd, int cmd, long arg);

POSIX_API char *strsep(char **stringp, const char *delim);

POSIX_API int write(int fd, const void* ptr, unsigned int sz);
POSIX_API int read(int fd, void* buffer, unsigned int sz);
POSIX_API int close(int fd);

#define getpid _getpid
#define open _open
#define dup2 _dup2
