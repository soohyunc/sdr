/*
 * Copyright (c) 1996 The Regents of the University of California.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 * 	This product includes software developed by the Network Research
 * 	Group at Lawrence Berkeley National Laboratory.
 * 4. Neither the name of the University nor of the Laboratory may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * This module contributed by John Brezak <brezak@apollo.hp.com>.
 * January 31, 1996
 */


#ifdef WIN32
#include <io.h>
#include <process.h>
#include <fcntl.h>
#include <windows.h>
#include <time.h>
#include <winsock.h>
#endif
#include <tk.h>
#ifdef WIN32
#define WM_WSOCK_READY 	WM_USER+123

extern HINSTANCE Tk_GetHINSTANCE();

#ifdef WIN32
#define MAX_FD 512
#else
#define MAX_FD 64
#endif
static Tcl_FileProc* sockproc[MAX_FD];
static HWND sockwin;

static LRESULT CALLBACK
WSocketHandler(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	Tcl_FileProc* p;
	int fd;

	switch (message) {
	case WM_CREATE:{
		CREATESTRUCT *info = (CREATESTRUCT *) lParam;
		SetWindowLong(hwnd, GWL_USERDATA, (DWORD)info->lpCreateParams);
		return 0;
	}	

	case WM_DESTROY:
		return 0;
	
	case WM_WSOCK_READY:
		fd = (UINT)wParam;
		if (fd >= 0 && fd < MAX_FD && (p = sockproc[fd]) != 0) {
			(*p)((ClientData)fd, TK_READABLE);
			return 0;
		}
		break;
	}
	return DefWindowProc(hwnd, message, wParam, lParam);
}
#endif

void linksocket(int fd, int mask, Tcl_FileProc* callback)
{
#ifdef WIN32
	int status;
	int flags = 0;


	if (fd < 0 || fd >= MAX_FD || sockproc[fd]) {
		fprintf(stderr, "iohandler error: (%d)\n", fd);
		return;
	}

	if (sockwin == 0) {
		/*
		* Register the Message window class.
		*/
		WNDCLASS cl;

		cl.style = CS_HREDRAW | CS_VREDRAW;
		cl.lpfnWndProc = WSocketHandler;
		cl.cbClsExtra = 0;
		cl.cbWndExtra = 0;
		cl.hInstance = Tk_GetHINSTANCE();
		cl.hIcon = NULL;
		cl.hCursor = NULL;
		cl.hbrBackground = NULL;
		cl.lpszMenuName = NULL;
		cl.lpszClassName = "WSocket";
		RegisterClass(&cl);

		sockwin = CreateWindow("WSocket", "",
					WS_POPUP | WS_CLIPCHILDREN,
					CW_USEDEFAULT, CW_USEDEFAULT, 1, 1,
					NULL,
					NULL, Tk_GetHINSTANCE(), callback);
		ShowWindow(sockwin, SW_HIDE);
	}

	if (TK_READABLE & mask)
		flags |= FD_READ;
	if (TK_WRITABLE & mask)
		flags |= FD_WRITE;

        if ((status = WSAAsyncSelect(fd, sockwin, WM_WSOCK_READY, flags)) > 0) {
		fprintf(stderr, "WSAAsyncSelect: %d error %lu\n",
			status, GetLastError());
		exit(1);
	    
        }
	sockproc[fd] = callback;
#else
	Tcl_CreateFileHandler(Tcl_GetFile((ClientData)fd, TCL_UNIX_FD),
			      mask, callback, (ClientData)fd);
#endif
}

void unlinksocket(fd)
{
#ifdef WIN32
	if (fd >= 0 && fd < MAX_FD && sockproc[fd] != 0) {
		sockproc[fd] = 0;
		(void) WSAAsyncSelect(fd, sockwin, 0, 0);
	}
#else
	Tcl_DeleteFileHandler(Tcl_GetFile((ClientData)fd, TCL_UNIX_FD));
#endif
}
