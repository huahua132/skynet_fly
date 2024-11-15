#pragma once

#define SHUT_RD         0               /* shut down the reading side */
#define SHUT_WR         1               /* shut down the writing side */
#define SHUT_RDWR       2               /* shut down both sides */

#define FD_SETSIZE 1024

#define _WINSOCK_DEPRECATED_NO_WARNINGS
#define WIN32_LEAN_AND_MEAN
#include <WinSock2.h>
#include <Windows.h>
#include <conio.h>

#include <ws2ipdef.h>
#include <WS2tcpip.h>

#include "socket_poll.h"
#include "socket_epoll.h"