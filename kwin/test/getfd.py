import gi, sys, subprocess
gi.require_version("Gio","2.0")
from gi.repository import Gio, GLib
c=Gio.bus_get_sync(Gio.BusType.SESSION,None)
r,fl=c.call_with_unix_fd_list_sync("org.kde.KWin","/org/kde/KWin/EIS/RemoteDesktop","org.kde.KWin.EIS.RemoteDesktop","connectToEIS",GLib.Variant("(i)",(3,)),GLib.VariantType("(hi)"),Gio.DBusCallFlags.NONE,-1,None,None)
fd=fl.get(r.unpack()[0])
sys.exit(subprocess.call([sys.argv[1],str(fd)]+sys.argv[2:],pass_fds=[fd]))
