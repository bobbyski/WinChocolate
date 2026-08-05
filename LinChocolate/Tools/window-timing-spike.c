/* window-timing-spike — a CONTROL EXPERIMENT for the "window flashes / takes
 * seconds to paint" report. Pure GTK4 C: no LinChocolate, no Swift, no
 * framework code of ours anywhere. It opens a main window, then a small second
 * window (the shape of the demo's inspector panel), and times each one from
 * `present` to its first rendered frame.
 *
 * If this shows the same multi-second gap on a display where the demo does,
 * the latency belongs to GTK/the X server/the window manager, and no amount of
 * framework work will remove it. If this is fast and the demo is slow, the
 * fault is ours and this narrows it to a handful of calls.
 *
 * Build & run inside the dev container:
 *   clang Tools/window-timing-spike.c $(pkg-config --cflags --libs gtk4) -o /tmp/spike && /tmp/spike
 */
#include <gtk/gtk.h>
#include <gdk/x11/gdkx.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>

/* SPIKE_NO_SYNC=1 strips _NET_WM_SYNC_REQUEST from the window's WM_PROTOCOLS
 * just after realize, before it is mapped.
 *
 * The hypothesis under test: GTK's X11 backend asks the window manager to
 * acknowledge a newly mapped surface through the frame-sync counter, and holds
 * the first frame until that acknowledgement arrives. quartz-wm advertises the
 * protocol but does not complete the handshake, so GDK waits out its timeout —
 * which is why a SECOND window takes ~1-2 s to paint while the first is fast.
 * If removing the protocol removes the stall, that is the mechanism, and the
 * same trick can be applied in the framework. */
static void maybe_strip_sync_request(GtkWidget *win) {
    const char *flag = g_getenv("SPIKE_NO_SYNC");
    if (!flag || !*flag) return;
    GtkNative *native = gtk_widget_get_native(win);
    if (!native) return;
    GdkSurface *surface = gtk_native_get_surface(native);
    if (!surface || !GDK_IS_X11_SURFACE(surface)) return;
    Display *dpy = GDK_SURFACE_XDISPLAY(surface);
    Window xid = GDK_SURFACE_XID(surface);
    Atom sync = XInternAtom(dpy, "_NET_WM_SYNC_REQUEST", False);
    Atom *protocols = NULL; int count = 0;
    if (!XGetWMProtocols(dpy, xid, &protocols, &count)) return;
    Atom kept[16]; int n = 0;
    for (int i = 0; i < count && n < 16; i++)
        if (protocols[i] != sync) kept[n++] = protocols[i];
    XFree(protocols);
    XSetWMProtocols(dpy, xid, kept, n);
    XFlush(dpy);
    fprintf(stderr, "SPIKE           [%s] stripped _NET_WM_SYNC_REQUEST (%d -> %d protocols)\n",
            (const char *)g_object_get_data(G_OBJECT(win), "spike-name"), count, n);
    fflush(stderr);
}

static gint64 t0;
static gint64 main_mapped, panel_mapped;

static double ms_now(void) { return (g_get_monotonic_time() - t0) / 1000.0; }

static void note(const char *win, const char *event, GtkWidget *w) {
    int ww = gtk_widget_get_width(w), wh = gtk_widget_get_height(w);
    int sw = 0, sh = 0;
    GtkNative *native = gtk_widget_get_native(w);
    if (native) {
        GdkSurface *s = gtk_native_get_surface(native);
        if (s) { sw = gdk_surface_get_width(s); sh = gdk_surface_get_height(s); }
    }
    fprintf(stderr, "SPIKE %8.1fms [%s] %-14s alloc=%dx%d surface=%dx%d\n",
            ms_now(), win, event, ww, wh, sw, sh);
    fflush(stderr);
}

static void on_map(GtkWidget *w, gpointer name) {
    note((const char *)name, "map", w);
    if (g_str_equal(name, "main"))  main_mapped  = g_get_monotonic_time();
    else                            panel_mapped = g_get_monotonic_time();
}

static void on_after_paint(GdkFrameClock *clock, gpointer data) {
    GtkWidget *w = GTK_WIDGET(data);
    const char *name = g_object_get_data(G_OBJECT(w), "spike-name");
    gint64 mapped = g_str_equal(name, "main") ? main_mapped : panel_mapped;
    static gboolean first_main = TRUE, first_panel = TRUE;
    gboolean *first = g_str_equal(name, "main") ? &first_main : &first_panel;
    if (*first) {
        *first = FALSE;
        fprintf(stderr, "SPIKE %8.1fms [%s] FIRST FRAME   %.1f ms after map\n",
                ms_now(), name, (g_get_monotonic_time() - mapped) / 1000.0);
        fflush(stderr);
    }
    note(name, "after-paint", w);
}

static GtkWidget *make_window(const char *name, const char *title, int w, int h) {
    GtkWidget *win = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(win), title);
    GtkWidget *label = gtk_label_new(title);
    gtk_widget_set_size_request(label, w, h);   /* content carries the size, as LinChocolate does */
    gtk_window_set_child(GTK_WINDOW(win), label);
    g_object_set_data(G_OBJECT(win), "spike-name", (gpointer)name);
    g_signal_connect(win, "map", G_CALLBACK(on_map), (gpointer)name);
    note(name, "pre-realize", win);
    gtk_widget_realize(win);
    maybe_strip_sync_request(win);
    GdkFrameClock *clock = gtk_widget_get_frame_clock(win);
    if (clock) g_signal_connect(clock, "after-paint", G_CALLBACK(on_after_paint), win);
    note(name, "pre-present", win);
    gtk_window_present(GTK_WINDOW(win));
    note(name, "post-present", win);
    return win;
}

static gboolean open_panel(gpointer data) {
    make_window("panel", "Spike Panel", 280, 140);
    return G_SOURCE_REMOVE;
}

static gboolean finish(gpointer data) { gtk_window_destroy(GTK_WINDOW(data)); return G_SOURCE_REMOVE; }

int main(void) {
    t0 = g_get_monotonic_time();
    gtk_init();
    GtkWidget *main_win = make_window("main", "Spike Main", 1120, 760);
    g_timeout_add_seconds(4, open_panel, NULL);      /* second window, like pressing Panel */
    g_timeout_add_seconds(12, finish, main_win);
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_timeout_add_seconds(13, (GSourceFunc)g_main_loop_quit, loop);
    g_main_loop_run(loop);
    return 0;
}
