#!/usr/bin/env python3
"""GTK4 test gallery for Schiefer (header bar like GNOME applications)."""
import sys
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib, Gio  # noqa: E402

app = Gtk.Application(application_id="org.example.RetroGallery4")


def build(app):
    win = Gtk.ApplicationWindow(application=app, title="GTK4 Gallery")
    win.set_default_size(900, 560)
    hb = Gtk.HeaderBar()
    menu = Gio.Menu()
    menu.append("Open…", "win.x")
    menu.append("Save", "win.x")
    act = Gio.SimpleAction.new("x", None)
    win.add_action(act)
    mbtn = Gtk.MenuButton(icon_name="open-menu-symbolic", menu_model=menu)
    hb.pack_end(mbtn)
    hb.pack_start(Gtk.Button(icon_name="go-previous-symbolic"))
    win.set_titlebar(hb)

    nb = Gtk.Notebook()
    win.set_child(nb)
    box = Gtk.Box(spacing=12, margin_start=10, margin_end=10, margin_top=10, margin_bottom=10)
    nb.append_page(box, Gtk.Label(label="Controls"))
    nb.append_page(Gtk.Label(label="empty"), Gtk.Label(label="Second"))

    c1 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    box.append(c1)
    c1.append(Gtk.Button(label="Default"))
    s = Gtk.Button(label="Suggested")
    s.add_css_class("suggested-action")
    c1.append(s)
    t = Gtk.ToggleButton(label="Toggled", active=True)
    c1.append(t)
    d = Gtk.Button(label="Disabled", sensitive=False)
    c1.append(d)
    f = Gtk.Button(label="Flat")
    f.add_css_class("flat")
    c1.append(f)
    c1.append(Gtk.CheckButton(label="Check box on", active=True))
    c1.append(Gtk.CheckButton(label="Check box off"))
    r1 = Gtk.CheckButton(label="Option A", active=True)
    r2 = Gtk.CheckButton(label="Option B")
    r2.set_group(r1)
    c1.append(r1)
    c1.append(r2)
    sw = Gtk.Box(spacing=8)
    sw.append(Gtk.Switch(active=True))
    sw.append(Gtk.Switch())
    c1.append(sw)

    c2 = Gtk.Grid(row_spacing=6, column_spacing=8)
    box.append(c2)
    rows = [("Text:", Gtk.Entry(text="abc")),
            ("Choice:", Gtk.DropDown.new_from_strings(["itemA", "itemB"])),
            ("SpinButton:", Gtk.SpinButton.new_with_range(0, 100, 1)),
            ("Search:", Gtk.SearchEntry(placeholder_text="Search…"))]
    sc = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
    sc.set_value(40)
    sc.set_hexpand(True)
    rows.append(("Slider:", sc))
    rows.append(("Progress:", Gtk.ProgressBar(fraction=0.6)))
    rows.append(("Level:", Gtk.LevelBar(value=0.4)))
    for i, (lab, w) in enumerate(rows):
        c2.attach(Gtk.Label(label=lab, xalign=1), 0, i, 1, 1)
        c2.attach(w, 1, i, 1, 1)

    c3 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, hexpand=True)
    box.append(c3)
    tv = Gtk.TextView()
    tv.get_buffer().set_text("\n".join(["Multi-line text"] * 30))
    sw2 = Gtk.ScrolledWindow(min_content_height=200, has_frame=True)
    sw2.set_child(tv)
    c3.append(sw2)
    lb = Gtk.ListBox()
    lb.add_css_class("boxed-list")
    for x in ("Entry A", "Entry B", "Entry C"):
        lb.append(Gtk.Label(label=x, xalign=0, margin_start=6, margin_top=4, margin_bottom=4))
    lb.select_row(lb.get_row_at_index(1))
    c3.append(lb)
    win.present()
    if "--popover" in sys.argv:
        GLib.timeout_add(1500, lambda: mbtn.popup() and False)


app.connect("activate", build)
app.run([])
