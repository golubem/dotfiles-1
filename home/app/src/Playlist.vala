public class Playlist : Gtk.Grid {
	public static Gtk.Image artPlay ;
	public static Gtk.ScrolledWindow scrollList;
	public static Gtk.TreeStore tree_store;
	public static Gtk.TreeView tree;
	public static Gtk.TreeIter itera;
	public static Gtk.TreeIter itert;
	public static uint currp;
	public static uint currc;

	public static void cmd_art () {
		if (current_status () != Mpd.State.STOP) {
			var conn = get_conn ();
			Mpd.Song song = conn.run_current_song ();
			string folder = GLib.Environment.get_user_special_dir(GLib.UserDirectory.MUSIC) + "/" + Path.get_dirname (song.get_uri ());
			string file = null;
			try {
				Dir dir = Dir.open (folder, 0);
				string? name = null;
				while ((name = dir.read_name ()) != null) {
					string path = Path.build_filename (folder, name);
					var files = File.new_for_path (path);
					try {
						var file_info = files.query_info ("*", FileQueryInfoFlags.NONE);
						if (file_info.get_content_type ().substring (0, file_info.get_content_type().index_of("/", 0)) == "image" && FileUtils.test (path, FileTest.IS_REGULAR)) {
							file = path;
							stdout.printf ("File size: %lld bytes\n", file_info.get_size ());
						}
					} catch (GLib.Error e) {
						stderr.printf ("Could not query album art info: %s\n", e.message);
					}
				}
			} catch (FileError err) {
				stderr.printf (err.message);
			}
			try {
				var albumArt = new Gdk.Pixbuf.from_file_at_size (file, 500, 500);
				artPlay.set_from_pixbuf (albumArt);
			} catch (GLib.Error e) {
				stderr.printf ("Could not load album art: %s\n", e.message);
			}
			//albumArt.scale_simple(150, 150, Gdk.InterpType.BILINEAR);
			//artPlay.set_from_file("cover.jpg");
			//artPlay.set_from_icon_name("media-optical", Gtk.IconSize.DND);
		}
	}

	public static void cmd_playls () {
		var conn = get_conn ();
		Mpd.Song song;
		conn.send_list_queue_meta ();
		tree_store.clear ();
		string album = null;
		while ((song = conn.recv_song ()) != null) {
			uint pos = song.get_pos ();
			string track = song.get_tag (Mpd.TagType.TRACK);
			if (track == null || track.char_count () == 1) {
				track = "0" + track;
			} else {
				track = track.substring (0, 2);
			}
			//track = int.parse(trackn);
			string title = song.get_tag (Mpd.TagType.TITLE);
			string lenght = to_minutes (song.get_duration ());
			if (album == null || song.get_tag (Mpd.TagType.ALBUM) != album) {
				album = song.get_tag (Mpd.TagType.ALBUM);
				string year = song.get_tag (Mpd.TagType.DATE);
				year = ((year == null ) ? "0000" : year.substring (0, 4));
				tree_store.append (out itera, null);
				tree_store.set (itera, 0, pos, 1, year, 2, album);
			}
			tree_store.append (out itert, itera);
			tree_store.set (itert, 0, pos, 1, track, 2, title, 3, lenght);
			//free(song);
		}
		cmd_psel();
		tree.row_activated.connect (on_row_activated);
		//selection.changed.connect (on_changed);
	}

	public static void cmd_psel () {
		var conn = get_conn ();
		Mpd.Song song;
		Mpd.Status status = conn.run_status ();
		conn.send_list_queue_meta ();
		string album = null;
		int parent = -1;
		int child = -1;
		currp = 0;
		currc = 0;
		while ((song = conn.recv_song ()) != null) {
			uint pos = song.get_pos ();
			if (album == null || song.get_tag (Mpd.TagType.ALBUM) != album) {
				album = song.get_tag (Mpd.TagType.ALBUM);
				parent++;
				child = -1;
			}
			child++;
			if (status.get_song_pos () == pos) {
				currp = parent;
				currc = child;
			}
		}
		var path = new Gtk.TreePath.from_indices (currp, currc);
		if (!tree.is_row_expanded (path)) {
			tree.expand_to_path (path);
		}
		tree.set_cursor (path, null, false);
		tree.scroll_to_cell (path, null, true, 0.5f, 0);
	}

	public static void on_row_activated (Gtk.TreeView treeview , Gtk.TreePath path, Gtk.TreeViewColumn column) {
		Gtk.TreeIter iter;
		uint pos;
		string track;
		string title;
		var conn = get_conn ();
		if (tree.model.get_iter (out iter, path)) {
			tree.model.get (iter,
							0, out pos,
							1, out track,
							2, out title);
			conn.send_play_pos (pos);
			Gtk.Image image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.MENU);
			Application.buttonToggle.set_image (image);
			cmd_art ();
		}
	}

	public static void cmd_delete (Gtk.TreeSelection selection) {
		Gtk.TreeModel model;
		Gtk.TreeIter iter;
		uint pos;
		string track;
		string title;
		var conn = get_conn ();
		if (selection.get_selected (out model, out iter)) {
			model.get (iter,
						0, out pos,
						1, out track,
						2, out title);
			stdout.printf ("%s\n", track);
			if (track != null && track.char_count () > 2) {
				Mpd.Song song;
				conn.send_list_queue_meta ();
				uint pos0 = -1;
				uint pos1 = -1;
				while ((song = conn.recv_song ()) != null) {
					if (song.get_tag (Mpd.TagType.ALBUM) == title) {
						if (pos0 == -1) {
							pos0 = song.get_pos ();
						}
						pos1 = song.get_pos ();
					}
				}
				pos1++;
				conn.run_delete_range (pos0, pos1);
			} else {
				conn.run_delete (pos);
			}
			cmd_playls ();
		}
	}

	public Playlist() {
		column_spacing = 0;
		row_spacing = 0;

		artPlay = new Gtk.Image ();
		artPlay.set_halign (Gtk.Align.CENTER);
		cmd_art ();
		attach (artPlay, 0, 0, 1, 2);

		attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 1, 0, 1, 1 );

		scrollList = new Gtk.ScrolledWindow (null, null);
		scrollList.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
		scrollList.set_hexpand (true);
		attach (scrollList, 2, 0, 1, 1);

		tree_store = new Gtk.TreeStore (4, typeof (uint), typeof (string), typeof (string), typeof (string));

		//for (int i = 0; i < playlist.length; i++) {
		//	list_store.append (out iter);
		//	list_store.set (iter, 0, playlist[i].number, 1, playlist[i].title);
		//}

		tree = new Gtk.TreeView.with_model (tree_store);
		tree.set_vexpand (true);
		tree.set_hexpand (true);
		tree.set_grid_lines (Gtk.TreeViewGridLines.VERTICAL);
		scrollList.add (tree);

		Gtk.CellRendererText celln = new Gtk.CellRendererText ();
		Gtk.CellRendererText cellt = new Gtk.CellRendererText ();
		celln.xalign = 1;
		celln.xpad = 10;
		celln.ypad = 5;
		//cellt.ellipsize = Pango.EllipsizeMode.END;
		tree.insert_column_with_attributes (-1, "#", celln, "text", 1);
		tree.insert_column_with_attributes (-1, "Title", cellt, "text", 2);
		tree.insert_column_with_attributes (-1, "Lenght", celln, "text", 3);

		cmd_playls ();

		var actionbar = new Gtk.ActionBar();
		//actionbar.set_hexpand (false);
		//actionbar.set_margin_top(0);
		//grid.attach(actionbar, 0, 1, 1, 1);
		attach (actionbar, 2, 1, 1, 1);

		var plbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		plbox.get_style_context ().add_class("linked");
		actionbar.pack_start(plbox);
		var up = new Gtk.Button.from_icon_name ("go-up-symbolic", Gtk.IconSize.MENU);
		plbox.pack_start(up);
		var remove = new Gtk.Button.from_icon_name ("list-remove-symbolic", Gtk.IconSize.MENU);
		remove.clicked.connect (() => {
			var selection = tree.get_selection ();
			cmd_delete (selection);
		});
		plbox.pack_start(remove);
		var down = new Gtk.Button.from_icon_name ("go-down-symbolic", Gtk.IconSize.MENU);
		plbox.pack_start(down);
		var clear = new Gtk.Button.from_icon_name ("list-remove-all-symbolic", Gtk.IconSize.MENU);
		clear.clicked.connect (() => {
			var conn = get_conn ();
			conn.run_clear ();
		});
		actionbar.pack_end (clear);
	}
}