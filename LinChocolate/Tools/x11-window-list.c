/* x11-window-list.c — minimal proof that windows actually mapped on the X
 * display, for environments with no xwininfo/xdotool and no sudo to install
 * them (the WSL1 loop; see Tools/wsl-native-build-test.sh).
 *
 * Walks the root window's tree and prints every viewable window's id,
 * geometry, and name. Exit 0 if at least one *named, viewable* top-level was
 * found, 1 otherwise — so a script can assert "the demo put a window up"
 * rather than merely "the process didn't die".
 *
 * Build:  clang x11-window-list.c -lX11 -o /tmp/xlist
 * Run:    DISPLAY=127.0.0.1:0 /tmp/xlist
 */
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h>
#include <string.h>

static int namedViewable = 0;

static void walk(Display *d, Window w, int depth) {
    Window root, parent, *children = NULL;
    unsigned int n = 0;
    XWindowAttributes a;

    if (XGetWindowAttributes(d, w, &a) && a.map_state == IsViewable && depth > 0) {
        char *name = NULL;
        XFetchName(d, w, &name);
        /* Only report windows big enough to be real surfaces — the tree is
         * full of 1x1 helper windows (input methods, trays). */
        if (a.width >= 40 && a.height >= 20) {
            printf("%*s0x%lx  %dx%d+%d+%d  \"%s\"\n", depth * 2, "",
                   (unsigned long)w, a.width, a.height, a.x, a.y,
                   name ? name : "");
            if (name && name[0] != '\0') {
                namedViewable = 1;
            }
        }
        if (name) {
            XFree(name);
        }
    }

    if (XQueryTree(d, w, &root, &parent, &children, &n)) {
        for (unsigned int i = 0; i < n; i++) {
            walk(d, children[i], depth + 1);
        }
        if (children) {
            XFree(children);
        }
    }
}

int main(void) {
    Display *d = XOpenDisplay(NULL);
    if (!d) {
        fprintf(stderr, "cannot open display %s\n", XDisplayName(NULL));
        return 2;
    }
    printf("display %s: %dx%d\n", XDisplayName(NULL),
           DisplayWidth(d, DefaultScreen(d)), DisplayHeight(d, DefaultScreen(d)));
    walk(d, DefaultRootWindow(d), 0);
    XCloseDisplay(d);
    return namedViewable ? 0 : 1;
}
