/* x11-c-window.c — stage 2a of the WSL1 loop bring-up: open ONE named X11
 * window from C, no Swift, no GTK. If this maps, raw X11 to the Windows-side
 * server works; anything failing above it is Swift's or GTK's problem.
 *
 * Build:  clang x11-c-window.c -lX11 -o /tmp/xcwin
 * Run:    DISPLAY=127.0.0.1:0 /tmp/xcwin   (stays up ~30 s, then exits 0)
 * Check:  Tools/x11-window-list.c sees "wsl1-x11-c-test" while it runs.
 */
#include <X11/Xlib.h>
#include <stdio.h>
#include <unistd.h>

int main(void) {
    Display *d = XOpenDisplay(NULL);
    if (!d) {
        fprintf(stderr, "cannot open display %s\n", XDisplayName(NULL));
        return 2;
    }
    int s = DefaultScreen(d);
    Window w = XCreateSimpleWindow(d, RootWindow(d, s), 100, 100, 400, 240, 1,
                                   BlackPixel(d, s), WhitePixel(d, s));
    XStoreName(d, w, "wsl1-x11-c-test");
    XSelectInput(d, w, ExposureMask);
    XMapWindow(d, w);
    XFlush(d);
    printf("mapped 0x%lx\n", (unsigned long)w);
    fflush(stdout);

    for (int i = 0; i < 30; i++) {
        while (XPending(d)) {
            XEvent e;
            XNextEvent(d, &e);
        }
        sleep(1);
    }
    XCloseDisplay(d);
    return 0;
}
