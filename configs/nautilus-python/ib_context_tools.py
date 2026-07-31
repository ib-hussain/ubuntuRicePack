"""UbuntuRicePack context-menu actions for Nautilus 4."""

from pathlib import Path
import logging
import os
import shutil
import subprocess
import urllib.parse

import gi

gi.require_version("Nautilus", "4.0")
from gi.repository import GObject, Nautilus  # noqa: E402


LOGGER = logging.getLogger("ubuntuRicePack.nautilus")


class IBToolsExtension(GObject.GObject, Nautilus.MenuProvider):
    """Provide New Text File and Open with Code for local folders."""

    @staticmethod
    def _path_from_file(file_info):
        if file_info is None:
            return None

        try:
            location = file_info.get_location()
            if location is not None:
                path = location.get_path()
                if path:
                    return Path(path)
        except (AttributeError, TypeError):
            pass

        try:
            uri = file_info.get_uri()
        except (AttributeError, TypeError):
            return None

        if not uri or not uri.startswith("file://"):
            return None
        return Path(urllib.parse.unquote(urllib.parse.urlparse(uri).path))

    @classmethod
    def _directory_for_selection(cls, files):
        if not files:
            return None

        path = cls._path_from_file(files[0])
        if path is None:
            return None
        return path if path.is_dir() else path.parent

    @staticmethod
    def _notify(title, message):
        notifier = shutil.which("notify-send")
        if notifier is None:
            LOGGER.warning("%s: %s", title, message)
            return
        subprocess.Popen(
            [notifier, "--icon=dialog-error", title, message],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

    def _open_code(self, _menu_item, path):
        code = shutil.which("code")
        if code is None:
            self._notify(
                "VS Code Not Found",
                "Install Visual Studio Code before using Open with Code.",
            )
            return

        try:
            subprocess.Popen(
                [code, "--reuse-window", os.fspath(path)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except OSError as error:
            LOGGER.exception("Could not start VS Code")
            self._notify("Open with Code", f"Could not start VS Code: {error}")

    def _new_text_file(self, _menu_item, directory):
        for number in range(0, 10_000):
            suffix = "" if number == 0 else f" {number}"
            candidate = directory / f"New Text File{suffix}.txt"
            try:
                candidate.touch(mode=0o644, exist_ok=False)
                return
            except FileExistsError:
                continue
            except OSError as error:
                LOGGER.exception("Could not create %s", candidate)
                self._notify("New File Error", f"Could not create file: {error}")
                return

        self._notify("New File Error", "No unused file name could be found.")

    def _create_menu_items(self, directory):
        if directory is None or not directory.is_dir():
            return []

        new_file_item = Nautilus.MenuItem(
            name="IBTools::NewTextFile",
            label="New Text File",
            tip="Create an empty text file in this folder",
            icon="text-x-generic",
        )
        new_file_item.connect("activate", self._new_text_file, directory)

        code_item = Nautilus.MenuItem(
            name="IBTools::OpenWithCode",
            label="Open with Code",
            tip="Open this location in Visual Studio Code",
            icon="com.visualstudio.code",
        )
        code_item.connect("activate", self._open_code, directory)
        return [new_file_item, code_item]

    def get_background_items(self, current_folder):
        return self._create_menu_items(self._path_from_file(current_folder))

    def get_file_items(self, files):
        return self._create_menu_items(self._directory_for_selection(files))
