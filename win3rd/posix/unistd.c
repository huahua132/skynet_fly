#include "unistd.h"

#define _WINSOCK_DEPRECATED_NO_WARNINGS
#define WIN32_LEAN_AND_MEAN
#include <WinSock2.h>
#include <stdio.h>
#include <stdint.h>
#include <windows.h>
#include <conio.h>
#include <errno.h>

static LONGLONG get_cpu_freq() {
    LARGE_INTEGER freq;
    QueryPerformanceFrequency(&freq);
    return freq.QuadPart;
}

int kill(pid_t pid, int exit_code) { return TerminateProcess((void*)pid, exit_code); }

#define NANOSEC 1000000000
#define MICROSEC 1000000

void usleep(size_t us) {
    if (us > 1000) {
        Sleep(us / 1000);
        return;
    }
    LONGLONG delta = get_cpu_freq() / MICROSEC * us;
    LARGE_INTEGER counter;
    QueryPerformanceCounter(&counter);
    LONGLONG start = counter.QuadPart;
    for (;;) {
        QueryPerformanceCounter(&counter);
        if (counter.QuadPart - start >= delta)
            return;
    }
}

void sleep(size_t ms) { Sleep(ms); }

int clock_gettime(int what, struct timespec* ti) {
    switch (what) {
    case CLOCK_MONOTONIC:
        static __int64 Freq = 0;
        static __int64 Start = 0;
        static __int64 StartTime = 0;
        if (Freq == 0) {
            StartTime = time(NULL);
            QueryPerformanceFrequency((LARGE_INTEGER*)&Freq);
            QueryPerformanceCounter((LARGE_INTEGER*)&Start);
        }
        __int64 Count = 0;
        QueryPerformanceCounter((LARGE_INTEGER*)&Count);

        //乘以1000，把秒化为毫秒
        __int64 now = (__int64)((double)(Count - Start) / (double)Freq * 1000.0) + StartTime * 1000;
        ti->tv_sec = now / 1000;
        ti->tv_nsec = (now - now / 1000 * 1000) * 1000 * 1000;
        return 0;
    case CLOCK_REALTIME:
        SYSTEMTIME st;
        GetSystemTime(&st); // 获取 UTC 时间

        // 将 SYSTEMTIME 转换为 UNIX 时间戳
        FILETIME ft;
        SystemTimeToFileTime(&st, &ft);
        ULARGE_INTEGER u64;
        u64.LowPart = ft.dwLowDateTime;
        u64.HighPart = ft.dwHighDateTime;

        ti->tv_sec = (uint32_t)((u64.QuadPart - 116444736000000000ULL) / 10000000); // 转换为秒
        ti->tv_nsec = (uint32_t)((u64.QuadPart % 10000000) * 100); // 获取纳秒部分
        return 0; // 响应成功
    case CLOCK_THREAD_CPUTIME_ID:
        // 获取当前线程的 CPU 时间
        FILETIME creation_time, exit_time, kernel_time, user_time;
        if (GetThreadTimes(GetCurrentThread(), &creation_time, &exit_time, &kernel_time, &user_time)) {
            ULARGE_INTEGER u64;
            u64.LowPart = user_time.dwLowDateTime;
            u64.HighPart = user_time.dwHighDateTime;

            ti->tv_sec = (uint32_t)((u64.QuadPart - 116444736000000000ULL) / 10000000); // 转换为秒
            ti->tv_nsec = (uint32_t)((u64.QuadPart % 10000000) * 100); // 获取纳秒部分
            return 0;
        }
        else {
            return -1; // 获取失败
        }
    }
    return -1;
}

int flock(int fd, int flag) {
    // Not implemented
    return 3;
}

int fcntl(int fd, int cmd, long arg)
{
	if (cmd == F_GETFL)
		return 0;

	if (cmd == F_SETFL && arg == O_NONBLOCK) {
		u_long ulOption = 1;
		ioctlsocket(fd, FIONBIO, &ulOption);
	}

	return 1;
}

void sigfillset(int* flag) {
    // Not implemented
}

int sigemptyset(int* set)
{
    /*Not implemented*/
    return 0;
}

void sigaction(int flag, struct sigaction* action, void* param) {
    // Not implemented
}

static void socket_keepalive(int fd) {
    int keepalive = 1;
    int ret = setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, (void*)&keepalive,
        sizeof(keepalive));

    assert(ret != SOCKET_ERROR);
}

int pipe(int fd[2]) {

    int listen_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    struct sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_addr.S_un.S_addr = inet_addr("127.0.0.1");

    srand(time(NULL));
    // use random port(range from 60000 to 60999) to simulate pipe()
    for (;;) {
        int port = 60000 + rand() % 1000;
        sin.sin_port = htons(port);
        if (!bind(listen_fd, (struct sockaddr*)&sin, sizeof(sin)))
            break;
    }

    listen(listen_fd, 5);
    printf("Windows sim pipe() listen at %s:%d\n", inet_ntoa(sin.sin_addr),
        ntohs(sin.sin_port));

    socket_keepalive(listen_fd);

    int client_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (connect(client_fd, (struct sockaddr*)&sin, sizeof(sin)) ==
        SOCKET_ERROR) {
        closesocket(listen_fd);
        return -1;
    }

    struct sockaddr_in client_addr;
    size_t name_len = sizeof(client_addr);
    int client_sock =
        accept(listen_fd, (struct sockaddr*)&client_addr, &name_len);
    // FD_SET( clientSock, &g_fdClientSock);

    // TODO: close listen_fd

    fd[0] = client_sock;
    fd[1] = client_fd;

    socket_keepalive(client_sock);
    socket_keepalive(client_fd);

    return 0;
}

int write(int fd, const void* ptr, unsigned int sz) {

    WSABUF vecs[1];
    vecs[0].buf = ptr;
    vecs[0].len = sz;

    DWORD bytesSent;
    if (WSASend(fd, vecs, 1, &bytesSent, 0, NULL, NULL)) {
        errno = WSAGetLastError();
        if (errno == WSAEWOULDBLOCK) {
            errno = EAGAIN;
        }
        return -1;
    }
    else
        return bytesSent;
}

int read(int fd, void* buffer, unsigned int sz) {

    WSABUF vecs[1];
    vecs[0].buf = buffer;
    vecs[0].len = sz;

    DWORD bytesRecv = 0;
    DWORD flags = 0;
    if (WSARecv(fd, vecs, 1, &bytesRecv, &flags, NULL, NULL)) {
        errno = WSAGetLastError();
        if (errno == WSAEWOULDBLOCK) {
            errno = EAGAIN;
        }
        if (errno == WSAECONNRESET)
            return 0;
        return -1;
    }
    else{
        return bytesRecv;
    }
}

int close(int fd) {
    shutdown(fd, SD_BOTH);
    return closesocket(fd);
}

int daemon(int a, int b) {
    // Not implemented
    return 0;
}

char* strsep(char** stringp, const char* delim) {
    char* s;
    const char* spanp;
    int c, sc;
    char* tok;
    if ((s = *stringp) == NULL)
        return (NULL);
    for (tok = s;;) {
        c = *s++;
        spanp = delim;
        do {
            if ((sc = *spanp++) == c) {
                if (c == 0)
                    s = NULL;
                else
                    s[-1] = 0;
                *stringp = s;
                return (tok);
            }
        } while (sc != 0);
    }
    /* NOTREACHED */
}