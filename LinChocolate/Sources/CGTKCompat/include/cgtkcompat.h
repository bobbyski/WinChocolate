/* Wrappers for GTK APIs that are deprecated but deliberately used.
 *
 * LinChocolate targets AppKit's surface, and for these four controls the
 * deprecated GTK API is the only one that fits:
 *
 *   - GtkComboBoxText is the direct editable-combo analog of NSComboBox;
 *     GtkDropDown (its replacement) has no entry and cannot be typed into.
 *   - GtkColorButton is the direct NSColorWell analog; GtkColorDialogButton
 *     (its replacement) is async-only, and NSColorWell's API is synchronous.
 *
 * Calling them from Swift raises a deprecation warning at every call site, and
 * Swift has no per-call suppression. Routing them through C does: the pragma in
 * cgtkcompat.c silences them at the one place that actually makes the call, so
 * the Swift build stays warning-clean without hiding warnings globally.
 */
#ifndef CGTKCOMPAT_H
#define CGTKCOMPAT_H

#include <gtk/gtk.h>

/**
 * Creates a new editable GtkComboBoxText (combo box with a text entry child).
 * Wraps gtk_combo_box_text_new_with_entry(); the NSComboBox analog.
 * @return A newly-created GtkWidget owned by GTK's floating-reference rules.
 */
GtkWidget *lc_combo_box_text_new_with_entry(void);

/**
 * Appends a text item to the end of a GtkComboBoxText's list.
 * Wraps gtk_combo_box_text_append_text().
 * @param combo The GtkComboBoxText widget (as a generic GtkWidget*).
 * @param text  The UTF-8 string to append as a new row.
 */
void       lc_combo_box_text_append_text(GtkWidget *combo, const char *text);

/**
 * Returns the child widget of a GtkComboBox (the editable entry, for text combos).
 * Wraps gtk_combo_box_get_child().
 * @param combo The GtkComboBox widget (as a generic GtkWidget*).
 * @return The child widget, or NULL if none.
 */
GtkWidget *lc_combo_box_get_child(GtkWidget *combo);

/**
 * Creates a new GtkColorButton showing the current color and opening a chooser.
 * Wraps gtk_color_button_new(); the NSColorWell analog.
 * @return A newly-created GtkWidget owned by GTK's floating-reference rules.
 */
GtkWidget *lc_color_button_new(void);

/**
 * Sets whether the color chooser dialog opened by the button is modal.
 * Wraps gtk_color_button_set_modal().
 * @param button The GtkColorButton widget (as a generic GtkWidget*).
 * @param modal  TRUE to make the color chooser dialog modal.
 */
void       lc_color_button_set_modal(GtkWidget *button, gboolean modal);

/**
 * Sets the currently-selected color on a GtkColorChooser.
 * Wraps gtk_color_chooser_set_rgba().
 * @param chooser The GtkColorChooser widget (as a generic GtkWidget*).
 * @param rgba    The color to select.
 */
void       lc_color_chooser_set_rgba(GtkWidget *chooser, const GdkRGBA *rgba);

/**
 * Reads the currently-selected color from a GtkColorChooser.
 * Wraps gtk_color_chooser_get_rgba().
 * @param chooser The GtkColorChooser widget (as a generic GtkWidget*).
 * @param rgba    Out-parameter filled with the currently-selected color.
 */
void       lc_color_chooser_get_rgba(GtkWidget *chooser, GdkRGBA *rgba);

#endif /* CGTKCOMPAT_H */
