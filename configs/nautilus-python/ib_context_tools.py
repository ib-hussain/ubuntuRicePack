from gi.repository import Nautilus, GObject
import os
import subprocess
import urllib.parse


class IBToolsExtension(GObject.GObject, Nautilus.MenuProvider):
    def _uri_to_path(self, uri):
        """Convert file URI to local path"""
        if not uri:
            return None
        if uri.startswith("file://"):
            return urllib.parse.unquote(uri[7:])
        return None

    def _path_from_file(self, file_obj):
        """Extract path from Nautilus file object"""
        try:
            uri = file_obj.get_uri()
            path = self._uri_to_path(uri)
            if path and os.path.exists(path):
                return path
        except Exception:
            pass
        return os.path.expanduser("~")

    def _directory_for_selection(self, files):
        """Get directory path from selection"""
        if not files:
            return os.path.expanduser("~")

        path = self._path_from_file(files[0])
        return path if os.path.isdir(path) else os.path.dirname(path)

    def _open_code(self, menu, path):
        """Open file/folder in VS Code with Wayland support"""
        code_bin = "/usr/bin/code"  # visual-studio-code-bin installs here
        
        if not os.path.exists(code_bin):
            subprocess.Popen([
                "notify-send",
                "VS Code Not Found",
                "Visual Studio Code is not installed",
                "--icon=dialog-error"
            ])
            return

        try:
            env = os.environ.copy()
            # Ensure Wayland native support
            env["ELECTRON_OZONE_PLATFORM_HINT"] = "wayland"
            env["GDK_BACKEND"] = "wayland"
            
            subprocess.Popen(
                [code_bin, "--reuse-window", path],
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
        except Exception as e:
            subprocess.Popen([
                "notify-send",
                "Open with Code",
                f"Failed to open: {str(e)}",
                "--icon=dialog-error"
            ])

    def _new_text_file(self, menu, path):
        """Create new empty text file with auto-numbering"""
        base = "New Text File"
        candidate = os.path.join(path, f"{base}.txt")
        i = 1

        while os.path.exists(candidate):
            candidate = os.path.join(path, f"{base} {i}.txt")
            i += 1

        try:
            open(candidate, "w").close()
        except Exception as e:
            subprocess.Popen([
                "notify-send",
                "New File Error",
                f"Failed to create file: {str(e)}",
                "--icon=dialog-error"
            ])

    def _create_menu_items(self, path):
        """Create all menu items for a given path"""
        # New File menu item
        new_file_item = Nautilus.MenuItem(
            name="IBTools::NewTextFile",
            label="New File",
            tip="Create a new empty text file",
            icon="text-x-generic"
        )
        new_file_item.connect("activate", self._new_text_file, path)

        # Open with Code menu item
        code_item = Nautilus.MenuItem(
            name="IBTools::OpenWithCode",
            label="Open with Code",
            tip="Open in Visual Studio Code",
            icon="code"
        )
        code_item.connect("activate", self._open_code, path)

        return [new_file_item, code_item]

    def get_background_items(self, current_folder):
        """Right-click on empty space in folder"""
        path = self._path_from_file(current_folder)
        return self._create_menu_items(path)

    def get_file_items(self, files):
        """Right-click on selected files/folders"""
        path = self._directory_for_selection(files)
        return self._create_menu_items(path)

'''
To install it:

```bash
# Copy to Nautilus extensions directory
mkdir -p ~/.local/share/nautilus-python/extensions/
cp ib_tools.py ~/.local/share/nautilus-python/extensions/

# Remove old extensions if they exist
rm -f ~/.local/share/nautilus-python/extensions/ib_context_tools.py
rm -f ~/.local/share/nautilus-python/extensions/open-with-code.py

# Restart Nautilus
nautilus -q
```

Key features of this combined version:
- **Only 2 menu items**: "New File" and "Open with Code"
- **Wayland optimized**: Sets proper environment variables for native Wayland support
- **Uses `--reuse-window`**: Opens files in existing VS Code window
- **Better error handling**: Desktop notifications if something fails
- **Clean URI parsing**: Takes the better approach from `open-with-code.py`
- **Correct binary path**: Points directly to where `visual-studio-code-bin` installs

The script will appear when you right-click in any folder or on any file selection in Nautilus.

'''

