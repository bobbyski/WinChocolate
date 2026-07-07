#ifndef LINCHOCOLATE_CGTK_SHIM_H
#define LINCHOCOLATE_CGTK_SHIM_H

/* Umbrella for the GTK4 C API. Include paths come from pkg-config `gtk4`
 * (see Package.swift). Pulling in the top gtk header transitively exposes
 * GLib/GObject/GDK/GSK, which is all the harness spike needs. */
#include <gtk/gtk.h>

#endif /* LINCHOCOLATE_CGTK_SHIM_H */
