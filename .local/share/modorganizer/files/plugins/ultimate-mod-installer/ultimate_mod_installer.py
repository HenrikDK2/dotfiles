import os
import time
import mobase
import webbrowser
import subprocess
import shutil
import hashlib
import re
import queue
import json
import configparser
import urllib.request
from audioplayer import AudioPlayer

from pathlib import Path
import ctypes

_window_instance = None
_music_engine = None

def get_music_player_widget(plugin, music_dir, player_cls):
    global _music_engine
    if _music_engine is None:
        _music_engine = MusicEngine(music_dir, player_cls)
    return MusicPlayerWidget(_music_engine, plugin)

try:
    import PyQt5.QtGui as QtGui
    import PyQt5.QtWidgets as QtWidgets
    from PyQt5.QtCore import (Qt, QTimer, QObject, QThread, pyqtSignal, 
    QEvent, QPropertyAnimation, QSize, QCoreApplication, QPoint)
    EXPANDING = QtWidgets.QSizePolicy.SizePolicy.Expanding
    EXTENDED_SELECTION = QtWidgets.QAbstractItemView.ExtendedSelection
    SELECT_ROWS = QtWidgets.QAbstractItemView.SelectRows
    ALIGN_CENTER = Qt.AlignCenter
    ALIGN_TOP = Qt.AlignTop
    ALIGN_BOTTOM = Qt.AlignBottom
    NO_EDIT_TRIGGERS = QtWidgets.QAbstractItemView.NoEditTriggers
    CHECKED = Qt.Checked
    UNCHECKED = Qt.Unchecked
    ASCENDING_ORDER =  Qt.AscendingOrder
    DESCENDING_ORDER =  Qt.DescendingOrder
    CUSTOM_CONTEXT_MENU = Qt.CustomContextMenu
    POINTING_HAND_CURSOR = Qt.PointingHandCursor
    USER_ROLE = Qt.UserRole
    POPUP = Qt.Popup
    STRONG_FOCUS = Qt.StrongFocus
    QAction = QtWidgets.QAction
    OK = QtWidgets.QDialogButtonBox.Ok
    CANCEL = QtWidgets.QDialogButtonBox.Cancel
    QIcon = QtGui.QIcon
    QMessageBox = QtWidgets.QMessageBox

except:
    import PyQt6.QtGui as QtGui
    import PyQt6.QtWidgets as QtWidgets
    from PyQt6.QtCore import (Qt, QTimer, QObject, QThread, pyqtSignal, 
    QEvent, QPropertyAnimation, QSize, QCoreApplication, QPoint)
    EXPANDING = QtWidgets.QSizePolicy.Policy.Expanding
    EXTENDED_SELECTION = QtWidgets.QAbstractItemView.SelectionMode.ExtendedSelection
    SELECT_ROWS = QtWidgets.QAbstractItemView.SelectionBehavior.SelectRows
    NO_EDIT_TRIGGERS = QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers
    ALIGN_CENTER = Qt.AlignmentFlag.AlignCenter
    ALIGN_TOP = Qt.AlignmentFlag.AlignTop
    ALIGN_BOTTOM = Qt.AlignmentFlag.AlignBottom
    CHECKED = Qt.CheckState.Checked
    UNCHECKED = Qt.CheckState.Unchecked
    ASCENDING_ORDER =  Qt.SortOrder.AscendingOrder
    DESCENDING_ORDER =  Qt.SortOrder.DescendingOrder
    CUSTOM_CONTEXT_MENU = Qt.ContextMenuPolicy.CustomContextMenu
    POINTING_HAND_CURSOR = Qt.CursorShape.PointingHandCursor
    USER_ROLE = Qt.ItemDataRole.UserRole
    POPUP = Qt.WindowType.Popup
    STRONG_FOCUS = Qt.FocusPolicy.StrongFocus
    QAction = QtGui.QAction
    OK = QtWidgets.QDialogButtonBox.StandardButton.Ok
    CANCEL = QtWidgets.QDialogButtonBox.StandardButton.Cancel
    QIcon = QtGui.QIcon
    QMessageBox = QtWidgets.QMessageBox

from mobase import IPluginTool

def get_instance_id(mo2_path):
    raw = mo2_path.lower().strip()
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:12]

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SECURE_BASE_DIR = os.path.join(os.getenv("APPDATA"), "Ultimate Mod Installer","generated")
HASH_ID = get_instance_id(BASE_DIR)
SAVES = os.path.join(SECURE_BASE_DIR,HASH_ID,"saves.json")
ARCHIVES_BACKUP = os.path.join(SECURE_BASE_DIR,HASH_ID,"dont_delete.json")
MUSIC_FOLDER = os.path.join(BASE_DIR, "resources/music")
SEVEN_ZIP = os.path.join(BASE_DIR, "7-zip/7z.exe")
SKYRIM_DATA_FOLDERS = [
    "Meshes",
    "Textures",
    "Materials",
    "Sounds",
    "Sound",
    "MusicData",
    "Scripts",
    "Source",
    "Interface",
    "Menus",
    "Shaders",
    "Strings",
    "SKSE",
    "Video",
    "CalienteTools",
    "Root"
]
SKYRIM_DATA_FILE_TYPES = [
    ".esm",  # master plugins
    ".esp",  # mod plugins
    ".bsa",  # Bethesda archive
    #".pex",  # compiled Papyrus scripts
    ".ini"  # configuration or metadata
    #".txt"   # sometimes used for mod metadata
]

EXIST_ACTION = [
    "merge",
    "replace",
    "ask"
]

# class RowColorDelegate(QtWidgets.QStyledItemDelegate):
#     def paint(self, painter, option, index):
#         if index.row() % 2 == 0:
#             option.backgroundBrush = QtGui.QBrush(QtGui.QColor(0, 0, 0))
#         else:
#             option.backgroundBrush = QtGui.QBrush(QtGui.QColor(40, 40, 40))

#         option.palette.setColor(QtGui.QPalette.Text, QtGui.QColor(255, 255, 255))

#         super().paint(painter, option, index)

class TestWidget(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(QtWidgets.QLabel("It works"))

class TimestampItem(QtWidgets.QTableWidgetItem):
    def __init__(self, display_text, timestamp):
        super().__init__(display_text)
        self.timestamp = timestamp

    def __lt__(self, other):
        if isinstance(other, TimestampItem):
            return self.timestamp < other.timestamp
        return super().__lt__(other)

class DragDropLineEdit(QtWidgets.QLineEdit):
    def __init__(self, parent=None, plugin=None):
        super().__init__(parent)
        self.parent = parent
        self.plugin = plugin
        self.setFocusPolicy(STRONG_FOCUS)
        self.setMouseTracking(True)

    def mousePressEvent(self, event):
        folder = QtWidgets.QFileDialog.getExistingDirectory(
            self, "Select Folder", ""
        )
        if folder:
            self.setText(folder)
            self.plugin.populate_archives_list()
        # Call base class to keep normal behavior (like focus rectangle)
        super().mousePressEvent(event)

    def dragEnterEvent(self, event):
        mime = event.mimeData()
        if mime.hasUrls() or mime.hasText():
            event.acceptProposedAction()
        else:
            event.ignore()

    def dropEvent(self, event):
        mime = event.mimeData()
        path = None

        if mime.hasUrls():
            urls = mime.urls()
            if urls:
                path = urls[0].toLocalFile()

        elif mime.hasText():
            text = mime.text()
            path = text.strip().strip('"')

        if path:
            self.handleDroppedPath(path)
            event.acceptProposedAction()
        else:
            event.ignore()

    def handleDroppedPath(self, path):
        try:
            path = os.path.normpath(path)
            self.setText(path)
            self.plugin.populate_archives_list()
        except Exception as e:
            QMessageBox.information(
                None,
                "Error",
                f"Exception4: {e}",
            )

# More reliable numeric sort item (works cross-version)
class NumericSizeItem(QtWidgets.QTableWidgetItem):
    def __lt__(self, other: "QtWidgets.QTableWidgetItem") -> bool:
        try:
            a = int(self.data(USER_ROLE))  # stored numeric bytes
            b = int(other.data(USER_ROLE))
            return a < b
        except Exception:
            # fallback to default behaviour if something's wrong
            return super().__lt__(other)

class BurningImage(QtWidgets.QWidget):
    def __init__(self, image_path, fire_gif, fire, plugin=None, parent=None):
        super().__init__(parent)
        try:
            self.plugin = plugin
            layout = QtWidgets.QStackedLayout(self)
            layout.setStackingMode(QtWidgets.QStackedLayout.StackingMode.StackAll)
            layout.setContentsMargins(0, 0, 0, 0)  # remove margins
            
            # Fire overlay (smaller)
            self.fire_label = QtWidgets.QLabel()
            self.fire_label.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
            self.fire_label.setAlignment(ALIGN_CENTER)
            self.fire_movie = QtGui.QMovie(fire_gif)
            self.fire_movie.setScaledSize(QSize(150, 150))
            self.fire_label.setMovie(self.fire_movie)
            self.fire_movie.start()
            layout.addWidget(self.fire_label)
            
             # Opacity effect for fade in/out
            self.opacity_effect = QtWidgets.QGraphicsOpacityEffect()
            self.fire_label.setGraphicsEffect(self.opacity_effect)
            self.opacity_effect.setOpacity(0.0)

            # Animation setup
            self.animation = QPropertyAnimation(self.opacity_effect, b"opacity")
            self.animation.setDuration(300)  # 1 second fade

            self.toggle_fire(fire)

            # Base image
            self.image_label = QtWidgets.QLabel()
            self.pixmap = QtGui.QPixmap(image_path)
            self.image_label.setPixmap(self.pixmap)
            self.image_label.setAlignment(ALIGN_CENTER)
            layout.addWidget(self.image_label)
            
            self.setCursor(POINTING_HAND_CURSOR)
            self.setToolTip("Install all from the list below")
        
            # Set the widget’s fixed size to match the largest child (image)
            self.setFixedSize(QSize(80,60)) # self.pixmap.size() = QSize(40,40) width,height
            
            # Enable drag & drop
            self.setAcceptDrops(True)
           
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 0: {e}",
            )
            
    def toggle_fire(self, on: bool):
        self.animation.stop()
        if on:
            self.animation.setStartValue(self.opacity_effect.opacity())
            self.animation.setEndValue(1.0)
            self.animation.start()
            self.fire_label.show()
            self.fire_movie.start()
        else:
            self.animation.setStartValue(self.opacity_effect.opacity())
            self.animation.setEndValue(0.0)
            self.animation.start()
            self.fire_label.show()
            self.fire_movie.start()
            
    # === Drag & Drop handling ===
    def dragEnterEvent(self, event: QtGui.QDragEnterEvent):
        if event.mimeData().hasUrls():
            # Force the action to "Move" instead of default "Copy"
            event.setDropAction(Qt.DropAction.MoveAction)
            event.accept()
        else:
            event.ignore()

    def dragMoveEvent(self, event: QtGui.QDragMoveEvent):
        if event.mimeData().hasUrls():
            event.setDropAction(Qt.DropAction.MoveAction)
            event.accept()
        else:
            event.ignore()

    def dropEvent(self, event: QtGui.QDropEvent):
        urls = event.mimeData().urls()
        archive_paths = []
        for url in urls:
            if url.isLocalFile():
                path = url.toLocalFile()
                if (path.endswith(".rar")
                    or path.endswith(".zip")
                    or path.endswith(".7z")):
                        archive_paths.append(path)
        if archive_paths:
            self.plugin.install_archives(type="given_full",archives=archive_paths)
        event.acceptProposedAction()

class ArchiveTable(QtWidgets.QTableWidget):
    def __init__(self, plugin=None, parent=None):
        super().__init__(0, 3, parent)  # adjust col count as needed
        self.plugin = plugin
        self.setAcceptDrops(True)
        
        self.setRowCount(0)
        self.setColumnCount(4)
        self.setHorizontalHeaderLabels(["", "🡻", "Size", "Time"])
        self.setSortingEnabled(True)
        self.sortItems(3, DESCENDING_ORDER)  # optional default sort
        # Make the table take all available space when the window resizes
        self.setSizePolicy(
            QtWidgets.QSizePolicy.Policy.Expanding,   # horizontal
            QtWidgets.QSizePolicy.Policy.Expanding    # vertical
        )

        # self.horizontalHeader().setStretchLastSection(False)

        header = self.horizontalHeader()
        header.sectionResized.connect(self.on_column_resized)
        # header.setSectionResizeMode(QtWidgets.QHeaderView.ResizeMode.Stretch)   # all columns stretch equally
        header.setSectionResizeMode(QtWidgets.QHeaderView.ResizeMode.Interactive)
        header.setSectionResizeMode(0, QtWidgets.QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(1, QtWidgets.QHeaderView.ResizeMode.Interactive)
        col_1_width = self.plugin.load_settings(f"col_{1}_width")
        self.setColumnWidth(1, col_1_width if col_1_width else 20)
        header.setSectionResizeMode(2, QtWidgets.QHeaderView.ResizeMode.Interactive)
        col_2_width = self.plugin.load_settings(f"col_{2}_width")
        self.setColumnWidth(2, col_2_width if col_2_width else 60)
        header.setSectionResizeMode(3, QtWidgets.QHeaderView.ResizeMode.Interactive)
        col_3_width = self.plugin.load_settings(f"col_{3}_width")
        self.setColumnWidth(3, col_3_width if col_3_width else 70)
        header.setDefaultAlignment(ALIGN_CENTER)
        # self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOn)
        #header.sectionClicked.connect(lambda col: self.sort_table(col))
        #self.archives_list.horizontalHeader().setSortIndicatorShown(False)
        
        self.setSelectionBehavior(SELECT_ROWS)
        self.setEditTriggers(NO_EDIT_TRIGGERS)  # non-editable
        self.itemChanged.connect(self.plugin.on_item_changed)

        row_h = self.plugin.load_settings("row_height")
        self.verticalHeader().setVisible(False) # Remove numbering
        self.verticalHeader().setDefaultSectionSize(int(row_h) if row_h else 27)

        self.itemDoubleClicked.connect(self.plugin.on_item_double_clicked)
        self.cellClicked.connect(self.plugin.on_cell_clicked)
        #self.archives_list.setSelectionBehavior(SELECT_ROWS)
        #self.archives_list.setSelectionMode(EXTENDED_SELECTION)
        self.setContextMenuPolicy(CUSTOM_CONTEXT_MENU)
        self.customContextMenuRequested.connect(self.plugin.on_right_click)

    def on_column_resized(self, logicalIndex, oldSize, newSize):
        self.plugin.save_settings(f"col_{logicalIndex}_width", newSize)

    
    def wheelEvent(self, event):
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            delta = event.angleDelta().y()
            step = 2 if delta > 0 else -2

            header = self.verticalHeader()
            current = header.defaultSectionSize()
            new_h = max(18, min(100, current + step))

            header.setDefaultSectionSize(new_h)
            self.plugin.save_settings("row_height", new_h)

            event.accept()
        else:
            super().wheelEvent(event)

    # === Drag & Drop handling ===
    def dragEnterEvent(self, event: QtGui.QDragEnterEvent):
        if event.mimeData().hasUrls():
            # Force the action to "Move" instead of default "Copy"
            event.setDropAction(Qt.DropAction.MoveAction)
            event.accept()
        else:
            event.ignore()

    def dragMoveEvent(self, event: QtGui.QDragMoveEvent):
        if event.mimeData().hasUrls():
            event.setDropAction(Qt.DropAction.MoveAction)
            event.accept()
        else:
            event.ignore()

    def dropEvent(self, event):
        if event.mimeData().hasUrls():
            self.already_loaded_archives = []
            for url in event.mimeData().urls():
                path = url.toLocalFile()
                if os.path.isfile(path):
                    if path.endswith(".rar") or path.endswith(".zip") or path.endswith(".7z"):
                        self.addArchive(path)
            if len(self.already_loaded_archives)==1:
                QMessageBox.information(
                    None,
                    "Archive exists",
                    f"This archive is already loaded:\n{self.already_loaded_archives}",
                )
            elif len(self.already_loaded_archives)>1:
                QMessageBox.information(
                    None,
                    "Archives exist",
                    f"These archives are already loaded:\n{self.already_loaded_archives}",
                )
            event.acceptProposedAction()

    def addArchive(self, archive_path):
        if (os.path.basename(archive_path) in self.plugin.all_archives_list or
            archive_path in self.plugin.dropped_archives):
            self.already_loaded_archives.append(os.path.basename(archive_path))
            return
            
        self.plugin.dropped_archives.append(archive_path)
        self.plugin.populate_archives_list()

        
class AltWindow(QtWidgets.QWidget):
    def __init__(self, plugin = None):
        super().__init__()
        self.plugin = plugin

    def select_archives(self):
        files, _ = QtWidgets.QFileDialog.getOpenFileNames(
            self,
            "Select Archive Files",
            "",
            "Archives (*.7z *.zip *.rar)"  # filter for only archives
        )

        if files:
            self.plugin.install_archives(type="given_full",archives=files)

        
class EditableField(QtWidgets.QWidget):
    def __init__(self, initial_text="", field_type = "game_name", plugin = None):
        super().__init__()
        self.plugin = plugin
        self.field_type = field_type

        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Text field (initially locked)
        self.line_edit = QtWidgets.QLineEdit(initial_text)
        self.line_edit.setReadOnly(True)
        self.line_edit.setMaxLength(99)
        #self.line_edit.setEnabled(False)
        self.line_edit.returnPressed.connect(self.save_edit)
        layout.addWidget(self.line_edit)

        # Edit button
        edit_icon = os.path.join(os.path.dirname(__file__), "resources/icons/edit-icon.png")
        self.btn_edit = QtWidgets.QPushButton(icon=QtGui.QIcon(edit_icon))
        self.btn_edit.setFixedWidth(40)
        layout.addWidget(self.btn_edit)

        # Save + Cancel buttons (hidden at start)
        save_icon = os.path.join(os.path.dirname(__file__), "resources/icons/save-icon.png")
        cancel_icon = os.path.join(os.path.dirname(__file__), "resources/icons/cancel-icon.png")
        self.btn_save = QtWidgets.QPushButton(icon=QtGui.QIcon(save_icon))
        self.btn_cancel = QtWidgets.QPushButton(icon=QtGui.QIcon(cancel_icon))
        for b in (self.btn_save, self.btn_cancel):
            b.setFixedWidth(40)
            b.hide()
            layout.addWidget(b)

        # connections
        self.btn_edit.clicked.connect(self.start_editing)
        self.btn_save.clicked.connect(self.save_edit)
        self.btn_cancel.clicked.connect(self.cancel_edit)

        self._old_text = initial_text

    def start_editing(self):
        self._old_text = self.line_edit.text()
        self.line_edit.setReadOnly(False)
        self.btn_edit.hide()
        self.btn_save.show()
        self.btn_cancel.show()
        self.line_edit.setFocus()

    def save_edit(self):
        new_text = self.line_edit.text()  # keep exact text, including spaces
        self.line_edit.setReadOnly(True)
        self.btn_edit.show()
        self.btn_save.hide()
        self.btn_cancel.hide()
        if new_text != self._old_text:  # compare exact text
            self.plugin.save_settings(self.field_type,new_text)
        self._old_text = new_text  # update old text
        self.line_edit.setFocus()

    def cancel_edit(self):
        # revert text
        self.line_edit.setText(self._old_text)
        self.line_edit.setReadOnly(True)
        self.btn_edit.show()
        self.btn_save.hide()
        self.btn_cancel.hide()
        self.line_edit.setFocus()
        
    def text(self):
        return self.line_edit.text()

    def set_text(self, new_text: str):
        self.line_edit.setText(new_text)
        self._old_text = new_text
        
        
class CloseWatcher(QObject):
    def __init__(self, callback):
        super().__init__()
        self.callback = callback

    def eventFilter(self, obj, event):
        if event.type() == QEvent.Type.Close:
            self.callback(event)
            # Return False so the event continues to default handling
        return False
        
class UMIPlugin(IPluginTool):
    def __init__(self):
        super().__init__()
        self._organizer = None
        self._manager = None
        self._downloads_tab = None
        self.checked_archives = {}
        self.dropped_archives = []
        self.archives_list = None
        self.installed_archives_list = []
        self.uninstalled_archives_list = []
        self.downloaded_archives_list = []
        self.all_archives_list = []
        self.show_uninstalled = None
        self.show_installed = None
        self.archives_count_label = None
        self.selected_count_label = None
        self.downloads_folder_line = None
        self.image_label = None
        self.install_archives_on_download = False
        self.burning = False
        self.vlc_process = None
        self.main_window = None
        self.auto_launch = None
        self.background_music = None
        self.install_method_dialog = None
        self.music_player = None
        self.default_separator = None
        self.tabs = None
        self.install_fomods_last = True

    def init(self, organizer):
        self._organizer = organizer
        self._organizer.onUserInterfaceInitialized(self.on_interface_initialized)
        self.downloads_path = organizer.downloadsPath()  # Path to MO2 Downloads
        self.mods_path = organizer.modsPath() # Path to MO2 Mods
        loaded_settings = self.load_settings("auto_launch")
        if not loaded_settings or loaded_settings == "yes":
            self.auto_launch = True
        else:
            self.auto_launch = False
        loaded_settings = self.load_settings("background_music")
        if loaded_settings and loaded_settings == "yes":
            self.background_music = True
        else:
            self.background_music = False
        return True
        
    
    def on_window_close(self, event):
        # stop music player when the plugin UI closes
        global _window_instance, _music_engine
        _window_instance = False
        if not self.background_music_cb.isChecked():
            _music_engine.stop()
            _music_engine= None
        if self.install_method_dialog:
            self.install_method_dialog.close()
            self.install_method_dialog = None
        event.accept()  # allow window to close

    def name(self):
        return "Ultimate Mod Installer"

    def author(self):
        return "illuminoous"

    def description(self):
        return ""

    def version(self):
        return mobase.VersionInfo(1, 0, 0, mobase.ReleaseType.FINAL)

    def isActive(self):
        return self._organizer.pluginSetting(self.name(), "enabled")

    def displayName(self):
        return "Ultimate Mod Installer"

    def icon(self):
        icon_path = os.path.join(os.path.dirname(__file__), "resources/icons/sauron-ring-icon.png")
        return QIcon(icon_path)

    def settings(self):
        return [mobase.PluginSetting("enabled", "Enable this plugin", True)]

    def tooltip(self):
        return ""
    
    def read_meta(self, archive_path, query_string):
        meta_path = archive_path +".meta"
        archive_basename = os.path.basename(archive_path)
        # # If meta does not exists for the archive, set default mod name to archive name
        # if not os.path.exists(meta_path) and query_string == "name":
        #     return archive_basename.split(".")[0]
        if not os.path.exists(meta_path):
            return None
        with open(meta_path, "r", encoding="utf-8") as metaf:
            for line in metaf:
                if "=" in line:
                    key, value = line.split("=", 1)
                    key = key.strip().lower()
                    value = value.strip()
                    if key == query_string.lower():
                        return value
            # If name is requested but wasn't found, 
            # try to set to mod name, if no mod name then archive name
            if query_string == "name":
                for line in metaf:
                    if "=" in line:
                        key, value = line.split("=", 1)
                        key = key.strip().lower()
                        value = value.strip()
                        if key == "modname":
                            return value
                # return archive_basename.split(".")[0]
            return None
        
    """Not needed as of now, but may be in future"""
    # def read_inis(self):
        # """
        # Parse every meta.ini in MODS_FOLDER and return installationFile,
        # which contains the archive name/path used to install it.
        # """
        # archives = []
        # for mod_name in os.listdir(MODS_FOLDER):
            # mod_path = os.path.join(MODS_FOLDER, mod_name)
            # ini_path = os.path.join(mod_path, "meta.ini")
            # if not os.path.isdir(mod_path) or not os.path.isfile(ini_path):
                # continue

            # config = configparser.ConfigParser()
            # config.optionxform = str  # preserve case
            # config.read(ini_path, encoding="utf-8")

            # if config.has_option("General", "installationFile"):
                # archives.append(config.get("General", "installationFile"))
        # return archives

    def set_all_archives_checkstates(self, state):
        for i in range(self.archives_list.rowCount()):
            item = self.archives_list.item(i,0)
            if item is not None:
                item.setCheckState(state)

    def inverse_archives_selection(self):
        for i in range(self.archives_list.rowCount()):
            item = self.archives_list.item(i,0)
            if item is not None:
                if item.checkState() == CHECKED:
                    item.setCheckState(UNCHECKED)
                else:
                    item.setCheckState(CHECKED)

    def get_checked_archives(self):
        return [
            self.archives_list.item(i,0).toolTip()
            for i in range(self.archives_list.rowCount())
            if self.archives_list.item(i,0).checkState() == CHECKED
        ]
        
    def get_all_archives(self):
        return [
            self.archives_list.item(i,0).toolTip()
            for i in range(self.archives_list.rowCount())
        ]
        
    # Not needed as of now
    # def save_checkstates(self):
    #     #self.checked_archives = {}
    #     # Saving check states
    #     try:
    #         for row in range(self.archives_list.rowCount()):
    #             item = self.archives_list.item(row, 0)  # Assuming column 0 is the key
    #             if item is not None:
    #                 key = item.text()
    #                 if key is not None and item.checkState() == CHECKED:
    #                     self.checked_archives[key] = item.checkState()  # Stores CHECKED or Unchecked
    #                 if key is not None and item.checkState() == UNCHECKED and key in self.checked_archives:
    #                     self.checked_archives.pop(key)
                        
    #     except Exception as e:
    #         QMessageBox.information(
    #             None,
    #             "Error",
    #             f"Exception: {e}",
    #         )

    def restore_checkstates(self):
        self.archives_list.blockSignals(True)
        try:
            # Collect valid keys from table
            valid_keys = set()
            for row in range(self.archives_list.rowCount()):
                item = self.archives_list.item(row, 0)
                if item is not None:
                    key = item.text()
                    if key:
                        if key in self.checked_archives:
                            item.setCheckState(CHECKED)
                            valid_keys.add(key)
                        else:
                            item.setCheckState(UNCHECKED)

            # Clean up dict: remove keys not in table anymore
            self.checked_archives = {
                k: v for k, v in self.checked_archives.items() if k in valid_keys
            }

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 3: {e}",
            )

        if self.checked_archives and len(self.checked_archives) > 0:
            self.selected_count_label.setText(f"Checked: {len(self.checked_archives)}")
        else:
            self.selected_count_label.setText(f"")

        self.archives_list.blockSignals(False)

    def save_settings(self, key, value):
        try:
            # Generate saves folder if it doesn't exist
            os.makedirs(os.path.dirname(SAVES), exist_ok=True)
            # Load existing data
            if os.path.exists(SAVES):
                with open(SAVES, "r", encoding="utf-8") as f:
                    data = json.load(f)
            else:
                data = {}

            # Add or update entry
            data[key]=value

            # Save back to JSON
            with open(SAVES, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 4: {e}",
            )

    def load_settings(self, key):
        try:
            # Load data
            if os.path.exists(SAVES):
                with open(SAVES, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    value = data.get(key)
                    return value if value else None
            else:
                return None

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 5: {e}",
            )
            
    def save_downloads_folder_path(self, path):
        if not os.path.isdir(path.strip()):
            return
        path = path.strip()
        self.save_settings("downloads_folder",path)
        QtWidgets.QMessageBox.information(
            self.window, 
            "Success", 
            f"Default downloads folder set to:\n{path}"
        )

    def load_downloads_folder_path(self):
        try:
            path = self.load_settings("downloads_folder")
            if path and os.path.isdir(path):
                self.downloads_folder_line.setText(path)
                self.populate_archives_list()
        except Exception as e:
            QtWidgets.QMessageBox.critical(
                self.window, 
                "Error", 
                f"Exception 6: {e}"
            )
                
    def filter_archives(self, query: str):
        query = query.lower()
        for row in range(self.archives_list.rowCount()):
            item_name = self.archives_list.item(row, 0)
            if item_name:
                text = item_name.text().lower()
                self.archives_list.setRowHidden(row, query not in text)
                
    def on_item_changed(self, item):
        # detect if this was really a checkbox change
        state = item.checkState()
        if state not in (CHECKED, UNCHECKED):
            return 
        if item.column() == 0:  # assuming column 0 is the checkbox
            new_state = item.checkState()
            selected_rows = set(idx.row() for idx in self.archives_list.selectedIndexes())
            # temporarily block signals to avoid recursion
            self.archives_list.blockSignals(True)
            try:
                # apply same check state to all selected rows
                for row in selected_rows:
                    checkbox_item = self.archives_list.item(row, 0)
                    if row != item.row():  # skip the changed item itself
                        #checkbox_item = self.archives_list.item(row, 0)
                        if checkbox_item:
                            checkbox_item.setCheckState(new_state)
                        # update dict
                    if self.checked_archives.get(checkbox_item.text()) == None and new_state == CHECKED: 
                        self.checked_archives[checkbox_item.text()] = CHECKED 
                    if self.checked_archives.get(checkbox_item.text()) != None and new_state == UNCHECKED: 
                        self.checked_archives.pop(checkbox_item.text())  
                if self.checked_archives.get(item.text()) == None and new_state == CHECKED: 
                    self.checked_archives[item.text()] = CHECKED 
                if self.checked_archives.get(item.text()) != None and new_state == UNCHECKED: 
                    self.checked_archives.pop(item.text()) 
                          
            except Exception as err:
                QMessageBox.critical(
                    None,
                    "Error",
                    f"Exception 7: {err}",
                )
            # update label with current count
            if self.checked_archives and len(self.checked_archives) > 0:
                self.selected_count_label.setText(f"Checked: {len(self.checked_archives)}")
            else:
                self.selected_count_label.setText(f"")

            self.archives_list.blockSignals(False)
            
    def apply_default_downloads_path(self):
        self.downloads_folder_line.setText(self.downloads_path)
        self.populate_archives_list()
                
    def on_item_double_clicked(self, item, context_menu=False):
        try:
            self.downloads_folder_line.text()
            archive_path = item.toolTip()
            for dropped_archive_path in self.dropped_archives:
                if dropped_archive_path == item.toolTip():
                    archive_path = dropped_archive_path
                    break
            if self.install_sequentially_cb.isChecked() and context_menu==False:
                self.start_burning()
                mod_name = self.manually_install_archive(archive_path)
                if mod_name:
                    self.update_mod_priority(mod_name)
                    # Refresh table if successful
                    self.populate_archives_list()
                    self.worker.enqueue("refresh",self.worker.refresh)
                self.stop_burning()
                self.window.raise_()
                self.window.activateWindow()
            else:
                # Prio is the last by default
                prio = len(self._organizer.modList().allMods())
                if self.default_separator and self.default_separator_cb.isChecked():
                    mod_list = self._organizer.modList()
                    separators = {}
                    separator_list = []
                    for mod_name in mod_list.allMods():
                        mod = mod_list.getMod(mod_name)
                        if mod and mod.isSeparator():
                            separator_list.append(mod_name)
                            separators[mod_name] = mod_list.priority(mod_name)
                    separator_list.sort(key=lambda p: separators.get(p, 0))
                    if separators[self.default_separator]:
                        next_separator_index = separator_list.index(self.default_separator)+1
                        if next_separator_index < len(separator_list):
                            next_separator = separator_list[next_separator_index]
                            if next_separator: 
                                prio = separators.get(next_separator)
                # Auto enable is enabled by default for double click auto-install
                self.auto_install_archives({archive_path:[prio,True]})
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 8: {e}",
            )
    
    def human_readable_size(self, size_bytes):
        """Convert bytes to KB/MB/GB string"""
        for unit in ["B", "KB", "MB", "GB"]:
            if size_bytes < 1024:
                return f"{size_bytes:.2f} {unit}"
            size_bytes /= 1024
        return f"{size_bytes:.2f} TB"
    
    def populate_archives_list(self):
        try:
            #self.save_checkstates()
            self.archives_list.setSortingEnabled(False)
            self.archives_list.setRowCount(0)
            self.archives_list.setAlternatingRowColors(True)
            # self.archives_list.setStyleSheet("""
            #     QTableWidget {
            #         background-color: #2b2b2b;
            #         alternate-background-color: #1ABC9C;
            #         color: white;
            #     }
            #     """)
            # self.archives_list.setItemDelegate(RowColorDelegate())
            self.installed_archives_list = []
            self.uninstalled_archives_list = []
            self.downloaded_archives_list = []
            self.all_archives_list = []
            #self.archives_list.clearContents()
            downloads_dir = self.downloads_folder_line.text()
            downloaded_count = 0
            installed_count = 0
            uninstalled_count = 0
            self.archives_list.blockSignals(True)
            # Insert dropped archives first (temporary)
            if len(self.dropped_archives) > 0:
                for archive_path in self.dropped_archives:
                    row = self.archives_list.rowCount()
                    self.archives_list.insertRow(row)
                    version = self.read_meta(archive_path,"version")
                    version = " (v"+version+")" if version else ""
                    # Archive name
                    archive_basename = os.path.basename(archive_path)
                    archive_name_stripped = self.extract_mod_name(archive_basename)
                    item_name = QtWidgets.QTableWidgetItem((archive_name_stripped if archive_name_stripped else archive_basename)+version)
                    #item_name.setFlags(item_name.flags() | Qt.ItemFlag.ItemIsUserCheckable)
                    item_name.setCheckState(UNCHECKED)
                    item_name.setFlags(
                        Qt.ItemFlag.ItemIsSelectable |  # row still selectable
                        Qt.ItemFlag.ItemIsEnabled       # enabled but not editable
                    )
                    #font = item_name.font()
                    #font.setUnderline(True)
                    #item_name.setFont(font)
                    item_name.setToolTip(archive_path)
                    
                    # Status
                    item_status = QtWidgets.QTableWidgetItem("Temporary")
                    item_status.setTextAlignment(ALIGN_CENTER)
                    # Color the status
                    item_status.setForeground(QtGui.QColor("red"))
                    item_status.setToolTip("Manually added (temporary)")

                    # File size
                    try:
                        size_bytes = os.path.getsize(archive_path)
                        size_str = self.human_readable_size(size_bytes)
                    except Exception:
                        size_bytes = -1
                        size_str = "N/A"
                    # create numeric-size item using the subclass
                    item_size = NumericSizeItem(size_str)
                    # store the numeric bytes in UserRole so __lt__ can read it
                    item_size.setData(USER_ROLE, int(size_bytes))
                    item_size.setTextAlignment(ALIGN_CENTER)
                    item_size.setToolTip(size_str)

                    file_time = os.path.getmtime(archive_path)
                    t_struct = time.localtime(file_time)
                    file_time_str = f"{t_struct.tm_mon}/{t_struct.tm_mday}/{t_struct.tm_year}  {t_struct.tm_hour%12 or 12}:{t_struct.tm_min:02d} {'AM' if t_struct.tm_hour<12 else 'PM'}"
                    item_time = TimestampItem(file_time_str, file_time)
                    item_time.setToolTip(file_time_str)
                    item_time.setTextAlignment(ALIGN_CENTER)
                    
                    self.archives_list.setItem(row, 0, item_name)
                    self.archives_list.setItem(row, 1, item_status)
                    self.archives_list.setItem(row, 2, item_size)
                    self.archives_list.setItem(row, 3, item_time)
                                    
            for f in os.listdir(downloads_dir):
                if f.lower().endswith((".zip", ".7z", ".rar")):
                    archive_path = os.path.join(downloads_dir, f)                    
                    meta_path = archive_path + ".meta"
                    self.all_archives_list.append(f)
                    
                    installed = False
                    uninstalled = False
                    
                    if os.path.exists(meta_path):
                        with open(meta_path, "r", encoding="utf-8", errors="ignore") as metaf:
                            for line in metaf:
                                if "=" in line:
                                    key, value = line.split("=", 1)
                                    key = key.strip().lower()
                                    value = value.strip().lower()
                                    if (key == "installed" and value == "false"):
                                        break
                                    if (key == "installed" and value == "true"):
                                        installed = True
                                    if (key == "uninstalled" and value == "true"):
                                        uninstalled = True
                                        break
                                    
                    status = "Downloaded"
                    if uninstalled == True:
                        self.uninstalled_archives_list.append(f)
                        uninstalled_count += 1
                        status = "Uninstalled"
                    elif installed == True:
                        self.installed_archives_list.append(f)
                        installed_count += 1
                        status = "Installed"
                    else:
                        self.downloaded_archives_list.append(f)
                        downloaded_count += 1
                        
                    if ((self.show_downloaded.isChecked() and installed == False)
                        or (self.show_installed.isChecked() and installed == True and uninstalled == False)
                        or (self.show_uninstalled.isChecked() and uninstalled == True)):                        
                        
                        row = self.archives_list.rowCount()
                        self.archives_list.insertRow(row)
                        version = self.read_meta(archive_path,"version")
                        version = " (v"+version+")" if version else ""
                        # Archive name
                        archive_basename = os.path.basename(archive_path)
                        archive_name_stripped = self.extract_mod_name(archive_basename)
                        item_name = QtWidgets.QTableWidgetItem((archive_name_stripped if archive_name_stripped else archive_basename)+version)
                        #item_name.setFlags(item_name.flags() | Qt.ItemFlag.ItemIsUserCheckable)
                        item_name.setCheckState(UNCHECKED)
                        item_name.setFlags(
                            Qt.ItemFlag.ItemIsSelectable |  # row still selectable
                            Qt.ItemFlag.ItemIsEnabled       # enabled but not editable
                        )
                        item_name.setToolTip(archive_path)
                        font = item_name.font()
                        font.setLetterSpacing(QtGui.QFont.SpacingType.AbsoluteSpacing, 0.1)  # pixels
                        # font.setWordSpacing(0.1)
                        font.setPointSize(9)

                        item_name.setFont(font)
                        # Archive name
                        # item_name = QtWidgets.QTableWidgetItem(f)
                        #item_name.setFlags(item_name.flags() | Qt.ItemFlag.ItemIsUserCheckable)
                        # item_name.setCheckState(UNCHECKED)
                        # item_name.setFlags(
                        #     Qt.ItemFlag.ItemIsSelectable |  # row still selectable
                        #     Qt.ItemFlag.ItemIsEnabled       # enabled but not editable
                        # )
                        #font = item_name.font()
                        #font.setUnderline(True)
                        #item_name.setFont(font)

                        
                        # Status
                        item_status = QtWidgets.QTableWidgetItem(status)
                        item_status.setTextAlignment(ALIGN_CENTER)

                        # Color the status
                        if status == "Downloaded":
                            item_status.setForeground(QtGui.QColor("green"))
                            item_status.setToolTip("Downloaded")
                        elif status == "Uninstalled":
                            item_status.setForeground(QtGui.QColor("orange"))
                            item_status.setToolTip("Uninstalled")
                        elif status == "Installed":
                            item_status.setForeground(QtGui.QColor("grey"))
                            item_status.setToolTip("Installed")

                        # File size
                        try:
                            size_bytes = os.path.getsize(archive_path)
                            size_str = self.human_readable_size(size_bytes)
                        except Exception:
                            size_bytes = -1
                            size_str = "N/A"
                        # create numeric-size item using the subclass
                        item_size = NumericSizeItem(size_str)
                        # store the numeric bytes in UserRole so __lt__ can read it
                        item_size.setData(USER_ROLE, int(size_bytes))
                        item_size.setTextAlignment(ALIGN_CENTER)
                        item_size.setToolTip(size_str)

                        file_path = os.path.join(downloads_dir, f)
                        file_time = os.path.getmtime(file_path)
                        t_struct = time.localtime(file_time)
                        file_time_str = f"{t_struct.tm_mon}/{t_struct.tm_mday}/{t_struct.tm_year}  {t_struct.tm_hour%12 or 12}:{t_struct.tm_min:02d} {'AM' if t_struct.tm_hour<12 else 'PM'}"
                        item_time = TimestampItem(file_time_str, file_time)
                        item_time.setToolTip(file_time_str)
                        item_time.setTextAlignment(ALIGN_CENTER)
                        
                        self.archives_list.setItem(row, 0, item_name)
                        self.archives_list.setItem(row, 1, item_status)
                        self.archives_list.setItem(row, 2, item_size)
                        self.archives_list.setItem(row, 3, item_time)
                            
            self.archives_list.blockSignals(False)
            self.show_downloaded.setText(f"Downloaded: {downloaded_count}  ")
            self.show_installed.setText(f"Installed: {installed_count}  ")
            self.show_uninstalled.setText(f"Uninstalled: {uninstalled_count}")
            # text_downloaded = f"{'D' if self.show_downloaded.isChecked() else ''}"
            # text_installed = f"{'I' if self.show_installed.isChecked() else ''}"
            # text_uninstalled = f"{'U' if self.show_uninstalled.isChecked() else ''}"
            # text_archives = "Archives ("
            # # When no option is selected
            # if not text_downloaded and not text_installed and not text_uninstalled:
            #     text_archives = "Archives: "
            # else:
            #     if text_downloaded:
            #         text_archives += text_downloaded
            #         if text_installed or text_uninstalled:
            #             text_archives += " + "
            #     if text_installed:
            #         text_archives += text_installed
            #         if text_uninstalled:
            #             text_archives += " + "
            #     if text_uninstalled:
            #         text_archives += text_uninstalled
            #     text_archives += "): "     
            # self.archives_count_label.setText(f"{text_archives}{self.archives_list.rowCount()}")
            # self.archives_count_label.setText(f"Archives: {self.archives_list.rowCount()}")
            self.restore_checkstates()
            #self.archives_list.sortItems(2, DESCENDING_ORDER)  # optional default sort
            self.archives_list.setSortingEnabled(True)
            self.filter_archives(self.search_box.text())

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 9: {e}",
            )
        
    def on_cell_clicked(self, row, column):
        # Only toggle the checkbox in column 0
        if column == 0:
            item = self.archives_list.item(row, column)
            if item is not None:
                if item.checkState() == CHECKED:
                    item.setCheckState(UNCHECKED)
                else:
                    item.setCheckState(CHECKED)
            if self.checked_archives.get(item.text()) == None and item.checkState() == CHECKED: 
                self.checked_archives[item.text()] = CHECKED 
            if self.checked_archives.get(item.text()) != None and item.checkState() == UNCHECKED: 
                self.checked_archives.pop(item.text())

            if self.checked_archives and len(self.checked_archives) > 0:
                self.selected_count_label.setText(f"Checked: {len(self.checked_archives)}")
            else:
                self.selected_count_label.setText(f"")
            # self.archives_list.blockSignals(False)
    
    def delete_archives(self, status):
        reply = QtWidgets.QMessageBox.question(
            self.window,
            "Confirmation",
            f"This will remove {'all the' if status == 'all' else 'all '+status} archives from"
             + " this list and from disk.\n\nAre you absolutely sure you want to proceed?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.No:
            return
            
        deleted_archives = []
        successful = True
        if status == "installed":
            for archive in self.installed_archives_list:
                if self.delete_archive(archive):
                    deleted_archives.append(archive)
                else:
                    successful = False
        elif status == "uninstalled":
            for archive in self.uninstalled_archives_list:
                if self.delete_archive(archive):
                    deleted_archives.append(archive)
                else:
                    successful = False
        elif status == "downloaded":
            for archive in self.downloaded_archives_list:
                if self.delete_archive(archive):
                    deleted_archives.append(archive)
                else:
                    successful = False
        elif status == "all":
            for archive in self.all_archives_list:
                if self.delete_archive(archive):
                    deleted_archives.append(archive)
                else:
                    successful = False
        else:
            # to avoid running the below self.populate if none of the above ran
            return
        
        # Refresh table
        self.populate_archives_list()
        if successful and len(deleted_archives) > 0:
            QtWidgets.QMessageBox.information(
                self.window,
                "Success",
                f"Deleted archives: {deleted_archives}"
            )
        elif successful == False and len(deleted_archives) > 0:
            QtWidgets.QMessageBox.information(
                self.window,
                "Failed to delete all archives",
                f"Deleted archives: {deleted_archives}"
            )
        
    
    def delete_archive(self, archive_path: str):
        try:
            meta_path = archive_path + ".meta"

            deleted_files = []

            # Delete archive
            if os.path.isfile(archive_path):
                os.remove(archive_path)
                deleted_files.append(archive_path)

            # Delete meta
            if os.path.isfile(meta_path):
                os.remove(meta_path)
                deleted_files.append(meta_path)

            if deleted_files:
                if archive_path in self.dropped_archives:
                    self.dropped_archives.remove(archive_path)
                return True
            else:
                QtWidgets.QMessageBox.warning(
                    self.window,
                    "Not Found",
                    f"No files found to delete for: {os.path.basename(archive_path)}"
                )
                return False

        except Exception as e:
            QtWidgets.QMessageBox.critical(
                self.window,
                "Error",
                f"Exception while deleting {os.path.basename(archive_path)}:\n{e}"
            )
     
     
    def on_right_click(self, pos):
        try: 
            index = self.archives_list.indexAt(pos)
            if not index.isValid():
                return

            row = index.row()
            downloads_dir = self.downloads_folder_line.text()
            archive_item = self.archives_list.item(row, 0)
            archive_name = archive_item.text() if archive_item else "<unknown>"
            archive_item1 = self.archives_list.item(row, 1)
            archive_status = archive_item1.text() if archive_item1 else "<unknown>"
            archive_path = os.path.join(downloads_dir, archive_name)
            if archive_status == "Manually Added (temporary)":
                found = False
                for dropped_archive_path in self.dropped_archives:
                    if os.path.basename(dropped_archive_path) == archive_name:
                        archive_path = dropped_archive_path
                        found = True
                if not found:
                    QtWidgets.QMessageBox.information(
                        self.window,
                        "Something went wrong",
                        f"Context menu can't be opened."
                    )
                    return
                        
            meta_path = archive_path + ".meta"

            # Make sure row gets selected on right click
            if not archive_item.isSelected():
                self.archives_list.clearSelection()
                self.archives_list.selectRow(row)
                
            # Get all selected rows
            selected_rows = set(idx.row() for idx in self.archives_list.selectedIndexes())
            selected_archives = [
                self.archives_list.item(row, 0).toolTip() for row in selected_rows
            ]
            # Make sure the clicked row is also selected
            if row not in selected_rows:
                self.archives_list.clearSelection()
                self.archives_list.selectRow(row)
                selected_archives = [self.archives_list.item(row, 0).toolTip()]

            menu = QtWidgets.QMenu(self.archives_list)

            install_multiple_action = None
            manual_install_multiple_action = None
            install_action = None
            manual_install_action = None
            if len(selected_archives) > 1:
                install_multiple_action = menu.addAction(f"Auto-install ({len(selected_archives)})")
                manual_install_multiple_action = menu.addAction(f"Install manually ({len(selected_archives)})")
            else:
                if self.install_sequentially_cb.isChecked():
                    install_action = menu.addAction("Auto-install")
                else:
                    manual_install_action = menu.addAction("Install manually")

            check_all_action = menu.addAction(f"Check all ({self.archives_list.rowCount()})")
            uncheck_all_action = menu.addAction(f"Uncheck all")
            inverse_check_action = menu.addAction("Inverse checked")

            visit_on_nexus_action = None
            open_meta_action = None
            if len(selected_archives) > 1:
                nexus_count = 0
                meta_count = 0
                for archive_name in selected_archives:
                    archive_path = os.path.join(downloads_dir, archive_name)
                    for dropped_archive_path in self.dropped_archives:
                        if os.path.basename(dropped_archive_path) == archive_name:
                            archive_path = dropped_archive_path
                            break
                    if os.path.exists(archive_path + ".meta"):
                        meta_count += 1
                        if self.read_meta(archive_path, "modID") != None:
                            nexus_count += 1
                            
                if nexus_count > 0:
                    visit_on_nexus_action = menu.addAction(f"Visit on Nexus ({nexus_count})")
                    
                open_file_action = menu.addAction(f"Open files ({len(selected_archives)})")
                
                if meta_count > 0:
                    open_meta_action = menu.addAction(f"Open meta files ({meta_count})")
                
                reveal_in_explorer_action = menu.addAction(f"Reveal in explorer ({len(selected_archives)})")
            else:
                nexus_id_exists = False
                meta_exists = False
                for archive_name in selected_archives:
                    archive_path = os.path.join(downloads_dir, archive_name)
                    for dropped_archive_path in self.dropped_archives:
                        if os.path.basename(dropped_archive_path) == archive_name:
                            archive_path = dropped_archive_path
                            break
                    if os.path.exists(archive_path + ".meta"):
                        meta_exists = True
                        if self.read_meta(archive_path, "modID") != None:
                            nexus_id_exists = True
                        break
                if nexus_id_exists:
                    visit_on_nexus_action = menu.addAction("Visit on Nexus")
                open_file_action = menu.addAction("Open file")
                if meta_exists:
                    open_meta_action = menu.addAction("Open meta file")
                reveal_in_explorer_action = menu.addAction("Reveal in explorer")
            
            delete_menu = menu.addMenu("Delete...")
            delete_installed_action = delete_menu.addAction("Delete installed archives")
            delete_uninstalled_action = delete_menu.addAction("Delete uninstalled archives")
            delete_downloaded_action = delete_menu.addAction("Delete downloaded archives")
            delete_all_action = delete_menu.addAction("Delete all archives")
            delete_action = None
            delete_multiple_action = None
            if len(selected_archives) > 1:
                delete_multiple_action = menu.addAction(f"Delete archives ({len(selected_archives)})")
            else:
                delete_action = menu.addAction("Delete archive")
            action = menu.exec(self.archives_list.viewport().mapToGlobal(pos))
            
            # Actual logic
            if action == None:
                return
            
            if action == check_all_action:
                self.set_all_archives_checkstates(CHECKED)

            elif action == uncheck_all_action:
                self.set_all_archives_checkstates(UNCHECKED)

            elif action == inverse_check_action:
                self.inverse_archives_selection()

            elif install_action != None and action == install_action:
                self.on_item_double_clicked(archive_item, context_menu=True)

            elif manual_install_action != None and action == manual_install_action:
                self.start_burning()
                mod_name = self.manually_install_archive(archive_path)
                if mod_name:
                    self.update_mod_priority(mod_name)
                    self.populate_archives_list()
                    self.worker.enqueue("refresh",self.worker.refresh)
                self.stop_burning()

            elif install_multiple_action != None and action == install_multiple_action:
                self.install_archives(type="given",archives=selected_archives)

            elif manual_install_multiple_action != None and action == manual_install_multiple_action:
                self.install_archives(type="given",archives=selected_archives)

            elif delete_action != None and action == delete_action:
                reply = QtWidgets.QMessageBox.question(
                    self.window,
                    "Confirmation",
                    f"This will remove archive from this list and from disk.\n\nAre you sure you want to proceed?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No
                )
                if reply == QMessageBox.StandardButton.No:
                    return
                archive_path = os.path.join(downloads_dir, archive_name)
                for dropped_archive_path in self.dropped_archives:
                    if os.path.basename(dropped_archive_path) == archive_name:
                        archive_path = dropped_archive_path
                        break
                self.delete_archive(archive_path)
                # Refresh table
                self.populate_archives_list()
                
            elif delete_multiple_action != None and action == delete_multiple_action:
                reply = QtWidgets.QMessageBox.question(
                    self.window,
                    "Confirmation",
                    f"This will remove selected archives from this list and from disk.\n\nAre you sure you want to proceed?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No
                )
                if reply == QMessageBox.StandardButton.No:
                    return
                successful = True
                deleted_archives = []
                for archive_name in selected_archives:
                    archive_path = os.path.join(downloads_dir, archive_name)
                    for dropped_archive_path in self.dropped_archives:
                        if os.path.basename(dropped_archive_path) == archive_name:
                            archive_path = dropped_archive_path
                            break
                    if self.delete_archive(archive_path) != True:
                        deleted_archives.append(archive_name)
                        successful = False
                        break
                # Refresh table
                self.populate_archives_list()
                if successful and len(deleted_archives) > 0:
                    QtWidgets.QMessageBox.information(
                        self.window,
                        "Success",
                        f"Deleted archives: {deleted_archives}"
                    )
                elif successful == False and len(deleted_archives) > 0:
                    QtWidgets.QMessageBox.information(
                        self.window,
                        "Failed to delete all archives",
                        f"Deleted archives: {deleted_archives}"
                    )
            elif action == delete_installed_action:
                self.delete_archives("installed")
            elif action == delete_uninstalled_action:
                self.delete_archives("uninstalled")
            elif action == delete_downloaded_action:
                self.delete_archives("downloaded")
            elif action == delete_all_action:
                self.delete_archives("all")

            elif action == open_file_action:
                for archive_name in selected_archives:
                    archive_path = os.path.join(downloads_dir, archive_name)
                    for dropped_archive_path in self.dropped_archives:
                        if os.path.basename(dropped_archive_path) == archive_name:
                            archive_path = dropped_archive_path
                            break
                    os.startfile(archive_path)

            elif open_meta_action != None and action == open_meta_action:
                for archive_name in selected_archives:
                    archive_path = os.path.join(downloads_dir, archive_name)
                    for dropped_archive_path in self.dropped_archives:
                        if os.path.basename(dropped_archive_path) == archive_name:
                            archive_path = dropped_archive_path
                            break
                    try:
                        os.startfile(archive_path + ".meta")
                    except:
                        print("")

            elif action == reveal_in_explorer_action:
                for archive_name in selected_archives:
                    archive_path = os.path.join(downloads_dir, archive_name)
                    for dropped_archive_path in self.dropped_archives:
                        if os.path.basename(dropped_archive_path) == archive_name:
                            archive_path = dropped_archive_path
                            break
                    folder_path = os.path.dirname(archive_path)
                    try:
                        os.startfile(folder_path)
                    except:
                        print("")

            elif visit_on_nexus_action != None and action == visit_on_nexus_action:
                for archive_name in selected_archives:
                    archive_path = os.path.join(downloads_dir, archive_name)
                    for dropped_archive_path in self.dropped_archives:
                        if os.path.basename(dropped_archive_path) == archive_name:
                            archive_path = dropped_archive_path
                            break
                    modid = self.read_meta(archive_path, "modID")
                    if modid != None:
                        game_name = self.game_name_field.text() if self.game_name_field.text() else "skyrimspecialedition"
                        webbrowser.open(f"https://www.nexusmods.com/{game_name}/mods/{modid}")
            
            # self.window.raise_()
            # self.window.activateWindow()
                
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 10: {e}",
            )
        
    def start_burning(self):
        self.burning_widget.toggle_fire(True)
        
    def stop_burning(self):
        self.burning_widget.toggle_fire(False)

    def refresh_archives(self):
        self.dropped_archives = []
        self.populate_archives_list()
        
    def open_alt_window(self):
        window = AltWindow(self)
        window.select_archives()

    def generate_archive_backup(self, archive_name_or_path, mod_name):
        try:
            # Load existing data
            if os.path.exists(ARCHIVES_BACKUP):
                with open(ARCHIVES_BACKUP, "r", encoding="utf-8") as f:
                    data = json.load(f)
            else:
                data = {}

            mod_path = os.path.join(self.mods_path, mod_name)
            # collect all plugins as a set directly
            mod_plugins = {
                f for f in os.listdir(mod_path)
                if f.endswith((".esp", ".esl", ".esm"))
            }
            # Add or update entry
            data[archive_name_or_path] = list(mod_plugins)

            # Save back to JSON
            with open(ARCHIVES_BACKUP, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Generating archive backup failed: {e}",
            )
    
    def generate_archives_backup(self):
        try:
            mod_list = self._organizer.modList()
            archives = {}
            for mod_name in mod_list.allMods():
                mod_plugins = {}
                mod_path = os.path.join(self.mods_path, mod_name)
                if os.path.exists(mod_path):
                    # collect all plugins as a set directly
                    mod_plugins = {
                        f for f in os.listdir(mod_path)
                        if f.endswith((".esp", ".esl", ".esm"))
                    }
                    
                archive_name_or_path = mod_list.getMod(mod_name).installationFile()
                if archive_name_or_path:
                    archives[archive_name_or_path] = mod_plugins
                    
            # Ensure folder exists
            os.makedirs(os.path.dirname(ARCHIVES_BACKUP), exist_ok=True)
            
            # Write everything to JSON
            with open(ARCHIVES_BACKUP, "w", encoding="utf-8") as f:
                json.dump({k: list(v) for k, v in archives.items()}, f, indent=2)
                
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Generating archives backup failed: {e}",
            )
    
    def find_deleted_archives(self):
        try:
            mod_list = self._organizer.modList()
            # Current valid archives
            current_archives = [
                mod_list.getMod(mod_name).installationFile()
                for mod_name in mod_list.allMods()
                if mod_list.getMod(mod_name).installationFile()
            ]
            #current_archives = self.read_inis()
            
            # Load saved archives
            if os.path.exists(ARCHIVES_BACKUP):
                with open(ARCHIVES_BACKUP, "r", encoding="utf-8") as f:
                    saved_archives = json.load(f) 
            else:
                saved_archives = {}
                
            # Find deleted ones
            archives_deleted = {a: saved_archives[a] for a in saved_archives if a not in current_archives}
            # Update JSON (remove deleted archives, keep existing ones)
            updated_archives = {a: saved_archives[a] for a in saved_archives if a in current_archives}
            
            with open(ARCHIVES_BACKUP, "w", encoding="utf-8") as f:
                json.dump(updated_archives, f, indent=2, ensure_ascii=False)
            return archives_deleted
            
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Retrieving deleted archives failed: {e}",
            )

    def display(self):
        global _window_instance
        if _window_instance:
            _window_instance.raise_()
            _window_instance.activateWindow()
            return

        self.window = QtWidgets.QWidget()
        _window_instance = self.window
        self.window._organizer = self._organizer
        self.window.setWindowTitle("Ultimate Mod Installer")
        self.window.setMinimumWidth(250)
        layout = QtWidgets.QVBoxLayout()
        # layout.setContentsMargins(10,0,10,10)
           
        self.worker = TaskWorker(SEVEN_ZIP, organizer=self._organizer, plugin=self)
        self.worker.taskFinished.connect(self.on_task_finished)
        self.worker.taskCanceled.connect(self.on_task_canceled)
        self.worker.start()
        
        title_ring_wrapper = QtWidgets.QVBoxLayout()
        title_label = QtWidgets.QLabel("One Installer")
        title_label.setWordWrap(True)
        title_label.setAlignment(ALIGN_CENTER)
        font = title_label.font()
        font.setPointSize(9)
        font.setBold(True)
        title_label.setFont(font)

        title_label1 = QtWidgets.QLabel("To Run Them All")
        title_label1.setWordWrap(True)
        title_label1.setAlignment(ALIGN_CENTER)
        font = title_label1.font()
        font.setPointSize(8)
        font.setBold(True)
        title_label1.setFont(font)
        
        ring_icon = os.path.join(os.path.dirname(__file__), "resources/icons/sauron-ring-icon-big.png")
        fire_gif = os.path.join(os.path.dirname(__file__), "resources/gifs/fire.gif")
        self.burning_widget = BurningImage(ring_icon, fire_gif, False, self)
        self.burning_widget.mousePressEvent = lambda event: self.install_archives(type="all")
        

        # Ribbon tabs
        # self.tabs = QtWidgets.QTabWidget()

        # === First tab: your current QTable ===
        # Create the table
        self.archives_list = ArchiveTable(self)
        # self.tabs.addTab(self.archives_list, "All")

        # # === Second tab: interactive table (archive install order) ===
        # self.table2 = QtWidgets.QTableWidget(5, 2)
        # self.table2.setHorizontalHeaderLabels(["Archive", "Order"])
        # self.table2.setDragDropMode(QtWidgets.QAbstractItemView.DragDropMode.InternalMove)  # reorder rows
        # self.tabs.addTab(self.table2, "Waiting to install")

        title_ring_wrapper.addWidget(title_label, alignment=ALIGN_CENTER)
        title_ring_wrapper.addWidget(self.burning_widget, alignment=ALIGN_CENTER)
        title_ring_wrapper.addWidget(title_label1, alignment=ALIGN_CENTER)

        checkboxes_wrapper = QtWidgets.QVBoxLayout()
        checkboxes_wrapper.setSpacing(0)

        self.auto_launch_cb = QtWidgets.QCheckBox("Embedd into MO2 (requires MO2 restart)")
        loaded_settings = self.load_settings("auto_launch")
        self.auto_launch_cb.setChecked(True if not loaded_settings or loaded_settings == "yes" else False)
        self.auto_launch_cb.stateChanged.connect(lambda checked: self.save_settings("auto_launch","yes" if checked else "no"))

        self.music_player = get_music_player_widget(self,MUSIC_FOLDER,AudioPlayer)

        self.background_music_cb = QtWidgets.QCheckBox("Enable/disable music")
        # self.background_music_cb.setToolTip("Completely disables music")
        loaded_settings = self.load_settings("background_music")
        self.background_music_cb.setChecked(False if loaded_settings and loaded_settings == "no" else True)
        def change_music_settings(checked):
            self.save_settings("background_music","yes" if checked else "no")
            if checked:
                # _music_engine = MusicEngine(MUSIC_FOLDER, AudioPlayer)
                volume = self.load_settings("volume")
                self.music_player.start_playback(volume=volume if volume else 50)
                # if volume:
                #     _music_engine.play_random_song(volume=int(volume))
                # else:
                #     _music_engine.play_random_song()
            else:
                self.music_player.stop_playback()

        self.background_music_cb.stateChanged.connect(lambda checked: change_music_settings(checked))

        self.install_sequentially_cb = QtWidgets.QCheckBox("Sequential/Manual Installing")
        self.install_sequentially_cb.setToolTip("Switches Auto-Install(default) to MO's Manual Install(safer, but much more headache-inducing)")
        loaded_settings = self.load_settings("install_sequentially")
        self.install_sequentially_cb.setChecked(True if loaded_settings and loaded_settings == "yes" else False)
        self.install_sequentially_cb.stateChanged.connect(lambda checked: self.save_settings("install_sequentially","yes" if checked else "no"))

        self.auto_install_cb = QtWidgets.QCheckBox("Auto-install archives on download")
        loaded_settings = self.load_settings("auto_install_downloaded")
        self.auto_install_cb.setChecked(True if loaded_settings and loaded_settings == "yes" else False)
        self.auto_install_cb.stateChanged.connect(lambda checked: self.save_settings("auto_install_downloaded","yes" if checked else "no"))

        self.default_separator_cb = QtWidgets.QCheckBox("Install archives under default separator")
        self.default_separator_cb.setToolTip(
            "Used when installing mods individually. You can set Default separator in Install Dialog window")
        loaded_settings = self.load_settings("use_default_separator")
        self.default_separator_cb.setChecked(True if loaded_settings and loaded_settings == "yes" else False)
        self.default_separator_cb.stateChanged.connect(lambda checked: self.save_settings("use_default_separator","yes" if checked else "no"))
        # Setting default separator
        loaded_settings = self.load_settings("default_separator")
        if loaded_settings: self.default_separator = loaded_settings

        checkboxes_wrapper.addWidget(self.background_music_cb)
        checkboxes_wrapper.addWidget(self.install_sequentially_cb)
        # if not self.auto_launch: checkboxes_wrapper.addWidget(self.background_music_cb)
        checkboxes_wrapper.addWidget(self.auto_install_cb)
        checkboxes_wrapper.addWidget(self.default_separator_cb)
        checkboxes_wrapper.addWidget(self.auto_launch_cb)
        
        editable_wrapper = QtWidgets.QHBoxLayout()
        prefix_suffix_wrapper = QtWidgets.QHBoxLayout()
        mod_prefix_layout = QtWidgets.QVBoxLayout()
        mod_prefix_layout.addWidget(QtWidgets.QLabel("Mod prefix:"))
        mod_prefix = self.load_settings("mod_prefix")
        self.mod_prefix_field = EditableField(mod_prefix if mod_prefix else "", "mod_prefix", self)
        mod_prefix_layout.addWidget(self.mod_prefix_field)
        mod_suffix_layout = QtWidgets.QVBoxLayout()
        mod_suffix_layout.addWidget(QtWidgets.QLabel("Mod suffix:"))
        mod_suffix = self.load_settings("mod_suffix")
        self.mod_suffix_field = EditableField(mod_suffix if mod_suffix else "", "mod_suffix", self)
        mod_suffix_layout.addWidget(self.mod_suffix_field)
        
        prefix_suffix_wrapper.addLayout(mod_prefix_layout)
        prefix_suffix_wrapper.addSpacing(5)
        prefix_suffix_wrapper.addLayout(mod_suffix_layout)
           
        game_name_layout = QtWidgets.QVBoxLayout()
        game_name_layout.addWidget(QtWidgets.QLabel(f"""Game (for 'Visit on Nexus' to function properly):"""))
        game_name = self.load_settings("game_name")
        self.game_name_field = EditableField(game_name if game_name else "skyrimspecialedition", plugin=self)
        game_name_layout.addWidget(self.game_name_field)
        
        # editable_wrapper.addLayout(game_name_layout)
        # editable_wrapper.addSpacing(20)
        editable_wrapper.addLayout(prefix_suffix_wrapper)
     
        # Downloads Selector
        self.downloads_folder_line = DragDropLineEdit(plugin=self)
        self.downloads_folder_line.setFocusPolicy(STRONG_FOCUS)
        self.downloads_folder_line.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, False)
        self.downloads_folder_line.setReadOnly(True)
        downloads_folder_layout = QtWidgets.QHBoxLayout()
        downloads_folder_layout.setSpacing(0)
        base_default = self._organizer.overwritePath()
        self.downloads_folder_line.setText(self._organizer.downloadsPath())
        # Reset Button
        reset_btn = QtWidgets.QPushButton()
        reset_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        reset_icon = self.window.style().standardIcon(QtWidgets.QStyle.StandardPixmap.SP_BrowserReload)
        reset_btn.setIcon(reset_icon)
        reset_btn.setToolTip("Set to organizer's downloads folder")
        reset_btn.setFixedWidth(28)
        reset_btn.clicked.connect(lambda: self.apply_default_downloads_path())
        # Save Button
        icon_path = os.path.join(os.path.dirname(__file__), "resources/icons/save.png")
        save_icon = QtGui.QIcon(icon_path)
        save_icon = self.window.style().standardIcon(QtWidgets.QStyle.StandardPixmap.SP_DialogSaveButton)
        save_btn = QtWidgets.QPushButton()
        save_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        save_btn.setIcon(save_icon)
        save_btn.setToolTip("Save downloads folder path")
        save_btn.setFixedWidth(28)
        save_btn.clicked.connect(lambda: self.save_downloads_folder_path(self.downloads_folder_line.text()))

        wrapper_downloads_layout = QtWidgets.QVBoxLayout()
        downloads_folder_layout.addWidget(self.downloads_folder_line)
        downloads_folder_layout.addWidget(reset_btn)
        downloads_folder_layout.addWidget(save_btn)
        wrapper_downloads_layout.addWidget(QtWidgets.QLabel("Downloads folder:"))
        wrapper_downloads_layout.addLayout(downloads_folder_layout)

        # tab_wrapper = QtWidgets.QHBoxLayout()

        # tab_index_wrapper = QtWidgets.QVBoxLayout()
        # tab_index_label = QtWidgets.QLabel()
        # tab_index_label.setText("UMI tab index(0-5):")
        # tab_index = QtWidgets.QSpinBox()
        # tab_index.setRange(0, 5)
        # self.prev_index = tab_index.value()
        # def on_tab_index_changed(value):
        #     self.save_settings("umi_tab_index",value)
        #     if self.tabs: self.tabs.tabBar().moveTab(self.prev_index, value)
        #     self.prev_index = value

        # tab_index.valueChanged.connect(on_tab_index_changed)
        # tab_index_loaded = self.load_settings("umi_tab_index")
        # # if tab_index_loaded: 
        # #     self.prev_index = tab_index_loaded
        # #     tab_index.setValue(tab_index_loaded)
        # tab_index_wrapper.addWidget(tab_index_label)
        # tab_index_wrapper.addWidget(tab_index)
        
        settings_wrapper = QtWidgets.QVBoxLayout()
        settings_wrapper.addLayout(wrapper_downloads_layout)
        settings_wrapper.addLayout(editable_wrapper)
        

        if self.auto_launch:
            default_tab_wrapper = QtWidgets.QHBoxLayout()
            # default_tab_wrapper.setAlignment(Qt.AlignmentFlag.AlignLeft)
            default_tab_label = QtWidgets.QLabel()
            default_tab_label.setText("Default tab:")
            default_tab = QtWidgets.QComboBox()
            default_tab.addItems(["Ultimate Mod Installer","Plugins","Archives", 
                                "Data","Saves","Downloads"])
            def on_default_tab_changed(index):
                self.save_settings("default_tab",default_tab.currentText())
            default_tab.currentIndexChanged.connect(on_default_tab_changed)
            default_tab.setSizePolicy(
                QtWidgets.QSizePolicy.Policy.Expanding,
                QtWidgets.QSizePolicy.Policy.Fixed
            )
            default_tab_loaded = self.load_settings("default_tab")
            if default_tab_loaded: default_tab.setCurrentText(default_tab_loaded)
            else: default_tab.setCurrentText("Ultimate Mod Installer")
            default_tab_wrapper.addWidget(default_tab_label, alignment=Qt.AlignmentFlag.AlignLeft)
            default_tab_wrapper.addWidget(default_tab)
            settings_wrapper.addLayout(default_tab_wrapper)

        settings_wrapper.addLayout(checkboxes_wrapper)

        settings_popup = QtWidgets.QWidget(self.window,POPUP)
        settings_popup.setWindowFlags(Qt.WindowType.Tool)
        settings_popup_layout = QtWidgets.QVBoxLayout(settings_popup)
        settings_popup_layout.addLayout(settings_wrapper)

        settings_popup_height = settings_popup.size().height()
        settings_popup.setMinimumWidth(350)
        settings_popup.setMaximumWidth(600)
        settings_popup.setMaximumHeight(settings_popup_height)

        settings_icon_path = os.path.join(os.path.dirname(__file__), "resources/icons/settings1.png")
        settings_icon = QtGui.QIcon(settings_icon_path)
        settings_label = QtWidgets.QLabel()
        settings_label.setPixmap(settings_icon.pixmap(16, 16))
        # settings_btn = QtWidgets.QPushButton()
        # settings_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        # settings_btn.setIcon(settings_icon)
        # settings_btn.setToolTip("Change settings")
        def open_settings_popup():
            settings_popup.adjustSize()  # important
            global_pos = settings_label.mapToGlobal(settings_label.rect().topRight())
            x = global_pos.x()
            y = global_pos.y()
            # 8 is half the icon size, so its positioned a lil better
            settings_popup.move(x - settings_popup.width()-8, y-settings_popup.height()-20) or settings_popup.show()
        # settings_btn.clicked.connect(open_settings_popup)
        settings_label.mousePressEvent = lambda event: open_settings_popup()
        settings_label.setCursor(POINTING_HAND_CURSOR)

        info_icon_path = os.path.join(os.path.dirname(__file__), "resources/icons/info.png")
        info_icon = QtGui.QIcon(info_icon_path)
        info_label = QtWidgets.QLabel()
        info_label.setPixmap(info_icon.pixmap(16, 16))
        tool_tip_text = (
            "-You can see tool tip for almost everything in UI, just hover over "
            "a widget, it'll explain what \nthat option does"
            "\n"
            "-You can adjust tab order, as well as a default opened tab"
            "\n"
            "-You can adjust row height using Ctrl + MouseScrollUp/Down, "
            "the changes will persist"
            "\n"
            "-Archives will show up only after they are finished downloading, "
            "if not, click 'Refresh' button" 
            "\n"
            "-The sequential installations will cancel if you cancel any of the "
            "individual installations"
            "\n"
            "-Hold Ctrl/Shift + LeftClick to check multiple selected archives"
            "\n"
            "-You can drag and drop archives to add them temporarily"
            "\n"
            "-Click on RING if you want to install all the shown archives"
            "\n"
            "-Click on Gandalf to feed him some tunes!"
        )
        info_label.setToolTip(tool_tip_text)

        # self.music_player = get_music_player_widget(self,MUSIC_FOLDER,AudioPlayer)
        # music_wrapper = QtWidgets.QHBoxLayout()        
        # music_wrapper.addWidget(self.music_player)
        # music_wrapper.setContentsMargins(0,0,0,0)

        music_popup = QtWidgets.QWidget(self.window,POPUP)
        music_popup.setWindowFlags(Qt.WindowType.Tool)
        music_popup_layout = QtWidgets.QVBoxLayout(music_popup)
        music_popup_layout.addWidget(self.music_player, alignment=ALIGN_CENTER)

        music_popup.adjustSize()
        music_popup.setFixedSize(music_popup.size())

        music_icon_path = os.path.join(os.path.dirname(__file__), "resources/icons/music.png")
        music_icon = QtGui.QIcon(music_icon_path)
        music_label = QtWidgets.QLabel()
        music_label.setPixmap(music_icon.pixmap(16, 16))
        # settings_btn = QtWidgets.QPushButton()
        # settings_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        # settings_btn.setIcon(settings_icon)
        # settings_btn.setToolTip("Change settings")
        def open_music_popup():
            music_popup.adjustSize()  # important
            global_pos = music_label.mapToGlobal(music_label.rect().topRight())
            x = global_pos.x()
            y = global_pos.y()
            # 8 is half the icon size, so its positioned a lil better
            music_popup.move(x - music_popup.width()-8, y-music_popup.height()-20) or music_popup.show()
        # settings_btn.clicked.connect(open_settings_popup)
        music_label.mousePressEvent = lambda event: open_music_popup()
        music_label.setCursor(POINTING_HAND_CURSOR)

        config_layout = QtWidgets.QHBoxLayout()
        wrapper = QtWidgets.QHBoxLayout()
        wrapper.addWidget(music_label)
        wrapper.addWidget(info_label)
        wrapper.addWidget(settings_label)
        wrapper.addSpacing(3)
        
        wrapper.setAlignment(ALIGN_TOP | Qt.AlignmentFlag.AlignRight)
        config_layout.addLayout(wrapper)

        # Main grid layout
        music_title_container = QtWidgets.QWidget()
        music_title_wrapper = QtWidgets.QGridLayout(music_title_container)

        show_hide_label = QtWidgets.QLabel()
        # show_hide_btn = QtWidgets.QPushButton()
        # show_hide_btn.setFixedWidth(20)
        # show_hide_btn.setFixedHeight(10)
        up_icon = QtGui.QIcon(os.path.join(os.path.dirname(__file__), "resources/icons/up.png"))
        down_icon = QtGui.QIcon(os.path.join(os.path.dirname(__file__), "resources/icons/down.png"))
        show_hide_label.setPixmap(up_icon.pixmap(10, 10))
        

        def toggle_music_wrapper():
            # flip
            visible = not music_title_container.isVisible()
            music_title_container.setVisible(visible)
            # show_hide_btn.setIcon(down_icon) if visible else show_hide_btn.setIcon(up_icon)
            show_hide_label.setPixmap(down_icon.pixmap(10, 10)) if visible else show_hide_label.setPixmap(up_icon.pixmap(10, 10))
            self.save_settings("mm_expanded", "yes" if visible else "no")

        show_hide_label.mousePressEvent = lambda event: toggle_music_wrapper()
        show_hide_label.setCursor(POINTING_HAND_CURSOR)
        # show_hide_btn.setIcon(up_icon)
        # show_hide_btn.clicked.connect(toggle_music_wrapper)

        # PLAY MUSIC (T-T)
        # self.music_player = get_music_player_widget(self,MUSIC_FOLDER,AudioPlayer)
        # music_wrapper = QtWidgets.QHBoxLayout()        
        # music_wrapper.addWidget(self.music_player, alignment=ALIGN_TOP)
        # music_wrapper.addStretch()
        # music_wrapper.setContentsMargins(0,0,0,0)

        music_title_wrapper.setContentsMargins(0,0,0,0)
        
        # Place left block in column 0, aligned left
        # music_title_wrapper.addLayout(music_wrapper, 0, 0,alignment=Qt.AlignmentFlag.AlignTop)
        # music_title_wrapper.addLayout(0, 0)

        # Place center block in column 1, centered
        music_title_wrapper.addLayout(title_ring_wrapper, 0, 1)  

        music_title_wrapper.addLayout(config_layout, 0, 2)

        # Add stretch in column 2 to push things properly
        music_title_wrapper.setColumnStretch(0, 1)  # left
        music_title_wrapper.setColumnStretch(1, 0)  # center stays fixed
        music_title_wrapper.setColumnStretch(2, 1)  # right "spacer"

        
        # layout.addLayout(music_title_wrapper)
        
        # Installation Buttons
        style = "QPushButton { min-height: 30px; max-height: 30px; }"
        install_btn_layout = QtWidgets.QHBoxLayout()
        install_all_btn = QtWidgets.QPushButton("Install...")
        install_all_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        install_all_btn.clicked.connect(self.open_alt_window)
        install_all_btn.setToolTip("Opens a window to select and install archives")
        install_all_btn.setStyleSheet(style)
        install_selected_btn = QtWidgets.QPushButton("Install checked")
        install_selected_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        install_selected_btn.clicked.connect(lambda: self.install_archives(type="selected"))
        install_selected_btn.setStyleSheet(style)
        install_btn_layout.addWidget(install_all_btn)
        # install_btn_layout.addSpacing(10)
        install_btn_layout.addWidget(install_selected_btn)

        # Archives Checkboxes
        self.show_downloaded = QtWidgets.QCheckBox("Downloaded: N/A")
        self.show_installed = QtWidgets.QCheckBox("Installed: N/A")
        self.show_uninstalled = QtWidgets.QCheckBox("Uninstalled: N/A")
        self.show_downloaded.setStyleSheet("QCheckBox { white-space: normal; }")
        self.show_installed.setStyleSheet("QCheckBox { white-space: normal; }")
        self.show_uninstalled.setStyleSheet("QCheckBox { white-space: normal; }")
        def show_downloaded_save():
            if self.show_downloaded.isChecked(): self.save_settings("show_downloaded","yes")
            else: self.save_settings("show_downloaded","no")
            self.populate_archives_list()
        def show_installed_save():
            if self.show_installed.isChecked(): self.save_settings("show_installed","yes")
            else: self.save_settings("show_installed","no")
            self.populate_archives_list()
        def show_uninstalled_save():
            if self.show_uninstalled.isChecked(): self.save_settings("show_uninstalled","yes")
            else: self.save_settings("show_uninstalled","no")
            self.populate_archives_list()
        self.show_downloaded.clicked.connect(show_downloaded_save)
        self.show_installed.clicked.connect(show_installed_save)
        self.show_uninstalled.clicked.connect(show_uninstalled_save)

        show_downloaded_load = self.load_settings("show_downloaded")
        if show_downloaded_load and show_downloaded_load == "no": self.show_downloaded.setChecked(False)
        else: self.show_downloaded.setChecked(True)

        show_installed_load = self.load_settings("show_installed")
        if show_installed_load and show_installed_load == "yes": self.show_installed.setChecked(True)
        else: self.show_installed.setChecked(False)

        show_uninstalled_load = self.load_settings("show_uninstalled")
        if show_uninstalled_load and show_uninstalled_load == "yes": self.show_uninstalled.setChecked(True)
        else: self.show_uninstalled.setChecked(False)

        checkboxes_layout = QtWidgets.QVBoxLayout()
        checkboxes_layout.addWidget(self.show_downloaded)
        checkboxes_layout.addWidget(self.show_installed)
        checkboxes_layout.addWidget(self.show_uninstalled)

        filter_icon_path = os.path.join(os.path.dirname(__file__), "resources/icons/filter.png")
        filter_icon = QtGui.QIcon(filter_icon_path)
        filter_btn = QtWidgets.QPushButton()
        filter_btn.setIcon(filter_icon)
        filter_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        filter_btn.setToolTip("Filter archives")
        filter_popup = QtWidgets.QWidget(self.window,POPUP)
        popup_layout = QtWidgets.QVBoxLayout(filter_popup)

        popup_layout.addLayout(checkboxes_layout)

        filter_btn.clicked.connect(lambda: filter_popup.move(filter_btn.mapToGlobal(filter_btn.rect().bottomLeft())) or filter_popup.show())
        
        self.search_box = QtWidgets.QLineEdit()
        self.search_box.setPlaceholderText("Search archives...")
        self.search_box.textChanged.connect(self.filter_archives)
        
        # wrapper_downloads_layout = QtWidgets.QVBoxLayout()
        # downloads_folder_layout.addWidget(self.downloads_folder_line)
        # downloads_folder_layout.addWidget(reset_btn)
        # downloads_folder_layout.addWidget(save_btn)
        # wrapper_downloads_layout.addWidget(QtWidgets.QLabel("Downloads Folder (click or drag and drop to change folder):"))
        # wrapper_downloads_layout.addLayout(downloads_folder_layout)

        # self.archives_count_label = QtWidgets.QLabel()
        self.selected_count_label = QtWidgets.QLabel()
        # self.archives_count_label.setWordWrap(True)
        # self.selected_count_label.setWordWrap(True)

        refresh_mods_btn = QtWidgets.QPushButton()
        refresh_mods_btn.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        refresh_mods_btn.setText('Refresh')
        refresh_mods_btn.setToolTip("Reload archives from downlaods folder (will remove drag and dropped archives)")
        refresh_mods_btn.clicked.connect(lambda: self.refresh_archives())
        #refresh_mods_btn.setFixedSize(120, 40)

        refresh_btn_layout = QtWidgets.QHBoxLayout()
        refresh_btn_layout.addSpacing(5)
        refresh_btn_layout.addWidget(self.selected_count_label, alignment=Qt.AlignmentFlag.AlignLeft)
        # refresh_btn_layout.addWidget(self.archives_count_label, alignment=Qt.AlignmentFlag.AlignLeft)
        # refresh_btn_layout.addStretch()
        refresh_btn_layout.addWidget(refresh_mods_btn, alignment=Qt.AlignmentFlag.AlignRight)
        

        # layout.addLayout(refresh_btn_layout)
        # layout.addWidget(self.archives_list)
        # layout.addWidget(self.tabs)

        include_search_layout = QtWidgets.QHBoxLayout()
        include_search_layout.addWidget(filter_btn)
        include_search_layout.addWidget(self.search_box)
        
        # editable_wrapper = QtWidgets.QHBoxLayout()
        # prefix_suffix_wrapper = QtWidgets.QHBoxLayout()
        # mod_prefix_layout = QtWidgets.QVBoxLayout()
        # mod_prefix_layout.addWidget(QtWidgets.QLabel("Mod prefix:"))
        # mod_prefix = self.load_settings("mod_prefix")
        # self.mod_prefix_field = EditableField(mod_prefix if mod_prefix else "", "mod_prefix", self)
        # mod_prefix_layout.addWidget(self.mod_prefix_field)
        # mod_suffix_layout = QtWidgets.QVBoxLayout()
        # mod_suffix_layout.addWidget(QtWidgets.QLabel("Mod suffix:"))
        # mod_suffix = self.load_settings("mod_suffix")
        # self.mod_suffix_field = EditableField(mod_suffix if mod_suffix else "", "mod_suffix", self)
        # mod_suffix_layout.addWidget(self.mod_suffix_field)
        
        # prefix_suffix_wrapper.addLayout(mod_prefix_layout)
        # prefix_suffix_wrapper.addSpacing(5)
        # prefix_suffix_wrapper.addLayout(mod_suffix_layout)
        
        # editable_wrapper.addLayout(game_name_layout)
        # editable_wrapper.addSpacing(20)
        # editable_wrapper.addLayout(prefix_suffix_wrapper)

        # wrapper_downloads_layout = QtWidgets.QVBoxLayout()
        # downloads_folder_layout.addWidget(self.downloads_folder_line)
        # downloads_folder_layout.addWidget(reset_btn)
        # downloads_folder_layout.addWidget(save_btn)
        # wrapper_downloads_layout.addWidget(QtWidgets.QLabel("Downloads Folder (click or drag and drop to change folder):"))
        # wrapper_downloads_layout.addLayout(downloads_folder_layout)

        # LAYOUT
        layout.addLayout(refresh_btn_layout)
        layout.addWidget(self.archives_list)
        layout.addLayout(include_search_layout)
        # layout.addWidget(show_hide_btn, alignment=Qt.AlignmentFlag.AlignLeft)
        layout.addWidget(show_hide_label, alignment=ALIGN_CENTER)
        layout.addWidget(music_title_container)
        mm_expanded = self.load_settings("mm_expanded")
        if mm_expanded and mm_expanded == "no":
            music_title_container.setVisible(False)
        else:
            # show_hide_btn.setIcon(down_icon)
            show_hide_label.setPixmap(down_icon.pixmap(10, 10))
        layout.addSpacing(2)
        
        self.load_downloads_folder_path()
        
        layout.addLayout(install_btn_layout)
        
        # Register the handlers once
        self._organizer.downloadManager().onDownloadComplete(self.on_archive_download_finished)
        self._organizer.downloadManager().onDownloadRemoved(lambda id: self.populate_archives_list())
        self._organizer.modList().onModRemoved(self.on_mod_removed)
        self.window.setLayout(layout)
        #self.window.setMinimumSize(800, 600)
        self.window.resize(800, 600)
        self.window.closeEvent = self.on_window_close
        self.window.show()
        QTimer.singleShot(0, self.populate_archives_list)
        QTimer.singleShot(0, self.dispaly_init)
        self.generate_archives_backup()

    def dispaly_init(self):
        # Focus plugin window on MO run
        self.window.raise_()
        self.window.activateWindow()

    def get_file_info(self,mod_id,file_id):
        api_key= "" # user paste their api key here, could be useful in the future
        url = f"https://api.nexusmods.com/v3/games/skyrimspecialedition/mod-files/{file_id}"
        
        req = urllib.request.Request(url)
        req.add_header("apikey", api_key)
        # req.add_header("Application-Name", "MO2Plugin")

        with urllib.request.urlopen(req) as response:
            data = response.read().decode("utf-8")
            return json.loads(data)

    def on_interface_initialized(self, main_window):
        global _music_engine
        if self.background_music:
            _music_engine = MusicEngine(MUSIC_FOLDER, AudioPlayer)
            is_muted = self.load_settings("is_muted")
            if is_muted and is_muted == "yes":
                _music_engine.is_muted = True

            repeat = self.load_settings("repeat_on")
            if repeat and repeat == "yes":
                _music_engine.repeat_on = True

            volume = self.load_settings("volume")
            if volume:
                _music_engine.play_random_song(volume=int(volume))
            else:
                _music_engine.play_random_song()

        self.main_window = main_window
        self._close_watcher = CloseWatcher(self.on_window_close)
        self.main_window.installEventFilter(self._close_watcher)

        if self.auto_launch:
            self.display()
            # Create once
            if not hasattr(self, "dock"):
                try:
                    from PyQt6 import QtWidgets, QtCore, QtGui
                    QAction = QtGui.QAction
                except:
                    from PyQt5 import QtWidgets, QtCore, QtGui
                    QAction = QtWidgets.QAction


                #self.dock = QtWidgets.QDockWidget("Ultimate Mod Installer", main_window)
                self.widget = self.window
                #self.dock.setWidget(self.widget)
                self.tabs = main_window.findChild(QtWidgets.QTabWidget)
                self.tabs.insertTab(0, self.widget, "Ultimate Mod Installer")
                # icon_path = os.path.join(BASE_DIR, "resources/icons/sauron-ring-icon.png")
                # tab_index = self.load_settings("umi_tab_index")
                # tab_index = tab_index if tab_index else 0
                
                # all_tabs={
                #     "Plugins":0,
                #     "Archives":1,
                #     "Data":2,
                #     "Saves":3,
                #     "Downloads":4,
                #     "Ultimate Mod Installer":5
                # }
                # self.tabs.insertTab(tab_index, self.widget, "Ultimate Mod Installer")
                # if default_tab == "Ultimate Mod Installer": 
                #     self.tabs.setCurrentIndex(tab_index)
                # elif all_tabs[default_tab] < tab_index:
                #     self.tabs.setCurrentIndex(all_tabs[default_tab])
                # else:
                #     self.tabs.setCurrentIndex(all_tabs[default_tab]+1)

                self.tabs.setMovable(True)
                def on_tab_moved(from_index,to_index):
                    order = []
                    for i in range(self.tabs.count()):
                        order.append(self.tabs.tabText(i))
                    self.save_settings("tab_order", order)
                self.tabs.tabBar().tabMoved.connect(on_tab_moved)

                default_tab = self.load_settings("default_tab")
                default_tab = default_tab if default_tab else "Ultimate Mod Installer"
                tab_order = self.load_settings("tab_order")
                tab_index = 0
                if tab_order:
                    for pos, tab_name in enumerate(tab_order):
                        for current in range(self.tabs.count()):
                            if self.tabs.tabText(current) == tab_name:
                                self.tabs.tabBar().moveTab(current, pos)
                                break
                        if tab_name == default_tab:
                            tab_index = pos

                self.tabs.setCurrentIndex(tab_index)

                # main_window.addDockWidget(
                #    QtCore.Qt.DockWidgetArea.RightDockWidgetArea,
                #    self.dock
                # )

            # Toggle visibility
            # self.dock.setvisible(not self.dock.isvisible())
            # icon_path = os.path.join(os.path.dirname(__file__), "resources/icons/sauron-ring-icon.png")
            # self.toggle_action = qaction(main_window)
            # self.toggle_action.setcheckable(true)
            # self.toggle_action.setchecked(true)
            # self.toggle_action.seticon(qtgui.qicon(icon_path))
            # self.toggle_action.settooltip("show/hide umi")
            # self.toggle_action.toggled.connect(self.dock.setvisible)
            # self.dock.visibilitychanged.connect(self.toggle_action.setchecked)
            # main_window.addtoolbar("tools").addaction(self.toggle_action)

    def on_mod_removed(self, mod_name):
        deleted_archives = self.find_deleted_archives()
        if deleted_archives:
            for deleted_archive in deleted_archives:
                """ Check if it's whole path or just archive name,
                if archive name then archive's probably directly in
                Downloads folder, else it's in another location """
                if not os.path.isdir(deleted_archive):
                    archive_path = os.path.join(self.downloads_path, deleted_archive)
                    self.write_meta(archive_path, "installed", "true")
                    self.write_meta(archive_path, "uninstalled", "true")
                else:
                    archive_path = deleted_archive
                    self.write_meta(archive_path, "installed", "true")
                    self.write_meta(archive_path, "uninstalled", "true")

                deleted_plugins = deleted_archives[deleted_archive]
        
                # Update loadorder file
                loadorder_path = os.path.join(self._organizer.profilePath(), "loadorder.txt")
                with open(loadorder_path, "r", encoding="utf-8") as f:
                    load_order_lines = [line.rstrip("\n") for line in f]

                # Update plugins file
                plugins_path = os.path.join(self._organizer.profilePath(), "plugins.txt")
                with open(plugins_path, "r", encoding="utf-8") as f:
                    plugins_lines = [line.rstrip("\n") for line in f]

                for deleted_plugin in deleted_plugins:
                    if deleted_plugin in load_order_lines:
                        load_order_lines.remove(deleted_plugin)
                    if deleted_plugin in plugins_lines:
                        plugins_lines.remove(deleted_plugin)

                # keep only plugins that still exist
                with open(loadorder_path, "w", encoding="utf-8") as f:
                    f.write("\n".join(load_order_lines) + "\n")

                with open(plugins_path, "w", encoding="utf-8") as f:
                    f.write("\n".join(plugins_lines) + "\n")

            self.populate_archives_list()

    def on_archive_download_finished(self, download_id: int):
        try:
            # if self.window.isVisible():
            archive_path = self._organizer.downloadManager().downloadPath(download_id)
            if os.path.exists(archive_path):
                QTimer.singleShot(0, lambda: self.populate_archives_list())
                # self.populate_archives_list()
                if self.auto_install_cb.isChecked():
                    # Prio is the last by default
                    prio = len(self._organizer.modList().allMods())
                    if self.default_separator and self.default_separator_cb.isChecked():
                        mod_list = self._organizer.modList()
                        separators = {}
                        separator_list = []
                        for mod_name in mod_list.allMods():
                            mod = mod_list.getMod(mod_name)
                            if mod and mod.isSeparator():
                                separator_list.append(mod_name)
                                separators[mod_name] = mod_list.priority(mod_name)
                        separator_list.sort(key=lambda p: separators.get(p, 0))
                        if separators[self.default_separator]:
                            next_separator_index = separator_list.index(self.default_separator)+1
                            if next_separator_index < len(separator_list):
                                next_separator = separator_list[next_separator_index]
                                if next_separator: 
                                    prio = separators.get(next_separator)
                    self.auto_install_archives({archive_path:[prio,True]})
                # self.window.raise_()
                # self.window.activateWindow()
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 11: {e}",
            )        

    def meta_exists(self, archive_path):
        if os.path.exists(archive_path + ".meta"):
            return True
        else:
            return False

    def manually_install_archives(self,archives_priority_checked):
        self.start_burning()
        installed_mods = {}
        for archive_path, priority_checked in archives_priority_checked.items():
            mod_name = self.manually_install_archive(archive_path)
            if mod_name:
                installed_mods[mod_name] = priority_checked[0]
                if archive_path in self.dropped_archives:
                    self.dropped_archives.remove(archive_path)
                self.populate_archives_list()
            else:
                break
            
        shift_by = 0
        for mod_name, priority in installed_mods.items():
            self.update_mod_priority(mod_name, priority=priority+shift_by)
            shift_by += 1

        if installed_mods:
            QTimer.singleShot(0, lambda: self.worker.enqueue("refresh", self.worker.refresh))

        self.stop_burning()

    def install_archives(self, type=None, archives=None):
        try:
            downloads_dir = self.downloads_folder_line.text()
            if type == "selected":
                archives = self.get_checked_archives()
            elif type == "all":
                archives = self.get_all_archives()
            elif type == "given" or type == "given_full":
                archives = archives

            if not archives:
                return
            
            archives_paths=[]
            for archive in archives:
                if type != "given_full": 
                    archive_path = os.path.join(downloads_dir, archive)
                    archive_name = archive
                else:
                    archive_path = archive
                    archive_name = os.path.basename(archive)

                for dropped_archive_path in self.dropped_archives:
                    if os.path.basename(dropped_archive_path) == archive_name:
                        archive_path = dropped_archive_path
                        break
                archives_paths.append(archive_path)

            if self.install_method_dialog: self.install_method_dialog.close()
            self.install_method_dialog = InstallMethodDialog(archives=archives_paths, plugin=self)            
            self.install_method_dialog.show()
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 13: {e}",
            )

    def is_fomod(self, archive_path):
        # List files
        result = subprocess.run(
            [SEVEN_ZIP, "l", "-ba", archive_path],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        if result.returncode != 0:
            raise RuntimeError(f"7z error: {result.stderr}")

        files = []
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 6:
                file_path = " ".join(parts[5:])
                files.append(file_path.replace("\\", "/"))
        is_fomod = False
        # If archive contains fomod folder, let MO handle the install
        for f in files:
            parts = f.lower().replace("\\", "/").split("/")
            if "fomod" in parts:
                is_fomod = True
        return is_fomod

    def pre_auto_install_archives(self, archives, exist_action = "ask"):
        self.fomod_list = []
        self.non_fomod_list = []
        self.new_install_order = []

        self.worker.enqueue("find_fomods",self.worker.find_fomods,archives, exist_action)

    def auto_install_archives(self, archives, exist_action = "ask", call = "direct"):
        try:
            # for something in archives.values():
            #     QMessageBox.critical(
            #         None,
            #         "Error",
            #         f"Something: {something}",
            #     )
            # return
            # # If only one archive, set install method to prompt
            # if len(archives) == 1:
            #     self.exist_action = "ask"
            self.exist_action = exist_action
            # Dictionary {archive_path<str> : enable_after_install<True,False>}
            self.archives = archives
            self.install_manually = False
            self.new_order = {}
            if not self.archives:
                return False
            
            if call == "direct":
                self.new_install_order = list(self.archives.keys())

            self.start_burning()
            self.dlg = QtWidgets.QProgressDialog("Installing archives...", "Cancel", 0, 100)
            self.dlg.setWindowModality(Qt.WindowModality.WindowModal)
            self.dlg.setMinimumWidth(400)
            # Force it to stay on top
            self.dlg.setWindowFlags(self.dlg.windowFlags() | Qt.WindowType.WindowStaysOnTopHint)

            self.current_index = 0
            self.cancelled = False

            self.dlg.canceled.connect(self.on_cancel)
            self.worker.taskCanceled.connect(self.on_task_canceled)

            self.dlg.show()
            self.dlg.raise_()  # bring to front
            # Place at top of primary screen
            screen = QtWidgets.QApplication.primaryScreen().availableGeometry()
            x = screen.center().x() - self.dlg.width() // 2
            y = screen.top()
            self.dlg.move(x, y)
            # Start the first
            # direct means that pre install didn't run(FOMODs are not set to install last)
            # thus it needs to be checked if it's FOMOD or not in next step, otherwise skip
            if call == "direct":
                self.pre_process_next(call)
            else:
                self.process_next(call)

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 14: {e}",
            )

    def pre_process_next(self,call):
        if self.current_index >= len(self.archives) or self.cancelled:
            self.dlg.close()
            return
        archive_path = self.new_install_order[self.current_index]
        self.worker.enqueue("is_fomod", self.worker.is_fomod, archive_path, call)

    def random_string(self,length=10):
        import string
        chars = string.ascii_letters + string.digits
        return ''.join(random.choice(chars) for _ in range(length))

    def process_next(self,call,is_fomod=None):
        # Old mod list, before creating new mod, used for comparison
        self.old_mod_list = [mod_name for mod_name in self._organizer.modList().allMods()]  
        self.install_manually = False
        if self.current_index >= len(self.archives) or self.cancelled:
            self.dlg.close()
            return
        downloads_dir = self.downloads_folder_line.text()
        archive_path = self.new_install_order[self.current_index]
        archive_name = os.path.basename(archive_path)
        for dropped_archive_path in self.dropped_archives:
            if os.path.basename(dropped_archive_path) == archive_path:
                archive_path = dropped_archive_path
                break
        if is_fomod == None:
            is_fomod = True if archive_path in self.fomod_list else False
        # Updating install progress dialog
        percent = int((self.current_index / len(self.archives)) * 100)
        self.dlg.setLabelText(f"Installed [{self.current_index}/{len(self.archives)}]\n" +
                              f"Installing: {os.path.basename(archive_path)}")
        self.dlg.setValue(percent)
        
        self.mod_names = self.get_mod_names(archive_path)
        
        if not self.mod_names:
            mod_basename = self.read_meta(archive_path, "modname")
            mod_extension = self.read_meta(archive_path, "name")
            mod_name = None
            if mod_basename:
                mod_name = mod_basename
                # If extension is the same name or is included 
                # in the basename/mod page name, it's likely a main file
                if (mod_extension
                    and mod_extension.lower() != mod_basename.lower()
                    and not mod_extension.lower() in mod_basename.lower()): 
                    mod_name += " - " + mod_extension
            elif mod_extension:
                mod_name = mod_extension
            if not mod_name:
                # This is basically the same as 'name' field inside archive's .meta
                mod_name = (
                    self.extract_mod_name(os.path.basename(archive_path))
                    or os.path.basename(archive_path).rsplit(".",1)[0]
                )
            full_mod_name = self.mod_prefix_field.text() + mod_name + self.mod_suffix_field.text()
            # Limit mod name to 200 characters, which is the limit (maybe?) for MO to work properly
            # Windows's limit is 225 characters for folders, so that's an absolute limit
            if len(full_mod_name) > 200:
                # Strip mod name instead of prefix and suffix, by the length of those two
                modified_mod_length = 200 - len(self.mod_prefix_field.text()) - len(self.mod_suffix_field.text())
                modified_mod_name = mod_name[:modified_mod_length]
                full_mod_name = self.mod_prefix_field.text() + modified_mod_name + self.mod_suffix_field.text()

            
            # 1. Remove invalid Windows characters everywhere
            full_mod_name = re.sub(r'[<>:"/\\|?*]', '', full_mod_name)
            # 2. Remove dots (and spaces) only from start and end
            full_mod_name = full_mod_name.strip(' .')

            WINDOWS_RESERVED = {
                "CON","PRN","AUX","NUL",
                *(f"COM{i}" for i in range(1, 10)),
                *(f"LPT{i}" for i in range(1, 10)),
            }
            # Handle reserved names
            if full_mod_name.upper() in WINDOWS_RESERVED:
                full_mod_name = "_" + full_mod_name
            
            if is_fomod:
                mod_exists = True if self.mod_names else False
                result = self._organizer.installMod(archive_path, full_mod_name)
                if result:
                    # Reretrieving fomod object since the above
                    # is bugged and doesn't return valid object
                    mod_list = self._organizer.modList()
                    new_mod_name = set(mod_list.allMods()) - set(self.old_mod_list)
                    # Not needed since MO installation handles this
                    # self.populate_ini(archive_path, mod_path)
                    if archive_path in self.dropped_archives:
                        self.dropped_archives.remove(archive_path)
                    self.populate_archives_list()
                    self.current_index += 1
                    # Change mod_exists to False in case the user choose to rename 
                    # and install as a new mod instead of replacing/merging
                    if new_mod_name:
                        new_mod_name = list(new_mod_name)[0]
                        mod_exists = False
                        # New order: {mod_name<str> : priority<int>,enabled<bool>,mod_exists<bool>}
                        self.new_order[new_mod_name] = self.archives.get(archive_path) + [mod_exists] + [archive_path]
                    if not self.cancelled and self.current_index < len(self.archives):
                        # QtWidgets.QApplication.processEvents()
                        if call == "direct":
                            QTimer.singleShot(0, lambda: self.pre_process_next(call))
                        else:
                            QTimer.singleShot(0, lambda: self.process_next(call))
                    else:
                        self.dlg.canceled.disconnect(self.on_cancel)
                        self.dlg.close()
                        self.dlg.canceled.connect(self.on_cancel)
                        self.stop_burning()
                        self.reorder_modlist(self.new_order)
                        # Fixes invalid origin name, that occurs when
                        # rest of the code runs while MO hasn't yet finished
                        # install process of a mod/fomod, this basically waits
                        # for MO to do it's job before rest of the code runs 
                        QTimer.singleShot(0, lambda: self.worker.enqueue("refresh", self.worker.refresh))
                        # self.worker.enqueue("refresh", self.worker.refresh)
                else:
                    try:
                        self.dlg.canceled.disconnect(self.on_cancel)
                        self.dlg.close()
                        self.dlg.canceled.connect(self.on_cancel)
                        self.stop_burning()
                        # Refresh and update install order only if there were 
                        # mods installed prior to FOMOD being cancelled
                        if len(self.archives) > 1 and self.current_index != 0:
                            self.reorder_modlist(self.new_order)
                            QTimer.singleShot(0, lambda: self.worker.enqueue("refresh", self.worker.refresh))
                        
                    except Exception as e:
                        QMessageBox.critical(
                            None,
                            "Error",
                            f"process_next FOMOD cancel failed: {e}",
                        )
            else:
                ###OONGA
                # Will trigger installation window if the mod with the same name exist
                # Need to fix it if users select 'Replace' or 'Merge' for mods
                if self.exist_action=="ask":
                    mod = self._organizer.createMod(full_mod_name)
                    if mod:
                        # mod_list = self._organizer.modList()
                        # mod_list.setPriority(mod.name(), self.archives.get(archive_path)[0])
                        # self.extract_archive(archive_path,mod.absolutePath(),call=call)
                        # Add mod name since it's not in mod_names even though
                        # it's installing same mod, so reorder can work
                        # Else user renamed so it's fine
                        new_mod_name = os.path.basename(mod.absolutePath())
                        self.mod_names = [new_mod_name]
                            
                        self.worker.enqueue("extract", self.worker.extract_archive, archive_path, 
                            mod.absolutePath(), call=call, exist_action=self.exist_action)
                        # else:
                        #     self.worker.enqueue("extract", self.worker.extract_archive, archive_path, 
                        #         mod.absolutePath(), call=call, exist_action=self.exist_action)
                            
                    else:
                        # QMessageBox.critical(
                        #     None,
                        #     "Error0",
                        #     f"Mod creation failed.",
                        # )
                        self.dlg.close()
                else:
                    ###OONGA
                    mod_path = os.path.join(self.mods_path, full_mod_name)
                    # Add mod name since it's not in mod_names even though
                    # it's installing existing mod, so reorder can work
                    if os.path.exists(mod_path) and not self.mod_names:
                        self.mod_names = [full_mod_name]
                    self.worker.enqueue("extract", self.worker.extract_archive, archive_path, 
                        mod_path, call=call, exist_action=self.exist_action)   

        else:
            dlg = CheckboxPopup(self.mod_names, archive_path, plugin=self)
            if len(self.mod_names) > 1:
                # Selected
                if dlg.exec():
                    self.mod_names = dlg.get_selected()
                # Canceled
                else:
                    self.dlg.close()
                    return
            
            for mod_name in self.mod_names:
                if is_fomod:
                    mod_exists = True if self.mod_names else False
                    result = self._organizer.installMod(archive_path, mod_name)
                    if result:
                        # Reretrieving fomod object since the above
                        # is bugged and doesn't return valid object
                        mod_list = self._organizer.modList()
                        new_mod_name = set(mod_list.allMods()) - set(self.old_mod_list)
                        # Not needed since MO installation handles this
                        # self.populate_ini(archive_path, mod_path)
                        if archive_path in self.dropped_archives:
                            self.dropped_archives.remove(archive_path)
                        self.populate_archives_list()
                        self.current_index += 1
                        # Change mod_exists to False in case the user choose to rename 
                        # and install as a new mod instead of replacing/merging
                        if new_mod_name:
                            new_mod_name = list(new_mod_name)[0]
                            mod_exists = False
                            # New order: {mod_name<str> : priority<int>,enabled<bool>,mod_exists<bool>}
                            self.new_order[new_mod_name] = self.archives.get(archive_path) + [mod_exists] + [archive_path]
                        if not self.cancelled and self.current_index < len(self.archives):
                            # QtWidgets.QApplication.processEvents()
                            if call == "direct":
                                QTimer.singleShot(0, lambda: self.pre_process_next(call))
                            else:
                                QTimer.singleShot(0, lambda: self.process_next(call))
                        else:
                            self.dlg.canceled.disconnect(self.on_cancel)
                            self.dlg.close()
                            self.dlg.canceled.connect(self.on_cancel)
                            self.stop_burning()
                            self.reorder_modlist(self.new_order)
                            # Fixes invalid origin name, that occurs when
                            # rest of the code runs while MO hasn't yet finished
                            # install process of a mod/fomod, this basically waits
                            # for MO to do it's job before rest of the code runs 
                            QTimer.singleShot(0, lambda: self.worker.enqueue("refresh", self.worker.refresh))
                            # self.worker.enqueue("refresh", self.worker.refresh)

                    else:
                        try:
                            self.dlg.canceled.disconnect(self.on_cancel)
                            self.dlg.close()
                            self.dlg.canceled.connect(self.on_cancel)
                            self.stop_burning()
                            # Refresh and update install order only if there were 
                            # mods installed prior to FOMOD being cancelled
                            if len(self.archives) > 1 and self.current_index != 0:
                                self.reorder_modlist(self.new_order)
                                QTimer.singleShot(0, lambda: self.worker.enqueue("refresh", self.worker.refresh))
                            
                        except Exception as e:
                            QMessageBox.critical(
                                None,
                                "Error",
                                f"Exception 16: {e}",
                            )
                else:
                    if self.exist_action == EXIST_ACTION[2]: # ask whether to replace/merge
                        mod = self._organizer.createMod(mod_name)
                        if mod:
                            # self.extract_archive(archive_path,mod.absolutePath(),call=call)
                            self.worker.enqueue("extract", self.worker.extract_archive, archive_path, mod.absolutePath(), call=call)
                        else:
                            # If it gets canceled
                            self.on_cancel()
                    elif self.exist_action == EXIST_ACTION[1]: # replace
                        mod_list = self._organizer.modList()
                        mod = mod_list.getMod(mod_name)
                        if mod:
                            # mod_list.removeMod(mod)
                            if os.path.exists(mod.absolutePath()):
                                shutil.rmtree(mod.absolutePath())
                        else:
                            # This will likely always get called since creating manually
                            # doesn't add mods to the MO list, at least not right away
                            mod_path = os.path.join(self.mods_path,mod_name)
                            if os.path.exists(mod_path):
                                shutil.rmtree(mod_path)

                        mod = self._organizer.createMod(mod_name)
                        if mod:
                            # self.extract_archive(archive_path,mod.absolutePath(),call=call)
                            self.worker.enqueue("extract", self.worker.extract_archive, archive_path, mod.absolutePath(), call=call)
                        else:
                            # This shouldn't ever be called since there
                            # won't ever be prompt in the first place
                            # but just in case
                            QMessageBox.critical(
                                None,
                                "Error1",
                                f"This prompt shouldn't be showing.",
                            )
                            self.dlg.close()
                    elif self.exist_action == EXIST_ACTION[0]: # merge
                        mod_path = os.path.join(self.mods_path, mod_name)
                        # self.extract_archive(archive_path,mod.absolutePath(),call=call)
                        self.worker.enqueue("extract", self.worker.extract_archive, archive_path, mod_path, call=call)
                    else:
                        self.dlg.close()
                        return

    def on_cancel(self):
        # This is being triggered on Cancel button
        # as well as self.dlg.close() method
        self.cancelled = True
        self.stop_burning()
        self.dlg.setLabelText("Closing...")
        self.dlg.close()
        # Update only if there was at least one mod installed
        if self.current_index != 0:
            self.populate_archives_list()
            self.reorder_modlist(self.new_order)
            self.worker.enqueue("refresh", self.worker.refresh)

    def on_task_canceled(self, archive_path, mod_path):
        self.install_manually = True

    def longpath(self, p):
        p = os.path.abspath(os.path.normpath(p))
        if p.startswith("\\\\?\\"):
            return p
        if p.startswith("\\\\"):
            return "\\\\?\\UNC\\" + p[2:]
        return "\\\\?\\" + p

    def on_task_finished(self, task_type, result, success, error_msg):
        try:
            if task_type == "is_fomod" and success:
                archive_path, is_fomod, call = result
                self.process_next(call,is_fomod=is_fomod)
            elif task_type == "find_fomods" and success:
                archives, exist_action = result
                self.auto_install_archives(archives,exist_action,call="pre-install")
            elif task_type == "extract" and success:
                archive_path, mod_path, call = result
                # New order: {mod_name<str> : priority<int>,enabled<bool>,mod_exists<bool>}
                mod_exists = True if self.mod_names else False
                self.new_order[os.path.basename(mod_path)] = self.archives.get(archive_path) + [mod_exists] + [archive_path]
                self.populate_ini(archive_path, mod_path)
                if archive_path in self.dropped_archives:
                    self.dropped_archives.remove(archive_path)
                self.populate_archives_list()
                self.current_index += 1
                if not self.cancelled and self.current_index < len(self.archives):
                    # QtWidgets.QApplication.processEvents()
                    if call == "direct":
                        QTimer.singleShot(0, lambda: self.pre_process_next(call))
                    else:
                        QTimer.singleShot(0, lambda: self.process_next(call))
                else:
                    self.dlg.canceled.disconnect(self.on_cancel)
                    self.dlg.close()
                    self.dlg.canceled.connect(self.on_cancel)
                    self.stop_burning()
                    self.reorder_modlist(self.new_order)
                    QTimer.singleShot(0, lambda: self.worker.enqueue("refresh", self.worker.refresh))
                        
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"on_task_finished Exception: {e}",
            )

    def fetch_current_plugins(self):
        current_plugins = []
        for mod_name in os.listdir(self.mods_path):
            mod_path = os.path.join(self.mods_path, mod_name)
            if not os.path.isdir(mod_path):
                continue  # skip files

            # collect all plugins as a set directly
            mod_plugins = {
                f for f in os.listdir(mod_path)
                if f.endswith((".esp", ".esl", ".esm"))
            }

            current_plugins.extend(mod_plugins)

        return current_plugins

    def safe_write(self, path, data, retries=50, delay=0.1):
        """Retry writing a file in case MO2 has it locked."""
        for _ in range(retries):
            try:
                with open(path, "w", encoding="utf-8") as f:
                    f.write("\n".join(data) + "\n")
                return
            except PermissionError:
                time.sleep(delay)
        raise RuntimeError(f"Could not write to {path}: still locked.")

    def reorder_modlist(self, new_order):
        """
        Reorders the first n mods in modlist.txt based on new_order.

        :param modlist_path: Path to modlist.txt
        :param new_order: Dictionary of mod name key and list value [priority, checked]
        """
        try:
            modlist_path = os.path.join(self._organizer.profilePath(),"modlist.txt")
            modlist_backup_path = os.path.join(self._organizer.profilePath(),"umi-backup","modlist.txt")
            if not os.path.exists(modlist_backup_path):
                os.makedirs(os.path.join(self._organizer.profilePath(),"umi-backup"),exist_ok=True)
                shutil.copy(modlist_path, modlist_backup_path)

            loadorder_path = os.path.join(self._organizer.profilePath(),"loadorder.txt")
            loadorder_backup_path = os.path.join(self._organizer.profilePath(),"umi-backup","loadorder.txt")
            if not os.path.exists(loadorder_backup_path):
                os.makedirs(os.path.join(self._organizer.profilePath(),"umi-backup"),exist_ok=True)
                shutil.copy(loadorder_path, loadorder_backup_path)

            plugins_path = os.path.join(self._organizer.profilePath(),"plugins.txt")
            plugins_backup_path = os.path.join(self._organizer.profilePath(),"umi-backup","plugins.txt")
            if not os.path.exists(plugins_backup_path):
                os.makedirs(os.path.join(self._organizer.profilePath(),"umi-backup"),exist_ok=True)
                shutil.copy(plugins_path, plugins_backup_path)

            bsa_path = os.path.join(self._organizer.profilePath(),"archives.txt")
            bsa_backup_path = os.path.join(self._organizer.profilePath(),"umi-backup","archives.txt")
            if not os.path.exists(bsa_backup_path):
                os.makedirs(os.path.join(self._organizer.profilePath(),"umi-backup"),exist_ok=True)
                shutil.copy(bsa_path, bsa_backup_path)

            locked_order_path = os.path.join(self._organizer.profilePath(),"lockedorder.txt")
            locked_order_backup_path = os.path.join(self._organizer.profilePath(),"umi-backup","lockedorder.txt")
            if not os.path.exists(locked_order_backup_path):
                os.makedirs(os.path.join(self._organizer.profilePath(),"umi-backup"),exist_ok=True)
                shutil.copy(locked_order_path, locked_order_backup_path)

            with open(modlist_path, "r", encoding="utf-8") as f:
                lines = [line.rstrip("\n") for line in f]

            n = len(new_order)
            comment_line = lines[0] if lines[0].startswith("#") else None
            if comment_line: lines.pop(0)
            # Strip leading '-' for comparison
            clean_lines = [line.lstrip("-") for line in lines[:n]]

            # Map mod name -> line index for quick lookup
            line_map = {} 
            for i, line in enumerate(lines):
                modname = line.lstrip("+-")
                line_map[modname] = line

            # Figuring out how many mods from the installation
            # are at the top, which would mean they are likely
            # new mods and it's fine to change their install order
            # Though keep in mind that the existing mods at the top
            # will also have thier order changed
            # added_count = 0
            # for i in range(0,n):
            #     new = False
            #     for mod in new_order.keys():
            #         line = line_map.get(mod)
            #         if line and lines.index(line) == i:
            #             added_count += 1
            #             new = True
            #             break
            #     if not new:
            #         break
                
            # File order is reversed (0 = lowest prio), so compute actual insertion index
            def file_index_from_priority(priority, total_lines):
                return total_lines - priority
            
            reverted_order = list(new_order.keys())
            if self.install_fomods_last:
                archives = list(self.archives.keys())
                archives_indexed = {a: i for i, a in enumerate(archives)}
                max_index = len(archives_indexed)

                # Sort new_order by archive index (4th element in each value)
                sorted_items = sorted(
                    new_order.items(),
                    key=lambda item: archives_indexed.get(item[1][3], max_index)
                )
                # Create a new list or dict (depending on what you need)
                reverted_order = [mod for mod, _ in sorted_items]

            # shift_by_dict = {}
            # for i in range(1, len(reverted_order)):
            #     shift_by = 0
            #     mod = reverted_order[i]
            #     prio = new_order.get(mod)[0]
            #     for j in range(0, i):
            #         prio1 = new_order.get(reverted_order[j])[0]
            #         if prio1 <= prio:
            #             shift_by += 1
            #     shift_by_dict[mod] = shift_by
            
            reordered_block = []
            reordered_plugins = {}
            # Already did this in when fetching archives for installation
            shift_by = 0
            for mod in reverted_order:
                others_list = new_order.get(mod)
                priority = others_list[0]
                enabled = others_list[1]
                mod_exists = others_list[2]
                prefix = "+" if enabled else "-"
                new_line = prefix + mod
                old_line = line_map.get(mod)

                if mod_exists and old_line:
                    old_idx = lines.index(old_line)
                    # if old_idx < added_count:
                    #     lines.remove(old_line)
                    #     lines.insert(0, new_line)
                    #     # This works because mods are already
                    #     # ordered from lower to higher prio
                    #     shift_by += 1
                    # else:
                    lines[old_idx] = new_line
                else:
                    if old_line: lines.remove(old_line)
                    insert_idx = file_index_from_priority(priority, len(lines))
                    # Brand new mod - insert directly
                    # shift_by = shift_by_dict.get(mod)
                    # if shift_by:
                    insert_idx = max(0, insert_idx - shift_by)
                    # else:
                        # insert_idx = max(0, insert_idx)
                    lines.insert(insert_idx, new_line)
                    # This works because mods are already
                    # ordered from lower to higher prio
                    shift_by += 1

                mod_plugins = []
                for mod_file in os.listdir(os.path.join(self.mods_path, mod)):
                    if (mod_file.endswith(".esp") or 
                        mod_file.endswith(".esl") or 
                        mod_file.endswith(".esm")):
                        # Do not add if another mods adds the same plugin
                        if not mod_file in mod_plugins:
                            if any(mod_file in plugin_list for plugin_list in reordered_plugins.values()):
                                continue
                            mod_plugins.append(mod_file)
                # Ordering plugin files by their basename
                plugins_priority = {}
                for plugin in mod_plugins:
                    priority_count = 0
                    for plugin1 in mod_plugins:
                        # Remove file extension
                        plugin1_stripped = plugin1.rstrip(plugin1[len(plugin1)-4:])
                        if plugin1 != plugin and plugin1_stripped in plugin:
                            priority_count += 1
                    plugins_priority[plugin] = priority_count

                mod_plugins.sort(key=lambda p: plugins_priority.get(p, 0))
                reordered_plugins[mod] = mod_plugins

            # Insert new mods at the top
            lines = reordered_block + lines
            if comment_line:
                lines = [comment_line] + lines
            # Write back
            self.safe_write(modlist_path,lines)
            # with open(modlist_path, "w", encoding="utf-8") as f:
            #     f.write("\n".join(lines) + "\n")


            # Update load order
            with open(loadorder_path, "r", encoding="utf-8") as f:
                load_order_lines = [line.rstrip("\n") for line in f]

            line_map = {} 
            for i, line in enumerate(load_order_lines):
                line_map[line] = i

            reordered_plugins_new = []
            for mod, plugins in reordered_plugins.items():
                for plugin_name in plugins:
                    if plugin_name in line_map:
                        continue
                    else:
                        reordered_plugins_new.append(plugin_name)

            load_order_lines = load_order_lines + reordered_plugins_new
            self.safe_write(loadorder_path,load_order_lines)
            # with open(loadorder_path, "w", encoding="utf-8") as f:
            #     f.write("\n".join(load_order_lines) + "\n")

            # Update plugins states
            with open(plugins_path, "r", encoding="utf-8") as f:
                plugins_lines = [line.rstrip("\n") for line in f]

            line_map = {} 
            for i, line in enumerate(plugins_lines):
                plugin_name = line.lstrip("*")
                line_map[plugin_name] = i

            reordered_plugins_prefixed = []
            for mod, plugins in reordered_plugins.items():
                for plugin_name in plugins:
                    if plugin_name in line_map:
                        og_idx = line_map[plugin_name]
                        prefix = "*" if new_order.get(mod) else ""
                        plugins_lines[og_idx] = prefix + plugin_name
                    else:
                        prefix = "*" if new_order.get(mod) else ""
                        plugin_name_prefixed = prefix + plugin_name
                        if plugin_name_prefixed not in reordered_plugins_prefixed:
                            reordered_plugins_prefixed.append(plugin_name_prefixed)

            plugins_lines = plugins_lines + reordered_plugins_prefixed
            self.safe_write(plugins_path,plugins_lines)
            # with open(plugins_path, "w", encoding="utf-8") as f:
            #     f.write("\n".join(plugins_lines) + "\n")

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Reorder modlist exception: {e}",
            )
    
    def extract_mod_id(self,archive_string):
        """
        Extracts the mod ID from a string of format <mod_name>-<mod_id>-
        where <mod_id> is 1-6 digits.
        """
        match = re.search(r"-(\d{1,6})-", archive_string)
        if match:
            return int(match.group(1))
        return None
        
    def extract_mod_name(self,archive_string):
        """
        Extract the mod name (everything before -<mod_id>- where <mod_id> is 1-6 digits)
        """
        match = re.match(r"^(.*?)-\d{1,6}-", archive_string)
        if match:
            return match.group(1)
        return None
        
    def get_mod_names(self,archive_path):
        try:
            found_mod_names = {}
            modID = None

            if os.path.dirname(archive_path) == self.downloads_path:
                archive_basename = os.path.basename(archive_path)
            else:
                # If archive is not in MO Downloads folder use full archive path
                archive_basename = archive_path

            if self.meta_exists(archive_path):
                # Extract modID from .meta file if exists
                modID = self.read_meta(archive_path, "modid")
            else:
                # Extract modID from archive name (less reliable but should work in most cases)
                modID = self.extract_mod_id(archive_basename)
            
            mod_list = self._organizer.modList()
            for mod_name in mod_list.allMods():
                mod = mod_list.getMod(mod_name)
                if mod:
                    if mod.installationFile() == archive_basename:
                        found_mod_names[mod.name()] = "installation_file"
            
            if not found_mod_names:
                for mod_name in os.listdir(self.mods_path):
                    mod_path = os.path.join(self.mods_path,mod_name)
                    if os.path.isdir(mod_path):
                        ini_path = os.path.join(mod_path, "meta.ini")
                        if os.path.exists(ini_path):
                            # PRIORITY ORDER
                            # Exact installation file > Similar installation file + Nexus ID > Nexus ID
                            found = False
                            meta_ini = self.read_ini(ini_path)
                            if meta_ini:
                                # Same archive used, should be same mod
                                installation_file = meta_ini.get("installationfile")
                                if installation_file:
                                    # Check if another mod was installed using the same archive, if so
                                    # use that mod's name as default name when installing
                                    # Also compare archive's name splitted, before -123-, to check if it's
                                    # actually the same mod file, just different version, should be reliable
                                    extracted_name = self.extract_mod_name(installation_file)
                                    extracted_name1 = self.extract_mod_name(archive_basename)
                                    if (installation_file == archive_basename or (extracted_name and extracted_name1 and
                                    extracted_name.lower() == extracted_name1.lower())):
                                        found_mod_names[mod_name] = "installation_file"
                                        found = True

                                # Same mod page, maybe same mods with similar archives (different versions?)
                                nexus_id = meta_ini.get("modid")
                                if (not found and installation_file and nexus_id and modID and modID != "None" and
                                    self.extract_mod_name(archive_basename) == self.extract_mod_name(installation_file) and
                                    modID == nexus_id):
                                    found_mod_names[mod_name] = "similar_installation_file"
                                    found = True

                                # DON'T WANT TO UPDATE MODS IF THEY ARE ONLY FROM THE SAME
                                # MOD PAGE BUT DON'T HAVE THE SAME INSTALLATIONS
                                # # Same mod page, different mods/archives
                                # if (not found and nexus_id and 
                                #     self.extract_mod_id(archive_basename) == nexus_id):
                                #     # Using same modName but adding extension, maybe if a patch
                                #     mod_basename = meta_ini.get("modname")
                                #     mod_extension = self.extract_mod_name(archive_basename)
            return found_mod_names
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 18: {e}",
            )
    
    def generate_meta(self, archive_path):
        meta_path = archive_path + ".meta"
        archive_name = os.path.basename(archive_path)
        with open(meta_path, "w", encoding="utf-8") as f:
            f.write(f"[General]\n")
            f.write(f"gameName=skyrimse\n")
            f.write(f"modID={self.extract_mod_id(archive_name)}\n")
            f.write(f"installed=false\n")
            f.write(f"removed=false\n")

    def write_meta(self, archive_path, key, value):
        try:
            meta_path = archive_path + ".meta"
            if not os.path.exists(meta_path): 
                self.generate_meta(archive_path)

            # Read raw bytes
            with open(meta_path, "rb") as f:
                raw = f.read()

            try:
                # Try best-effort decode (ANSI fallback)
                text = raw.decode("utf-8")
            except UnicodeDecodeError:
                text = raw.decode("cp1252", errors="ignore")

            lines = text.splitlines(keepends=True)
            updated = False

            for i, line in enumerate(lines):
                if "=" in line:
                    k, _ = line.split("=", 1)
                    if k.strip() == key:  # match regardless of spaces
                        lines[i] = f"{key}={value}\n"
                        updated = True
                        break

            if not updated:
                # Make sure [General] exists
                if not any(l.strip().startswith("[General]") for l in lines):
                    lines.insert(0, "[General]\n")
                lines.append(f"{key}={value}\n")

            # Write back in ANSI (same as MO2 normally uses)
            new_text = "".join(lines)
            with open(meta_path, "wb") as f:
                f.write(new_text.encode("cp1252", errors="replace"))
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 19: {e}",
            )
        
    def write_ini(self, ini_path, key, value, section="General"):
        """
        Update or insert a key in a meta.ini file.
        Defaults to [General] section unless otherwise specified.
        """
        try:
            config = configparser.ConfigParser()
            config.optionxform = str  # preserve case of keys

            if os.path.exists(ini_path):
                config.read(ini_path, encoding="utf-8")

            if section not in config:
                config[section] = {}

            config[section][key] = str(value)

            with open(ini_path, "w", encoding="utf-8") as f:
                config.write(f)

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 20: {e}",
            )
    
    def read_ini_field(self, ini_path, key, section="General", fallback = None):
        """
        Update or insert a key in a meta.ini file.
        Defaults to [General] section unless otherwise specified.
        """
        try:
            # TRY BELOW IF BUGGING
            # config = configparser.RawConfigParser(strict=False)
            # config.optionxform = str  # keep case
            config = configparser.ConfigParser(interpolation=None)
            config.read(ini_path, encoding='utf-8')

            if not config.has_section(section):
                return fallback

            # Normalize key for fuzzy match
            key_lower = key.strip().lower()
            for k in config[section]:
                if k.strip().lower() == key_lower:
                    return config[section][k]
            return fallback

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 21: {e}",
            )

    def read_ini(self, ini_path, section="General", fallback=None):
        try:
            # TRY BELOW IF BUGGING
            # config = configparser.RawConfigParser(strict=False)
            # config.optionxform = str  # keep case
            config = configparser.ConfigParser(interpolation=None)
            config.read(ini_path, encoding="utf-8")

            if not config.has_section(section):
                return fallback

            result = {}
            for k, v in config[section].items():
                result[k.strip().lower()] = v
            return result

        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 22: {e}",
            )
            return fallback

    def populate_ini(self, archive_path, mod_path):
        try:
            # Populating meta.ini file
            mod_id = None
            game_name = None
            nexus_category = None
            version = None
            installation_file = None
            if self.meta_exists(archive_path):
                mod_id = self.read_meta(archive_path, "modid")
                game_name = self.read_meta(archive_path, "gameName")
                nexus_category = self.read_meta(archive_path, "category")
                version = self.read_meta(archive_path, "version")
            else:
                mod_id = self.extract_mod_id(archive_path)
            ini_path = os.path.join(mod_path,"meta.ini")
            if game_name != None:
                self.write_ini(ini_path, "gameName", game_name)
            if mod_id != None:
                self.write_ini(ini_path, "modid", mod_id)
            if version != None:
                self.write_ini(ini_path, "version", version)
            if os.path.dirname(archive_path) == self.downloads_path:
                installation_file = os.path.basename(archive_path)
            else:
                installation_file = archive_path
            self.write_ini(ini_path, "installationFile", installation_file)
            
            if nexus_category != None:
                self.write_ini(ini_path, "nexusCategory", nexus_category)
            # Update archive .meta
            self.write_meta(archive_path, "installed", "true")
            self.write_meta(archive_path, "uninstalled", "false")
            
            self.generate_archive_backup(installation_file, os.path.basename(mod_path))
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 23: {e}",
            )

    def update_mod_priority(self, name, priority=None):
        try:
            if name:
                mod_list = self._organizer.modList()
                if priority:
                    mod_list.setPriority(name,priority)
                else:
                    if self.default_separator and self.default_separator_cb.isChecked():
                        separators = {}
                        separator_list = []
                        for mod_name in mod_list.allMods():
                            mod = mod_list.getMod(mod_name)
                            if mod and mod.isSeparator():
                                separator_list.append(mod_name)
                                separators[mod_name] = mod_list.priority(mod_name)
                        separator_list.sort(key=lambda p: separators.get(p, 0))
                        if separators[self.default_separator]:
                            next_separator_index = separator_list.index(self.default_separator)+1
                            # Also ignore the last one since that's the default behavior
                            if next_separator_index < len(separator_list):
                                next_separator = separator_list[next_separator_index]
                                if next_separator: 
                                    mod_list.setPriority(name, separators.get(next_separator))
                                    # self.worker.enqueue("refresh", self.worker.refresh)
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 35: {e}",
            )

    def manually_install_archive(self, archive_path):
        try:
            self.old_mod_list = [mod_name for mod_name in self._organizer.modList().allMods()]  
            mod_basename = self.read_meta(archive_path, "modname")
            mod_extension = self.read_meta(archive_path, "name")
            mod_name = None
            if mod_basename:
                mod_name = mod_basename
                # If extension is the same name or is included 
                # in the basename/mod page name, it's likely a main file
                if (mod_extension
                    and mod_extension != mod_basename
                    and not mod_extension in mod_basename): 
                    mod_name += " - " + mod_extension
            elif mod_extension:
                mod_name = mod_extension
            if not mod_name:
                # This is basically the same as 'name' field inside archive's .meta
                mod_name = (
                    self.extract_mod_name(os.path.basename(archive_path))
                    or os.path.basename(archive_path).rsplit(".",1)[0]
                )
            result = self._organizer.installMod(archive_path, self.mod_prefix_field.text() + mod_name + self.mod_suffix_field.text())
            if result:
                # Reretrieving mod object since the above is
                # bugged(I think?) and doesn't return valid object
                mod_list = self._organizer.modList()
                mod_found = None
                for name in mod_list.allMods():
                    mod = mod_list.getMod(name)
                    if mod == result:
                        mod_found = mod
                    elif (not mod_found
                        and (mod.installationFile() == os.path.basename(archive_path)
                            or mod.installationFile() == archive_path)
                        and not mod.name() in self.old_mod_list):
                        mod_found = mod
                if mod_found:
                    self.generate_archive_backup(archive_path, mod_found.name())
                    return mod_found.name()
            else:
                return None
        except Exception as e:
            QMessageBox.critical(
                None,
                "Error",
                f"Exception 45: {e}",
            )

    def merge_folders_no_overwrite(self, src, dst):
        """Recursively merge src folder into dst."""
        if not os.path.exists(dst):
            print(f"Creating new root folder: {dst}")
            shutil.move(src, dst)
            return

        for item in os.listdir(src):
            s = os.path.join(src, item)
            d = os.path.join(dst, item)
            if os.path.isdir(s):
                self.merge_folders_no_overwrite(s, d)
            else:
                print(f"Moving file: {s} -> {d} skip if exists")
                if os.path.exists(d):
                    continue
                shutil.move(s, d)

            #os.rmdir(src)


    def move_temp_no_overwrite(self, temp_dir, dest_dir, remove_source=True):
        """
        Moves all files and folders from temp_dir into dest_dir,
        skipping files that already exist in dest_dir.
        Then removes temp_dir if empty.
        """
        if not os.path.exists(temp_dir):
            return

        os.makedirs(dest_dir, exist_ok=True)

        for item in os.listdir(temp_dir):
            src_path = os.path.join(temp_dir, item)
            dst_path = os.path.join(dest_dir, item)

            if os.path.exists(dst_path):
                if os.path.isdir(dst_path) and os.path.isdir(src_path):
                    print(f"Merging folder: {src_path} -> {dst_path}")
                    self.merge_folders_no_overwrite(src_path, dst_path)
                else:
                    print(f"Skipping file: {src_path} -> {dst_path}")
                    # Don’t delete src, just leave it in temp
                    continue
            else:
                print(f"Moving: {src_path} -> {dst_path}")
                # Skip moving if it's meta.ini, since it'll always
                # get generated by new installation
                # if item == "meta.ini":
                #     continue
                shutil.move(src_path, dst_path)

        # Try to remove temp_dir
        try:
            if os.path.isdir(temp_dir):# and remove_source:
                shutil.rmtree(temp_dir)
        except Exception as e:
            print(f"Warning: could not remove {temp_dir}: {e}")

         
class TaskWorker(QObject):
    # Emits: task_type, result, success_flag, error_message
    taskFinished = pyqtSignal(str, object, bool, str)
    taskProgress = pyqtSignal(str, int, str)  # task_type, percent, message
    taskCanceled = pyqtSignal(str, str)

    def __init__(self, sevenz_path, organizer=None, plugin=None, parent=None):
        super().__init__(parent)
        self.plugin = plugin
        self.sevenz_path = sevenz_path
        self._organizer = organizer
        self._queue = queue.Queue()
        self._thread = QThread()
        self.moveToThread(self._thread)
        self._thread.started.connect(self._process_queue)
        self._running = False
        self._cancel = False

    def start(self):
        if not self._running:
            self._running = True
            self._thread.start()

    def stop(self):
        self._running = False
        self._thread.quit()
        self._thread.wait()

    def enqueue(self, task_type, func, *args, **kwargs):
        """
        Add a job to the worker queue.

        task_type: str (e.g. "extract", "refresh")
        func: callable (function/method to run)
        args/kwargs: passed to func
        """
        self._queue.put((task_type, func, args, kwargs))

    def _process_queue(self):
        while self._running:
            try:
                task_type, func, args, kwargs = self._queue.get(timeout=0.1)
            except queue.Empty:
                continue

            success = False
            error_msg = ""
            result = None
            try:
                result = func(*args, **kwargs)
                success = True
            except Exception as e:
                error_msg = str(e)

            self.taskFinished.emit(task_type, result, success, error_msg)
            self._queue.task_done()

    def longpath(self, p):
        p = os.path.abspath(p)
        if p.startswith("\\\\?\\"):
            return p
        if p.startswith("\\\\"):
            return "\\\\?\\UNC\\" + p[2:]
        return "\\\\?\\" + p

    def extract_archive(self, archive_path, extract_path, call="direct", exist_action="ask"):
        ###OONGA
        # Delete the content of the mod if user selected Replace previously
        if os.path.exists(extract_path) and exist_action =="replace":
            # shutil.rmtree(extract_path)
            for filename in os.listdir(extract_path):
                if filename=="meta.ini":
                    continue
                
                file_path = os.path.join(extract_path, filename)
                try:
                    if os.path.isfile(file_path) or os.path.islink(file_path):
                        os.unlink(file_path)  # remove file or symlink
                    elif os.path.isdir(file_path):
                        shutil.rmtree(file_path)  # remove subdirectory
                except Exception as e:
                    print(f"Faild to delete {file_path}")
        
        temp_dir = os.path.join(extract_path, "_temp")
        if os.path.exists(temp_dir): shutil.rmtree(temp_dir)
        os.makedirs(temp_dir, exist_ok=True)
        args = [SEVEN_ZIP, "x", "-y", archive_path, f"-o{temp_dir}"]

        process = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        if process.returncode != 0:
            raise RuntimeError(f"7z extraction failed: {process.stderr.read()}")

        ###OONGA
        # If user selected Replaced previously, here the new content gets added
        # If user selected Merge previously, the content of the previous version
        # of the mod is contained, and here the new content gets merged
        self.flatten_items(self.longpath(temp_dir))
        self.move_temp(self.longpath(temp_dir),self.longpath(extract_path))

        return archive_path, extract_path, call
    
    def is_fomod(self, archive_path, call):
        # # List files
        result = subprocess.run(
            [SEVEN_ZIP, "l", "-ba", archive_path],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        if result.returncode != 0:
            raise RuntimeError(f"7z error: {result.stderr}")

        files = []
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 6:
                file_path = " ".join(parts[5:])
                files.append(file_path.replace("\\", "/"))

        is_fomod = False
        # If archive contains fomod folder, let MO handle the install
        for f in files:
            parts = f.lower().replace("\\", "/").split("/")
            if "fomod" in parts:
                is_fomod = True
                break
        return archive_path, is_fomod, call
        
    def find_fomods(self, archives, exist_action):
        for archive_path in archives:
            # # List files
            result = subprocess.run(
                [SEVEN_ZIP, "l", "-ba", archive_path],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
            )
            if result.returncode != 0:
                raise RuntimeError(f"7z error: {result.stderr}")

            files = []
            for line in result.stdout.splitlines():
                parts = line.split()
                if len(parts) >= 6:
                    file_path = " ".join(parts[5:])
                    files.append(file_path.replace("\\", "/"))

            fomod = False
            # If archive contains fomod folder, let MO handle the install
            for f in files:
                parts = f.lower().replace("\\", "/").split("/")
                if "fomod" in parts:
                    fomod = True
                    self.plugin.fomod_list.append(archive_path)
                    break
            if not fomod:
                self.plugin.non_fomod_list.append(archive_path)
        self.plugin.new_install_order = self.plugin.non_fomod_list + self.plugin.fomod_list
        return archives, exist_action
    
    def refresh(self):
        """Call organizer refresh (if provided)."""
        if not self._organizer:
            raise RuntimeError("No organizer instance provided")
        self._organizer.refresh()
        return True
    
    def merge_folders(self, src, dst):
        """Recursively merge src folder into dst."""
        if not os.path.exists(dst):
            print(f"Creating new root folder: {dst}")
            shutil.move(src, dst)
            return

        for item in os.listdir(src):
            s = os.path.join(src, item)
            d = os.path.join(dst, item)
            if os.path.isdir(s):
                self.merge_folders(s, d)
            else:
                print(f"Moving file: {s} -> {d}")
                if os.path.exists(d):
                    os.remove(d)
                shutil.move(s, d)

        os.rmdir(src)
    
    def move_temp(self, temp_dir, dest_dir):
        """
        Moves all files and folders from src_dir into dst_dir,
        then removes the empty src_dir.
        """
        if not os.path.exists(temp_dir):
            return
        #os.makedirs(dest_dir, exist_ok=True)

        for item in os.listdir(temp_dir):
            src_path = os.path.join(temp_dir, item)
            dst_path = os.path.join(dest_dir, item)
            if os.path.exists(dst_path):
                if os.path.isdir(dst_path):
                    print(f"Merging folder: {src_path} -> {dst_path}")
                    self.merge_folders(src_path, dst_path)
                else:
                    print(f"Overwriting file: {src_path} -> {dst_path}")
                    os.remove(dst_path)
                    shutil.move(src_path, dst_path)
            else:
                print(f"Moving: {src_path} -> {dst_path}")
                shutil.move(src_path, dst_path)
        # Remove empty source directory
        if os.path.isdir(temp_dir) and not os.listdir(temp_dir):
            os.rmdir(temp_dir)

    def flatten_items(self, src_dir, folder_names=SKYRIM_DATA_FOLDERS, extensions=SKYRIM_DATA_FILE_TYPES):
        folder_names = [f.lower() for f in (folder_names or [])]
        extensions = [e.lower() for e in (extensions or [])]

        print(f"Scanning: {src_dir}")

        # Flag to indicate we found Skyrim data content
        is_data = False

        for root, dirs, files in os.walk(src_dir, topdown=True):
            if os.path.basename(root).lower() == "data":
                is_data = True
                if root == src_dir: return    
            # Check if any subfolder is a known Skyrim folder
            elif any(d.lower() in folder_names for d in dirs):
                is_data = True
                if root == src_dir: return
                print(f"→ Data folder detected in: {root}")
            # Check if any file has a known Skyrim data file extension
            elif any(f.lower().endswith(ext) for f in files for ext in extensions):
                is_data = True
                if root == src_dir: return
                print(f"→ Data files detected in: {root}")

            # If flagged as data folder, move everything to root
            if is_data:
                for item in os.listdir(root):
                    src_path = os.path.join(root, item)
                    dst_path = os.path.join(src_dir, item)
                    if os.path.isdir(src_path):
                        print(f"Merging folder: {src_path} -> {dst_path}")
                        self.merge_folders(src_path, dst_path)
                    else:
                        print(f"Moving file: {src_path} -> {dst_path}")
                        if os.path.exists(dst_path):
                            os.remove(dst_path)
                        shutil.move(src_path, dst_path)
                if os.path.exists(root) and root != src_dir:
                    os.rmdir(root)
                break  # stop after flattening the first data folder
        

    # def flatten_items(self, src_dir, folder_names=SKYRIM_DATA_FOLDERS, extensions=SKYRIM_DATA_FILE_TYPES):
    #     folder_names = [f.lower() for f in (folder_names or [])]
    #     extensions = [e.lower() for e in (extensions or [])]

    #     print(f"Searching in: {src_dir}")
    #     print(f"Target folders: {folder_names}, Target extensions: {extensions}")

    #     is_data = False
    #     # Handle "Data" folder directly
    #     data_folder = os.path.join(src_dir, "Data")
    #     if os.path.isdir(data_folder):
    #         is_data = True
    #         print(f"Found 'Data' folder: {data_folder}")
    #         for item in os.listdir(data_folder):
    #             src_path = os.path.join(data_folder, item)
    #             dst_path = os.path.join(src_dir, item)
    #             if os.path.exists(dst_path):
    #                 if os.path.isdir(dst_path):
    #                     print(f"Merging folder: {src_path} -> {dst_path}")
    #                     self.merge_folders(src_path, dst_path)
    #                 else:
    #                     print(f"Overwriting file: {src_path} -> {dst_path}")
    #                     os.remove(dst_path)
    #                     shutil.move(src_path, dst_path)
    #             else:
    #                 print(f"Moving: {src_path} -> {dst_path}")
    #                 shutil.move(src_path, dst_path)
    #         # Remove empty Data folder
    #         try:
    #             os.rmdir(data_folder)
    #             print(f"Removed empty Data folder: {data_folder}")
    #         except OSError:
    #             pass

    #     if not is_data:
    #         for root, dirs, files in os.walk(src_dir, topdown=True):
    #             # if root == src_dir:
    #             #     continue

    #             # Folders
    #             for d in dirs:
    #                 if d.lower() in folder_names or is_data:
    #                     if root == src_dir:
    #                         continue
    #                     is_data = True
    #                     src_path = os.path.join(root, d)
    #                     dst_path = os.path.join(src_dir, d)
    #                     self.merge_folders(src_path, dst_path)

    #             # Files
    #             for f in files:
    #                 if any(f.lower().endswith(ext) for ext in extensions) or is_data:
    #                     if root == src_dir:
    #                         continue
    #                     is_data = True
    #                     src_path = os.path.join(root, f)
    #                     dst_path = os.path.join(src_dir, f)
    #                     # # Don't move the file if the parent folder is Skyrim Data folder
    #                     # if os.path.dirname(src_path) in folder_names:
    #                     #     continue
    #                     # if os.path.exists(dst_path):
    #                     #     os.remove(dst_path)
    #                     shutil.move(src_path, dst_path)

    #             if is_data: break

class MarqueeLabel(QtWidgets.QLabel):
    def __init__(self, text="", parent=None):
        super().__init__(parent)
        self.base_text = text
        self.offset = 0
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_offset)
        self.setText(text)
        self.setMouseTracking(True)
        self.setAlignment(Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft)

        # start scrolling if text is too wide
        if self.fontMetrics().horizontalAdvance(self.base_text) > self.width():
            self.timer.start(30)

        # enable custom context menu
        self.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.customContextMenuRequested.connect(self.show_context_menu)

    def show_context_menu(self, pos):
        menu = QtWidgets.QMenu(self)
        copy_action = menu.addAction("Copy")
        action = menu.exec(self.mapToGlobal(pos))
        if action == copy_action:
            QtWidgets.QApplication.clipboard().setText(self.base_text)

    def setText(self, text):
        self.base_text = text
        self.offset = 0
        super().setText(text)
        self.update()

        if self.fontMetrics().horizontalAdvance(self.base_text) > self.width():
            self.timer.start(30)
        else:
            self.timer.stop()

    def update_offset(self):
        fm = self.fontMetrics()
        text_width = fm.horizontalAdvance(self.base_text)
        self.offset -= 1
        if self.offset < -text_width - 20:
            self.offset = 0
        self.update()

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        fm = self.fontMetrics()
        text_width = fm.horizontalAdvance(self.base_text)

        if text_width <= self.width():
            painter.drawText(self.rect(), Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignCenter, self.base_text)
        else:
            x = self.offset
            while x < self.width():
                painter.drawText(x, (self.height() + fm.ascent()) // 2, self.base_text)
                x += text_width + 20



class VolumeSlider(QtWidgets.QSlider):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.show_text = False
        self.setMouseTracking(True)
        self.valueChanged.connect(self.on_value_changed)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.show_text = True
            self.update_tooltip()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self.show_text:
            self.update_tooltip()
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.show_text = False
            QtWidgets.QToolTip.hideText()
        super().mouseReleaseEvent(event)

    def on_value_changed(self, _):
        if self.show_text:
            self.update_tooltip()

    def update_tooltip(self):
        opt = QtWidgets.QStyleOptionSlider()
        self.initStyleOption(opt)
        handle_rect = self.style().subControlRect(
            QtWidgets.QStyle.ComplexControl.CC_Slider,
            opt,
            QtWidgets.QStyle.SubControl.SC_SliderHandle,
            self
        )

        global_handle = self.mapToGlobal(handle_rect.center())
        tooltip_pos = global_handle + QPoint(-21, -55)

        QtWidgets.QToolTip.showText(tooltip_pos, f"{self.value()}%", self)


class GandalfLabel(QtWidgets.QLabel):
    clicked = pyqtSignal()

    def __init__(self, parent=None, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.parent = parent
        self.setAcceptDrops(True)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.clicked.emit()

    # === Drag & Drop handling ===
    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            if event.mimeData().hasUrls():
                # Force the action to "Move" instead of default "Copy"
                event.setDropAction(Qt.DropAction.MoveAction)
                event.accept()
            else:
                event.ignore()

    def dropEvent(self, event):
        os.makedirs(MUSIC_FOLDER, exist_ok=True)
        files = [url.toLocalFile() for url in event.mimeData().urls()]
        invalid_files = []

        added_files = 0
        tune_exists = True if self.parent.engine.music_files else False
        for file_path in files:
            if not file_path.lower().endswith(".mp3"):
                invalid_files.append(file_path)
                continue  # skip non-mp3 files
            try:
                file_name = os.path.basename(file_path)
                dest_path = os.path.join(MUSIC_FOLDER, file_name)
                # Skip files from MUSIC_FOLDER, obviously, but not
                # so obvious that I realized it right away
                if os.path.exists(dest_path):
                    continue
                shutil.move(file_path, dest_path)
                # Only play if this is the only file in the music folder
                # And refresh music_files
                if not self.parent.engine.music_files:
                    self.parent.start_playback()
                added_files += 1
                print(f"Added: {dest_path}")
            except Exception as e:
                print(f"Failed to add {file_path}: {e}")
        tune_exists = " more " if tune_exists else " "
        if added_files == 1:
            QMessageBox.information(
                self,
                "Gandalf is Vibing",
                f"One{tune_exists}tune has been added to Gandalf's Spellbook!",
            )
        elif added_files > 1:
            QMessageBox.information(
                self,
                "Gandalf is Vibing",
                f"{added_files}{tune_exists}tunes have been added to Gandalf's Spellbook!",
            )
        if invalid_files:
            QMessageBox.warning(
                self,
                "Invalid files",
                f"The following files were skipped because they are not .mp3:\n" +
                "\n".join([os.path.basename(f) for f in invalid_files])
            )

import random 

class MusicEngine:
    def __init__(self, music_dir, player_cls):
        self.music_dir = music_dir
        self.player_cls = player_cls

        self.process = None
        self.file_path = None
        self.is_muted = False
        self.repeat_on = False
        self.title = None

        self.music_files = []
        self.music_queue = []
        self.last_song = None

    def get_music_files(self):
        files = []
        if os.path.exists(self.music_dir):
            for f in os.listdir(self.music_dir):
                if f.lower().endswith(".mp3"):
                    files.append(os.path.join(self.music_dir, f))
        self.music_files = files
        return files

    def get_next_random_song(self):
        music_files = self.get_music_files()
        if not music_files:
            return None
        if not self.music_queue:
            self.music_queue = music_files.copy()
            random.shuffle(self.music_queue)
            # avoid repeat of last song
            if self.last_song and self.music_queue[0] == self.last_song and len(self.music_queue) > 1:
                self.music_queue[0], self.music_queue[1] = self.music_queue[1], self.music_queue[0]
        next_song = self.music_queue.pop(0)
        self.last_song = next_song
        return next_song

    def play(self, file_path=None, volume=50):
        if file_path:
            self.file_path = file_path
        if not self.file_path:
            return
        self.process = self.player_cls(self.file_path)
        if self.is_muted: self.process.volume = 0
        else: self.process.volume = volume
        self.process.play(block=False)

    def play_random_song(self, skip=False, volume=50):
        if not self.repeat_on or skip or not self.file_path:
            self.file_path = self.get_next_random_song()
        if self.file_path:
            # Removes .mp3 from name and sets the name as title
            # if title_object:
            self.title = os.path.basename(self.file_path)[:-4]
            #     title_object.setText(self.title)
            self.play(self.file_path, volume=volume)

    def change_volume(self, volume):
        if not self.is_muted and self.process:
            self.process.volume = volume

    def toggle_repeat(self):
        self.repeat_on = not self.repeat_on
        return self.repeat_on

    def toggle_mute(self, slider_value):
        self.is_muted = not self.is_muted
        if self.process:
            self.process.volume = 0 if self.is_muted else slider_value
        return self.is_muted

    def is_playing(self):
        return self.process and self.process.is_playing, self.title

    def stop(self):
        if self.process:
            self.process.close()
            self.process = None


class MusicPlayerWidget(QtWidgets.QWidget):
    def __init__(self, engine: MusicEngine, plugin=None):
        super().__init__()
        self.engine = engine
        self.plugin = plugin
        self.slider_released = True

        buttons = QtWidgets.QHBoxLayout()

        # Layout
        layout = QtWidgets.QVBoxLayout(self)
        # layout.setAlignment(ALIGN_TOP)
        layout.setContentsMargins(0,0,0,0)

        self.marquee = MarqueeLabel()
        self.marquee.setFixedWidth(120)  # control visible area
        self.setMaximumWidth(120)
        # self.marquee.setMaximumWidth(105)
        # self.setMinimumWidth(120)
        
        # Mute button
        self.mute_button = QtWidgets.QPushButton()
        self.icon_muted = QtGui.QIcon(os.path.join(os.path.dirname(__file__), "resources/icons/volume-muted.png"))
        self.icon_unmuted = QtGui.QIcon(os.path.join(os.path.dirname(__file__), "resources/icons/volume.png"))
        self.mute_button.setIcon(self.icon_unmuted)
        self.mute_button.clicked.connect(self.toggle_mute_unmute)
        self.mute_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        # self.mute_button.setFixedWidth(30)
        self.mute_button.setFixedHeight(25)
          
        # Volume slider
        self.volume_slider = VolumeSlider(Qt.Orientation.Horizontal)
        #self.volume_slider = QtWidgets.QSlider(Qt.Orientation.Horizontal)
        self.volume_slider.setRange(0, 100)
        self.volume_slider.setValue(50)
        self.volume_slider.sliderReleased.connect(self.on_handle_released)
        self.volume_slider.sliderPressed.connect(self.on_handle_pressed)
        self.volume_slider.valueChanged.connect(self.on_value_changed) 
        # self.volume_slider.setFixedWidth(200)
        # self.volume_slider.setStyleSheet("""
        #     QSlider::handle:horizontal {
        #         width: 22px;   /* make handle wider */
        #         height: 20px;  /* optional: taller */
        #         margin: -8px 0; /* adjust vertical alignment */
        #     }
        # """)

        # Skip button
        self.skip_button = QtWidgets.QPushButton()
        self.icon_skip = QtGui.QIcon(os.path.join(os.path.dirname(__file__), "resources/icons/skip-icon.png"))
        self.skip_button.setIcon(self.icon_skip)
        self.skip_button.clicked.connect(self.skip_song)
        self.skip_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        # self.skip_button.setFixedWidth(30)
        self.skip_button.setFixedHeight(25)
        self.skip_button.setToolTip("Next Random")
        
        # Gandalf vibing   
        gandalf_gif_path = os.path.join(os.path.dirname(__file__), "resources/gifs/gandalf.gif")
        self.gandalf_gif = GandalfLabel(parent=self)
        self.gandalf_gif.setContentsMargins(0,0,0,0)
        self.gandalf_gif.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.gandalf_gif_movie = QtGui.QMovie(gandalf_gif_path)
        self.gandalf_gif_movie.setScaledSize(QSize(60, 30))
        self.gandalf_gif.setMovie(self.gandalf_gif_movie)
        self.gandalf_gif.clicked.connect(self.open_add_music_dialog)
        self.gandalf_gif.setCursor(POINTING_HAND_CURSOR)
        self.gandalf_gif.setToolTip("Feed Gandalf!")
        # start() to make it show up initialy and stop() in case there's no
        # added songs atm, so he's not vibing to silence, though he has his pipe
        self.gandalf_gif_movie.start()
        self.gandalf_gif_movie.stop()

        # Repeat button
        self.repeat_button = QtWidgets.QPushButton()
        self.icon_repeat = QtGui.QIcon(os.path.join(os.path.dirname(__file__), "resources/icons/repeat.png"))
        self.icon_repeat_on = QtGui.QIcon(os.path.join(os.path.dirname(__file__), "resources/icons/repeat-on-icon.png"))
        self.repeat_button.setIcon(self.icon_repeat)
        self.repeat_button.clicked.connect(self.toggle_repeat)
        self.repeat_button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        # self.repeat_button.setFixedWidth(30)
        self.repeat_button.setFixedHeight(25)
        self.repeat_button.setToolTip("Repeat: Off")

        buttons.addWidget(self.repeat_button, alignment=Qt.AlignmentFlag.AlignLeft)
        buttons.addWidget(self.mute_button)
        buttons.addWidget(self.skip_button, alignment=Qt.AlignmentFlag.AlignRight)

        # Marque is used for a song name text
        playing, title = self.engine.is_playing()
        layout.addWidget(self.marquee)
        if not playing: self.marquee.setVisible(False)
        layout.addWidget(self.volume_slider)
        layout.addLayout(buttons)
        layout.addSpacing(5)
        layout.addWidget(self.gandalf_gif, alignment=Qt.AlignmentFlag.AlignCenter)

        # Timer to check if music finished
        self.timer = QTimer()
        self.timer.timeout.connect(self.check_song)

        # Start playback
        background_music = self.plugin.load_settings("background_music")
        background_music = not background_music or background_music == "yes"
        if background_music:
            self.start_playback()
        self.load_settings()

    def start_playback(self, volume=50):
        playing, title = self.engine.is_playing()
        if not playing:
            self.engine.play_random_song(volume=self.volume_slider.value())
            playing, title = self.engine.is_playing()

        if title:
            self.marquee.setText(title)
            self.marquee.setVisible(True)
        self.update_gandalf_vibe(self.volume_slider.value())
        self.timer.start(2000)

    def stop_playback(self):
        playing, title = self.engine.is_playing()
        if playing:
            self.engine.stop()
            playing, title = self.engine.is_playing()
        self.update_gandalf_vibe(0)

    def check_song(self):
        playing, title = self.engine.is_playing()
        if not playing and self.engine.process:
            self.engine.play_random_song(volume=self.volume_slider.value())
            self.update_gandalf_vibe(self.volume_slider.value())
            playing, title = self.engine.is_playing()
            if title:
                self.marquee.setText(title)
                self.marquee.setVisible(True)
        elif not self.engine.process:
            self.timer.stop()

    def skip_song(self):
        self.engine.play_random_song(
            skip=True, 
            volume=self.volume_slider.value())
        playing, title = self.engine.is_playing()
        if title:
            self.marquee.setText(title)

    def toggle_repeat(self):
        repeat_on = self.engine.toggle_repeat()
        if repeat_on:
            self.repeat_button.setIcon(self.icon_repeat_on)
            self.repeat_button.setToolTip("Repeat: On")
        else:
            self.repeat_button.setIcon(self.icon_repeat)
            self.repeat_button.setToolTip("Repeat: Off")
        self.plugin.save_settings("repeat_on", "yes" if repeat_on else "no")

    def toggle_mute_unmute(self):
        muted = self.engine.toggle_mute(self.volume_slider.value())
        if muted:
            self.mute_button.setIcon(self.icon_muted)
            self.gandalf_gif_movie.stop()
        else:
            self.mute_button.setIcon(self.icon_unmuted)
            self.update_gandalf_vibe(self.volume_slider.value())

        self.plugin.save_settings("is_muted", "yes" if muted else "no")

    def on_value_changed(self):
        volume = self.volume_slider.value()
        self.engine.change_volume(volume)
        self.update_gandalf_vibe(volume)
        if self.slider_released:
            self.plugin.save_settings("volume",str(volume))

    def on_handle_pressed(self):
        self.slider_released = False

    def on_handle_released(self):
        self.slider_released = True
        volume = self.volume_slider.value()
        self.plugin.save_settings("volume",str(volume))

    def update_gandalf_vibe(self, volume):
        """
        Make Gandalf vibe according to volume:
        - volume = 0 -> stop
        - volume < 30 -> slow
        - volume 30-70 -> normal
        - volume > 70 -> fast
        """
        playing, title = self.engine.is_playing()
        if not playing or self.engine.is_muted:
            self.gandalf_gif_movie.stop()
        elif volume == 0:
            self.gandalf_gif_movie.stop()
        else:
            self.gandalf_gif_movie.start()
            if volume < 30:
                self.gandalf_gif_movie.setSpeed(50)   # slow
            elif volume < 70:
                self.gandalf_gif_movie.setSpeed(100)  # normal
            else:
                self.gandalf_gif_movie.setSpeed(150)  # fast

    def load_settings(self):
        is_muted = self.plugin.load_settings("is_muted")
        if is_muted and is_muted == "yes":
            if not self.engine.is_muted:
                self.toggle_mute_unmute()
            else:
                self.mute_button.setIcon(self.icon_muted)
                self.gandalf_gif_movie.stop()
        else:
            if self.engine.is_muted:
                self.toggle_mute_unmute()
            else:
                self.mute_button.setIcon(self.icon_unmuted)
                self.update_gandalf_vibe(self.volume_slider.value())

        volume = self.plugin.load_settings("volume")
        if volume:
            self.volume_slider.setValue(int(volume))

        repeat = self.plugin.load_settings("repeat_on")
        if repeat and repeat == "yes":
            if repeat and repeat == "yes":
                if not self.engine.repeat_on:
                    self.toggle_repeat()
                else:
                    self.repeat_button.setIcon(self.icon_repeat_on)
                    self.repeat_button.setToolTip("Repeat: On")
            else:
                if self.engine.repeat_on:
                    self.toggle_repeat()
                else:
                    self.repeat_button.setIcon(self.icon_repeat)
                    self.repeat_button.setToolTip("Repeat: Off")

    def open_add_music_dialog(self):
        # third argument is case-sensitive (*<ext> *<ext> ...)
        files, _ = QtWidgets.QFileDialog.getOpenFileNames(
            self,
            "Select Music Files",
            MUSIC_FOLDER,
            "Audio Files (*.mp3)"
        )
        if not files:
            return

        # Make folder if doesn't exist for some reason
        os.makedirs(MUSIC_FOLDER, exist_ok=True)
        added_files = 0
        tune_exists = True if self.engine.music_files else False
        for file_path in files:
            try:
                file_name = os.path.basename(file_path)
                dest_path = os.path.join(MUSIC_FOLDER, file_name)
                # Skip files from MUSIC_FOLDER, obviously, but not
                # so obvious that I realized it right away
                if os.path.exists(dest_path):
                    continue
                # move file
                shutil.move(file_path, dest_path)
                # Only play if this is the only file in the music folder
                # And refresh music_files
                if not self.engine.music_files:
                    self.start_playback()
                added_files += 1

            except Exception as e:
                print(f"Failed to add {file_path}: {e}")
        tune_exists = " more " if tune_exists else " "
        if added_files == 1:
            QMessageBox.information(
                self,
                "Gandalf is Vibing",
                f"One{tune_exists}tune has been added to Gandalf's Spellbook!",
            )
        elif added_files > 1:
            QMessageBox.information(
                self,
                "Gandalf is Vibing",
                f"{added_files}{tune_exists}tunes have been added to Gandalf's Spellbook!",
            )

        
class CheckboxPopup(QtWidgets.QDialog):
    def __init__(self, mod_names, archive_path, plugin=None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Select Mods")
        archive_name = os.path.basename(archive_path)
        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(
            QtWidgets.QLabel(f"These mods were installed using same or similar archives(different versions).\n" +
                             "Cancelling will cancel installation process.\n" +
                             "Select which mod(s) to merge/replace:\n")
        )

        # Store checkboxes
        self.checkboxes = []
        archive_mod_name = plugin.read_meta(archive_path,"name")
        for item in mod_names:
            cb = QtWidgets.QCheckBox(item)
            if item == archive_mod_name: cb.setChecked(True)
            layout.addWidget(cb)
            self.checkboxes.append(cb)

        layout.addSpacing(10)

        # OK/Cancel buttons
        btns = OK | CANCEL
        buttonBox = QtWidgets.QDialogButtonBox(btns)
        buttonBox.accepted.connect(self.accept)
        buttonBox.rejected.connect(self.reject)
        layout.addWidget(buttonBox)


    def accept(self):
        if not any(cb.isChecked() for cb in self.checkboxes):
            QtWidgets.QMessageBox.warning(self, "Warning", "Please select at least one option.")
            return  # do not close
        super().accept()

    def get_selected(self):
        """Return list of checked item texts"""
        return [cb.text() for cb in self.checkboxes if cb.isChecked()]
    
class DragDropTable(QtWidgets.QTableWidget):
    def __init__(self, upper, parent=None):
        super().__init__(0, 2, parent)
        self.upper = upper
        self.setHorizontalHeaderLabels(["Install Order",""])
        # self.horizontalHeader().setStretchLastSection(True)
        self.setEditTriggers(QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers)
        self.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectionBehavior.SelectRows)
        self.setSelectionMode(QtWidgets.QAbstractItemView.SelectionMode.ExtendedSelection)
        self.setDragEnabled(True)
        self.setAcceptDrops(True)
        self.setDragDropOverwriteMode(False)
        self.setDropIndicatorShown(True)
        self.setDragDropMode(QtWidgets.QAbstractItemView.DragDropMode.InternalMove)

        self.verticalHeader().setVisible(False)
        self.horizontalHeader().setStretchLastSection(False)
        self.horizontalHeader().setSectionResizeMode(0, QtWidgets.QHeaderView.ResizeMode.Stretch)  # Install Order column
        self.setColumnWidth(1, 30)  # fixed narrow Activate column

        # Adjust window size based on table content
        self.setSizeAdjustPolicy(QtWidgets.QAbstractScrollArea.SizeAdjustPolicy.AdjustToContents)
        self.resizeRowsToContents()
        self.resizeColumnsToContents()
        
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.setContextMenuPolicy(CUSTOM_CONTEXT_MENU)
        self.customContextMenuRequested.connect(self.on_right_click)
        
        self.default_separator = None

        self.cellClicked.connect(lambda row,column: self.on_cell_clicked(row,column,"click"))
        self.cellDoubleClicked.connect(lambda row,column: self.on_cell_clicked(row,column,"double-click"))

        self.info_shown = False

        # Defer scroll until widget is visible/layouted
        self.verticalHeader().setDefaultSectionSize(35)
        self._scroll_factor = 10  # how much to multiply wheel scroll

    def wheelEvent(self, event):
        delta = event.angleDelta().y()  # how much wheel moved
        steps = delta / 120  # one "notch" is 120
        scroll_amount = int(steps * self._scroll_factor)
        scrollbar = self.verticalScrollBar()
        scrollbar.setValue(scrollbar.value() - scroll_amount)
        event.accept()

    def scroll_to_separator(self, row, ran = False):
        if not ran:
            QTimer.singleShot(0, lambda: self.scroll_to_separator(row,ran=True))
            return
        if row >= 0:
            separator = self.item(row, 0)
            self.scrollToItem(
                separator, QtWidgets.QAbstractItemView.ScrollHint.PositionAtTop
            )

    def on_right_click(self, pos):
        index = self.indexAt(pos)
        if not index.isValid():
            return
        row = index.row()
        archive_item = self.item(row, 0)
        archive_name = archive_item.text() if archive_item else "<unknown>"

        menu = QtWidgets.QMenu(self)

        check_all_action = menu.addAction(f"Enable all")
        uncheck_all_action = menu.addAction(f"Disable all")
        inverse_check_action = menu.addAction("Inverse")

        action = menu.exec(self.viewport().mapToGlobal(pos))
        if action == None:
            return
        
        if action == check_all_action:
            self.set_all_archives_checkstates(CHECKED)

        elif action == uncheck_all_action:
            self.set_all_archives_checkstates(UNCHECKED)

        elif action == inverse_check_action:
            self.inverse_archives_selection()

    def set_all_archives_checkstates(self, state):
        for i in range(self.rowCount()):
            item = self.item(i,1)
            if item is not None and item.text():
                item.setCheckState(state)

    def inverse_archives_selection(self):
        for i in range(self.rowCount()):
            item = self.item(i,1)
            if item is not None and item.text():
                if item.checkState() == CHECKED:
                    item.setCheckState(UNCHECKED)
                else:
                    item.setCheckState(CHECKED)

    def on_cell_clicked(self, row, column, click_type):
        if column != 1 and click_type=="click":  # Activate column is index 1
            return

        # get all selected rows
        selected_rows = sorted(set(idx.row() for idx in self.selectionModel().selectedRows()))
        if not selected_rows:
            selected_rows = [row]

        if self.item(row,1) != None and self.item(row,1).text():
            # determine new state by toggling clicked cell
            new_state = CHECKED if self.item(row, 1).checkState() == UNCHECKED else UNCHECKED

            for r in selected_rows:
                item = self.item(r, 1)
                if item:
                    item.setCheckState(new_state)
                    item.setTextAlignment(ALIGN_CENTER)
        else:
            current_separator = self.item(row, 0).text()
            if self.default_separator == current_separator:
                    return
            else:
                for r in range(self.rowCount()):
                    separator = self.item(r, 0).text()
                    if separator == self.default_separator:
                        self.takeItem(r, 1)
                        break
            item = QtWidgets.QTableWidgetItem()
            icon = QtGui.QIcon(os.path.join(os.path.dirname(__file__), "resources/icons/save-icon.png"))
            item.setIcon(icon)
            self.setItem(row, 1, item)
            self.default_separator = current_separator
            self.upper.upper.plugin.save_settings("default_separator",current_separator)
            self.upper.upper.plugin.default_separator = current_separator
            if not self.info_shown:
                QMessageBox.information(
                    None,
                    "Set as Default",
                    f"New default separator: \n{current_separator}"+
                    "\n\nNext time you run the installer, "+
                    "all the archives will be loaded under this separator.",
                )
                self.info_shown = True
   

    def dragLeaveEvent(self,event):
        self.upper.upper.toggle_lightning(False)
        event.accept()
   
    def dropEvent(self, event):
        self.upper.upper.toggle_lightning(False)
        # Save scroll position
        vscroll = self.verticalScrollBar()
        old_value = vscroll.value()

        selected_rows = sorted(set(idx.row() for idx in self.selectedIndexes()))
        if not selected_rows:
            return super().dropEvent(event)

        drop_index = self.indexAt(event.position().toPoint())
        if not drop_index.isValid():
            drop_row = self.rowCount()
        else:
            pos = self.dropIndicatorPosition()  # Qt.DropIndicatorPosition
            if pos == QtWidgets.QAbstractItemView.DropIndicatorPosition.AboveItem:
                drop_row = drop_index.row()
            elif pos == QtWidgets.QAbstractItemView.DropIndicatorPosition.BelowItem:
                drop_row = drop_index.row() + 1
            else:
                drop_row = drop_index.row() + 1  # treat "on item" as below

        rows_data = []
        for r in selected_rows:
            row_items = []
            for c in range(self.columnCount()):
                if self.item(r,c):
                    row_items.append(self.item(r,c).clone())
                else:
                    return      
            
            rows_data.append(row_items)

        for r in reversed(selected_rows):
            self.removeRow(r)
            if r < drop_row:
                drop_row -= 1

        for row_items in rows_data:
            self.insertRow(drop_row)
            for c, item in enumerate(row_items):
                self.setItem(drop_row, c, item)
            drop_row += 1

        # Restore scroll position
        vscroll.setValue(old_value)

        event.accept()

    def dragMoveEvent(self, event):
        super().dragMoveEvent(event)
        self.upper.upper.toggle_lightning(True)

class InstallOrderWindow(QtWidgets.QWidget):
    def __init__(self, upper, parent=None):
        super().__init__()
        self.setWindowTitle("Install Order")
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0,0,0,0)
        self.archives = upper.archives[::-1]
        self.table = DragDropTable(self)
        layout.addWidget(self.table)
        self.upper = upper

        self.separators = {}
        self.separator_list = []
        mod_list = upper.plugin._organizer.modList()
        for mod_name in mod_list.allMods():
            mod = mod_list.getMod(mod_name)
            if mod and mod.isSeparator():
                self.separator_list.append(mod.name())
                self.separators[mod.name()] = mod_list.priority(mod_name)
        
        self.separator_list.sort(key=lambda p: self.separators.get(p, 0))

        loaded_settings = self.upper.plugin.load_settings("default_separator")
        
        archives_added = False
        for separator in self.separator_list:
            if loaded_settings and loaded_settings == separator:
                self.add_separator_row(separator,default_separator=True)
                for archive in self.archives:
                    archive_basename = os.path.basename(archive)
                    archive_name_stripped = self.upper.plugin.extract_mod_name(archive_basename)
                    # self.add_row(os.path.basename(archive))
                    self.add_row(archive_name_stripped if archive_name_stripped else archive_basename.rsplit('.',1)[0], archive)
                archives_added = True
                continue
            self.add_separator_row(separator)

        if not loaded_settings and not archives_added:
            for archive in self.archives:
                archive_basename = os.path.basename(archive)
                archive_name_stripped = self.upper.plugin.extract_mod_name(archive_basename)
                # self.add_row(os.path.basename(archive))
                self.add_row(archive_name_stripped if archive_name_stripped else archive_basename.rsplit('.',1)[0], archive)

        # QTimer.singleShot(0,self.table.scrollToBottom)

    def add_row(self, name, archive_path, activate=True):
        row = self.table.rowCount()
        self.table.insertRow(row)
        name_item = QtWidgets.QTableWidgetItem(name)
        name_item.setToolTip(archive_path)
        self.table.setItem(row, 0, name_item)
        # Activate checkbox
        # Keep at least one space so it's recognized as text
        # so it can be used as condition in if statement
        item = QtWidgets.QTableWidgetItem(" ")
        item.setFlags(Qt.ItemFlag.ItemIsEnabled)
        item.setCheckState(CHECKED if activate else UNCHECKED)
        item.setTextAlignment(ALIGN_CENTER)
        self.table.setItem(row, 1, item)

    def add_separator_row(self, name, default_separator=False):
        row = self.table.rowCount()
        self.table.insertRow(row)
        item = QtWidgets.QTableWidgetItem(name)
        item.setFlags(Qt.ItemFlag.NoItemFlags)
        self.table.setItem(row, 0, item)
        # Add default separator if found or use last as default
        if default_separator or row == len(self.separator_list)-1:
            if not self.table.default_separator:
                self.table.default_separator = name
                item = QtWidgets.QTableWidgetItem()
                icon = QtGui.QIcon(os.path.join(os.path.dirname(__file__), "resources/icons/save-icon.png"))
                item.setIcon(icon)
                self.table.setItem(row, 1, item)
                QTimer.singleShot(0, lambda: self.table.scroll_to_separator(row))
    
    def get_reordered_archives(self):
        """
        Returns a dict: {mod_name: True/False}
        """
        archives_priority_checked = {}
        for row in range(self.table.rowCount()):
            if self.table.item(row, 1) and self.table.item(row,1).text():
                for archive in self.archives:
                    # archive_name = os.path.basename(archive)
                    # If row has check/uncheck (separators don't have one)
                    # name = self.table.item(row, 0).text()
                    archive_path = self.table.item(row, 0).toolTip()
                    checked = self.table.item(row, 1).checkState() == CHECKED
                    if archive == archive_path:
                        if row-1 >= 0:
                            finished = False
                            # Checking against previous rows, if mod then
                            # move current one up, if separator then get the
                            # next separator based on this one's idx + 1
                            # then place mod on next separator's priority
                            # since mod needs to be at the end of previous separator
                            for i in range(1, row+1):
                                row_previous = row - i
                                # Compare value from tooltip if archive, else from text for separators
                                previous_name = self.table.item(row_previous, 0).toolTip()
                                if previous_name in [arc for arc in self.archives]:
                                    if i == row:
                                        if len(self.separator_list) > 0:
                                            next_separator = self.separator_list[0]
                                            # Use first separator if row index is 0
                                            priority = self.separators.get(next_separator)
                                            archives_priority_checked[archive]=[priority,checked]
                                        else:
                                            # If there are no separators used
                                            priority = len(all_mods)-1
                                            archives_priority_checked[archive]=[priority,checked]
                                        finished = True
                                        break
                                    continue
                                else:
                                    # Comparing value from text for separators, as mentioned above
                                    previous_name = self.table.item(row_previous, 0).text()
                                    next_separator_index = self.separator_list.index(previous_name)+1
                                    if next_separator_index < len(self.separator_list):
                                        next_separator = self.separator_list[next_separator_index]
                                        priority = self.separators.get(next_separator)
                                        archives_priority_checked[archive]=[priority,checked]
                                    else:
                                        all_mods = self.upper.plugin._organizer.modList().allMods()
                                        priority = len(all_mods)-1
                                        archives_priority_checked[archive]=[priority,checked]
                                    finished = True
                                    break
                            if not finished:
                                all_mods = self.upper.plugin._organizer.modList().allMods()
                                priority = len(all_mods)-1
                                archives_priority_checked[archive]=[priority,checked]
                            break
                        elif row == 0:
                            if len(self.separator_list) > 0:
                                next_separator = self.separator_list[0]
                                # Use first separator if row index is 0
                                priority = self.separators.get(next_separator)
                                archives_priority_checked[archive]=[priority,checked]
                            else:
                                all_mods = self.upper.plugin._organizer.modList().allMods()
                                # If there are no separators used
                                priority = len(all_mods)-1
                                archives_priority_checked[archive]=[priority,checked]
                        break
        # Returns dictionary (archive_path<str>:list[priority<int>,checked<bool>])
        # Keep in mind this returns current state priorities,
        # not taking into account insertions and shifting of mods
        # which is being handled in reorder_modlist method
        return archives_priority_checked

class InstallMethodDialog(QtWidgets.QDialog):
    def __init__(self, archives=None, plugin=None, parent=None, method="auto_install"):
        super().__init__(parent)
        self.plugin = plugin
        self.archives = archives
        self.method = method
        self.setWindowTitle("Install Dialog")
        self.setModal(False)
        # self.resize(800,350)

        # Main layout
        layout = QtWidgets.QVBoxLayout(self)

        prompt_wrapper = QtWidgets.QVBoxLayout()
        prompt_wrapper.setContentsMargins(0,5,20,15)
        

        # Buttons
        buttonBox = QtWidgets.QDialogButtonBox()
        if self.plugin.install_sequentially_cb.isChecked():
            self.proceed_button = buttonBox.addButton("Proceed", QtWidgets.QDialogButtonBox.ButtonRole.AcceptRole)
            self.proceed_button.clicked.connect(lambda: self.set_action("proceed"))
        else:
            # Question text
            label = QtWidgets.QLabel("How do you want to manage already installed non-FOMOD mods (if any)?")
            prompt_wrapper.addWidget(label, alignment=Qt.AlignmentFlag.AlignRight)
            
            self.ask_button = buttonBox.addButton("Prompt Me", QtWidgets.QDialogButtonBox.ButtonRole.AcceptRole)
            self.merge_button = buttonBox.addButton("Merge", QtWidgets.QDialogButtonBox.ButtonRole.AcceptRole)
            self.replace_button = buttonBox.addButton("Replace", QtWidgets.QDialogButtonBox.ButtonRole.AcceptRole)
            # Connect clicks
            self.merge_button.clicked.connect(lambda: self.set_action("merge"))
            self.replace_button.clicked.connect(lambda: self.set_action("replace"))
            self.ask_button.clicked.connect(lambda: self.set_action("ask"))
        
        buttonBox.accepted.connect(self.accept)

        # Default action
        self.plugin.exist_action = None

        gandalf_judging_path = os.path.join(os.path.dirname(__file__), "resources/images/gandalf-judging.png")
        self.gandalf_label = QtWidgets.QLabel()
        self.pixmap = QtGui.QPixmap(gandalf_judging_path)
        self.gandalf_label.setPixmap(self.pixmap)
        self.gandalf_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignBottom)
        self.gandalf_label.setContentsMargins(15,0,0,0)

        lightning_path = os.path.join(os.path.dirname(__file__), "resources/gifs/lightning.gif")
        self.lightning_label = QtWidgets.QLabel()
        self.lightning_label.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.lightning_label.setAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignBottom)
        self.lightning_movie = QtGui.QMovie(lightning_path)
        self.lightning_movie.setScaledSize(QSize(50, 50))
        self.lightning_label.setMovie(self.lightning_movie)
        # self.lightning_movie.start()
        self.lightning_label.setContentsMargins(10,35,0,0)

         # Opacity effect for fade in/out
        self.opacity_effect = QtWidgets.QGraphicsOpacityEffect()
        self.lightning_label.setGraphicsEffect(self.opacity_effect)
        self.opacity_effect.setOpacity(0.0)

        # Animation setup
        self.animation = QPropertyAnimation(self.opacity_effect, b"opacity")
        self.animation.setDuration(500)

        gandalf_wrapper = QtWidgets.QVBoxLayout()
        # Container widget
        gandalf_container = QtWidgets.QWidget()
        gandalf_layout = QtWidgets.QVBoxLayout(gandalf_container)
        gandalf_layout.setContentsMargins(0, 0, 0, 0)
        gandalf_layout.setSpacing(0)

        gandalf_layout.addWidget(self.lightning_label, alignment=Qt.AlignmentFlag.AlignLeft)
        gandalf_layout.addWidget(self.gandalf_label, alignment=Qt.AlignmentFlag.AlignRight)

        gandalf_wrapper.addWidget(gandalf_container, alignment=Qt.AlignmentFlag.AlignBottom)
        
        prompt_wrapper.addWidget(buttonBox)
        layout.addLayout(prompt_wrapper)

        self.install_fomods_last_cb = QtWidgets.QCheckBox("Install FOMODs last")
        self.install_fomods_last_cb.setToolTip("Whether to install FOMODs according to Install Order, or last(this won't change the actual Install Order you've set)")
        # self.install_fomods_last_cb.setLayoutDirection(Qt.LayoutDirection.RightToLeft)
        loaded_settings = self.plugin.load_settings("install_fomods_last")
        if not loaded_settings or loaded_settings == "yes":
            # Default true
            self.install_fomods_last_cb.setChecked(True)
            self.plugin.install_fomods_last = True
        else:
            self.install_fomods_last_cb.setChecked(False)
            self.plugin.install_fomods_last = False

        self.install_fomods_last_cb.stateChanged.connect(lambda checked: self.update_cb(checked))

        table_wrapper = QtWidgets.QVBoxLayout()
        label = QtWidgets.QLabel(
            "You can change default separator here, by ticking any one of them."+
            "\nDrag & Drop to change install order, enable/disable "+
            "to automatically enable/disable on install."
            )
        # label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        label.setWordWrap(True)
        table_wrapper.addWidget(self.install_fomods_last_cb)
        table_wrapper.addWidget(label)
        wrapper = QtWidgets.QHBoxLayout()
        self.install_order = InstallOrderWindow(self)
        table_wrapper.addWidget(self.install_order)
        fomod_label = QtWidgets.QLabel("Keep in mind that FOMODs always have to be manually handled.")
        fomod_label.setWordWrap(True)
        info_font = fomod_label.font()
        info_font.setPointSize(8)
        info_font.setBold(True)
        fomod_label.setFont(info_font)
        table_wrapper.addWidget(fomod_label)
        table_wrapper.setContentsMargins(5,0,15,12)
        wrapper.addLayout(table_wrapper)
        wrapper.addLayout(gandalf_wrapper)
        # wrapper.addWidget(self.image_label, alignment=Qt.AlignmentFlag.AlignBottom)
        wrapper.setContentsMargins(0,0,0,0)

        layout.addLayout(wrapper)

        layout.setContentsMargins(15,10,0,0)

    def update_cb(self, checked):
        self.plugin.save_settings("install_fomods_last","yes" if checked else "no")
        self.plugin.install_fomods_last = True if checked else False

    def toggle_lightning(self, on: bool):
        self.animation.stop()
        if on:
            self.animation.setStartValue(self.opacity_effect.opacity())
            self.animation.setEndValue(1.0)
            self.animation.start()
            self.lightning_label.show()
            self.lightning_movie.start()
        else:
            self.animation.setStartValue(self.opacity_effect.opacity())
            self.animation.setEndValue(0.0)
            self.animation.start()
            self.lightning_label.show()
            self.lightning_movie.start()

    def set_action(self, action):
        self.archives = self.install_order.get_reordered_archives()
        if self.plugin.install_sequentially_cb.isChecked():
            self.plugin.manually_install_archives(self.archives)
        else:
            if self.install_fomods_last_cb.isChecked():
                self.plugin.pre_auto_install_archives(self.archives, exist_action=action)
            else:
                self.plugin.auto_install_archives(self.archives, exist_action=action)

