#include "include/cgtkcompat.h"

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

#pragma GCC diagnostic pop
