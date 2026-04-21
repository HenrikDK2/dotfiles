import mobase
from PyQt6.QtCore import Qt, QTimer, QEvent, QObject
from PyQt6.QtWidgets import QApplication, QTreeView, QAbstractItemView
from PyQt6.QtGui import QShortcut, QKeySequence
class ViewWatcher(QObject):
   
    def __init__(self, view: QTreeView, on_highlight_changed, on_selection_changed):
        super().__init__(view)
        self._view = view
        self._highlight_callback = on_highlight_changed
        self._selection_callback = on_selection_changed
        self._last_highlighted = set()
       
        view.viewport().installEventFilter(self)
       
        selection_model = view.selectionModel()
        if selection_model:
            selection_model.selectionChanged.connect(self._on_selection_changed)
       
        model = view.model()
        if model:
            model.dataChanged.connect(self._on_data_changed)
   
    def eventFilter(self, obj, event: QEvent) -> bool:
        if event.type() == QEvent.Type.Paint:
            QTimer.singleShot(10, self._check_highlights)
        return False
   
    def _on_data_changed(self, top_left, bottom_right, roles):
        QTimer.singleShot(10, self._check_highlights)
   
    def _on_selection_changed(self, selected, deselected):
        if not self._view or not self._view.model():
            return
       
        indexes = selected.indexes()
        if indexes:
            index = indexes[0]
            name = index.data(Qt.ItemDataRole.DisplayRole)
            if name:
                self._selection_callback(name)
   
    def _check_highlights(self):
        if not self._view or not self._view.model():
            return
       
        model = self._view.model()
        highlighted = set()
       
        for row in range(model.rowCount()):
            index = model.index(row, 0)
           
            bg = index.data(Qt.ItemDataRole.BackgroundRole)
            if bg is not None:
                name = index.data(Qt.ItemDataRole.DisplayRole)
                if name:
                    highlighted.add(name)
       
        new_highlights = highlighted - self._last_highlighted
        if new_highlights:
            for name in new_highlights:
                self._highlight_callback(name)
       
        self._last_highlighted = highlighted
class AutoScrollHighlightPlugin(mobase.IPlugin):
   
    def __init__(self):
        super().__init__()
        self._organizer: mobase.IOrganizer = None
        self._mods_view: QTreeView = None
        self._plugins_view: QTreeView = None
        self._mods_watcher: ViewWatcher = None
        self._plugins_watcher: ViewWatcher = None
        self._syncing = False
        self._enabled = True
        self._shortcut: QShortcut = None
   
    def name(self) -> str:
        return "Auto Scroll Highlight"
   
    def author(self) -> str:
        return "Plugin Author"
   
    def description(self) -> str:
        return "Автоматически прокручивает к подсвеченному моду/плагину (двунаправленно)"
   
    def version(self) -> mobase.VersionInfo:
        return mobase.VersionInfo(1, 3, 0, mobase.ReleaseType.FINAL)
   
    def isActive(self) -> bool:
        return True
   
    def settings(self) -> list:
        return []
   
    def init(self, organizer: mobase.IOrganizer) -> bool:
        self._organizer = organizer
        # Теперь _setup и _setup_hotkey оба получают main_window
        organizer.onUserInterfaceInitialized(self._setup)
        organizer.onUserInterfaceInitialized(self._setup_hotkey)
        return True

   
    def _setup(self, main_window=None) -> None:
        """Находит виджеты и устанавливает наблюдателей."""
        for widget in QApplication.allWidgets():
            name = widget.objectName()
            if name == "modList" and isinstance(widget, QTreeView):
                self._mods_view = widget
                print("[AutoScroll] Found modList view")
            elif name == "espList" and isinstance(widget, QTreeView):
                self._plugins_view = widget
                print("[AutoScroll] Found espList view")

        if self._mods_view:
            self._mods_watcher = ViewWatcher(
                self._mods_view,
                self._on_mod_highlighted,
                self._on_mod_selected
            )
            print("[AutoScroll] Watcher installed for modList")

        if self._plugins_view:
            self._plugins_watcher = ViewWatcher(
                self._plugins_view,
                self._on_plugin_highlighted,
                self._on_plugin_selected
            )
            print("[AutoScroll] Watcher installed for espList")

        print("[AutoScroll] Auto-scroll synchronization is ENABLED (press F10 to toggle)")

   
    def _setup_hotkey(self, main_window) -> None:
        if main_window:
            self._shortcut = QShortcut(QKeySequence(Qt.Key.Key_F10), main_window)
            self._shortcut.activated.connect(self._toggle_enabled)
            print(f"[AutoScroll] Hotkey F10 registered for toggling synchronization")
   
    def _toggle_enabled(self) -> None:
        self._enabled = not self._enabled
        status = "ENABLED" if self._enabled else "DISABLED"
        print(f"[AutoScroll] ====================================")
        print(f"[AutoScroll] Auto-scroll synchronization is now {status}")
        print(f"[AutoScroll] ====================================")
   
    def _on_mod_highlighted(self, mod_name: str) -> None:
        if not self._enabled:
            return
       
        if self._syncing or not self._mods_view:
            return
       
        self._syncing = True
        QTimer.singleShot(20, lambda: self._scroll_to_item(
            self._mods_view, mod_name
        ))
        QTimer.singleShot(100, self._reset_sync)
   
    def _on_mod_selected(self, mod_name: str) -> None:
        pass
   
    def _on_plugin_highlighted(self, plugin_name: str) -> None:
        if not self._enabled:
            return
       
        if self._syncing or not self._plugins_view:
            return
       
        self._syncing = True
        QTimer.singleShot(20, lambda: self._scroll_to_item(
            self._plugins_view, plugin_name
        ))
        QTimer.singleShot(100, self._reset_sync)
   
    def _on_plugin_selected(self, plugin_name: str) -> None:
        if not self._enabled:
            return
       
        if self._syncing:
            return
           
        if not self._organizer or not self._mods_view:
            return
       
        plugin_list = self._organizer.pluginList()
        if not plugin_list:
            return
       
        mod_name = plugin_list.origin(plugin_name)
       
        if mod_name and mod_name not in ("data", "overwrite", "<data>"):
            self._syncing = True
           
            model = self._mods_view.model()
            if model:
                mod_list = self._organizer.modList()
                if mod_list:
                    display_name = mod_list.displayName(mod_name)
                   
                    matches = model.match(
                        model.index(0, 0),
                        Qt.ItemDataRole.DisplayRole,
                        display_name,
                        -1,
                        Qt.MatchFlag.MatchExactly | Qt.MatchFlag.MatchRecursive
                    )
                   
                    if matches:
                        QTimer.singleShot(10, lambda: self._scroll_to(
                            self._mods_view, matches[0]
                        ))
                    else:
                        matches2 = model.match(
                            model.index(0, 0),
                            Qt.ItemDataRole.DisplayRole,
                            mod_name,
                            -1,
                            Qt.MatchFlag.MatchExactly | Qt.MatchFlag.MatchRecursive
                        )
                        if matches2:
                            QTimer.singleShot(10, lambda: self._scroll_to(
                                self._mods_view, matches2[0]
                            ))
           
            QTimer.singleShot(100, self._reset_sync)
   
    def _scroll_to_item(self, view: QTreeView, item_name: str) -> None:
        if not view or not view.model():
            return
       
        model = view.model()
        matches = model.match(
            model.index(0, 0),
            Qt.ItemDataRole.DisplayRole,
            item_name,
            1,
            Qt.MatchFlag.MatchExactly | Qt.MatchFlag.MatchRecursive
        )
       
        if matches:
            self._scroll_to(view, matches[0])
   
    def _scroll_to(self, view: QTreeView, index) -> None:
        if view and index and index.isValid():
            view.scrollTo(
                index,
                QAbstractItemView.ScrollHint.PositionAtCenter
            )
   
    def _reset_sync(self) -> None:
        self._syncing = False
def createPlugin() -> mobase.IPlugin:
    return AutoScrollHighlightPlugin()