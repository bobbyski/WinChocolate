#include "include/cgtkcompat.h"
#include <gdk/x11/gdkx.h>
#include <X11/Xlib.h>

/* These calls are deprecated on purpose — see cgtkcompat.h for why each one is
 * still the right control. Scoped to this file so nothing else loses warnings. */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

GtkWidget *lc_combo_box_text_new_with_entry(void) {
    return gtk_combo_box_text_new_with_entry();
}

void lc_combo_box_text_append_text(GtkWidget *combo, const char *text) {
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(combo), text);
}

GtkWidget *lc_combo_box_get_child(GtkWidget *combo) {
    return gtk_combo_box_get_child(GTK_COMBO_BOX(combo));
}

GtkWidget *lc_color_button_new(void) {
    return gtk_color_button_new();
}

void lc_color_button_set_modal(GtkWidget *button, gboolean modal) {
    gtk_color_button_set_modal(GTK_COLOR_BUTTON(button), modal);
}

void lc_color_chooser_set_rgba(GtkWidget *chooser, const GdkRGBA *rgba) {
    gtk_color_chooser_set_rgba(GTK_COLOR_CHOOSER(chooser), rgba);
}

void lc_color_chooser_get_rgba(GtkWidget *chooser, GdkRGBA *rgba) {
    gtk_color_chooser_get_rgba(GTK_COLOR_CHOOSER(chooser), rgba);
}

void lc_css_provider_load(GtkCssProvider *provider, const char *css) {
    gtk_css_provider_load_from_data(provider, css, -1);
}

char *lc_run_file_chooser(GtkWindow *parent, gboolean open, const char *directory, const char *suggested_name) {
    (void)parent;
    (void)open;
    (void)directory;
    (void)suggested_name;
    return NULL;
}

#pragma GCC diagnostic pop

void lc_strip_wm_sync_request(GtkWidget *window) {
    GtkNative *native = gtk_widget_get_native(window);
    if (!native) return;
    GdkSurface *surface = gtk_native_get_surface(native);
    if (!surface || !GDK_IS_X11_SURFACE(surface)) return;
    Display *display = GDK_SURFACE_XDISPLAY(surface);
    Window xid = GDK_SURFACE_XID(surface);
    Atom sync_request = XInternAtom(display, "_NET_WM_SYNC_REQUEST", False);
    Atom *protocols = NULL;
    int count = 0;
    if (!XGetWMProtocols(display, xid, &protocols, &count)) return;
    Atom kept[32];
    int kept_count = 0;
    for (int i = 0; i < count && kept_count < 32; i++) {
        if (protocols[i] != sync_request) kept[kept_count++] = protocols[i];
    }
    XFree(protocols);
    if (kept_count != count) {
        XSetWMProtocols(display, xid, kept, kept_count);
        XFlush(display);
    }
}

void lc_set_window_background_rgb(GtkWidget *window, double red, double green, double blue) {
    GtkNative *native = gtk_widget_get_native(window);
    if (!native) return;
    GdkSurface *surface = gtk_native_get_surface(native);
    if (!surface || !GDK_IS_X11_SURFACE(surface)) return;   /* Wayland: nothing to do */
    Display *display = GDK_SURFACE_XDISPLAY(surface);
    Window xid = GDK_SURFACE_XID(surface);
    unsigned long pixel =
        (((unsigned long)(red   * 255.0) & 0xFF) << 16) |
        (((unsigned long)(green * 255.0) & 0xFF) <<  8) |
        (((unsigned long)(blue  * 255.0) & 0xFF));
    XSetWindowBackground(display, xid, pixel);
    XClearWindow(display, xid);
    XFlush(display);
}
