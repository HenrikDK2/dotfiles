#Written by MaskPlauge
import mobase
import os

try:
    from PyQt6.QtCore import QCoreApplication, QObject, Qt, QEvent, QItemSelectionModel, QTimer
    from PyQt6.QtGui import QIcon, QCursor, QAction
    from PyQt6.QtWidgets import QMainWindow, QTabWidget, QWidget, QTreeView, QApplication, QMenu, QPushButton, QHBoxLayout

    # Compatibility flags
    SELECT_FLAG = QItemSelectionModel.SelectionFlag.ClearAndSelect | QItemSelectionModel.SelectionFlag.Rows
    BLOCKED_EVENTS = {
        QEvent.Type.MouseMove, QEvent.Type.MouseButtonPress, QEvent.Type.MouseButtonRelease, 
        QEvent.Type.MouseButtonDblClick, QEvent.Type.Wheel, QEvent.Type.HoverEnter, 
        QEvent.Type.HoverLeave, QEvent.Type.HoverMove, QEvent.Type.KeyPress, QEvent.Type.KeyRelease,
    }
    WAIT_CURSOR = Qt.CursorShape.WaitCursor

except ImportError:
    from PyQt5.QtCore import QCoreApplication, QObject, Qt, QEvent, QItemSelectionModel, QTimer
    from PyQt5.QtGui import QIcon, QCursor, QAction
    from PyQt5.QtWidgets import QMainWindow, QTabWidget, QWidget, QTreeView, QApplication, QMenu, QPushButton, QHBoxLayout

    # Compatibility flags
    SELECT_FLAG = QItemSelectionModel.ClearAndSelect | QItemSelectionModel.Rows
    BLOCKED_EVENTS = {
        QEvent.MouseMove, QEvent.MouseButtonPress, QEvent.MouseButtonRelease, 
        QEvent.MouseButtonDblClick, QEvent.Wheel, QEvent.HoverEnter, 
        QEvent.HoverLeave, QEvent.HoverMove, QEvent.KeyPress, QEvent.KeyRelease,
    }
    WAIT_CURSOR = Qt.WaitCursor

DEBUG = False
FILENAME_COLUMN = 0
DOWNLOAD_COLUMN = 1

class ContextMenuEventFilter(QObject):
    def __init__(self, download_view: QTreeView, plugin_instance):
        super().__init__()
        self.download_view: QTreeView = download_view
        self.plugin: PauseOrResumeAllDownloads = plugin_instance
        self.pause_all_action = QAction("Pause All")
        self.pause_all_action.triggered.connect(self.plugin._pauseAllDownloads)
        self.resume_all_action = QAction("Resume All")
        self.resume_all_action.triggered.connect(self.plugin._resumeAllDownloads)

    def eventFilter(self, obj, event: QEvent):
        if getattr(self.plugin, 'is_running', False):
            if event.type() in BLOCKED_EVENTS:
                return True

        if event.type() == QEvent.Type.Show and isinstance(obj, QMenu):
            if obj.parent() == self.download_view:
                if getattr(self.plugin, 'is_running', False):
                    if getattr(self.plugin, 'is_pausing', False):
                        QTimer.singleShot(0, lambda:self.auto_trigger_menu_pause(obj))
                    elif getattr(self.plugin, 'is_resuming', False):
                        QTimer.singleShot(0, lambda:self.auto_trigger_menu_resume(obj))
                    return False
                elif getattr(self.plugin, 'insert_actions_in_context_menus', False):
                    self.insert_pause_all_and_resume_all(obj)
        return False
    
    def insert_pause_all_and_resume_all(self, menu: QMenu):
        selection_model = self.download_view.selectionModel()
        if not selection_model.hasSelection():
            return
        index = selection_model.currentIndex()
        item = index.sibling(index.row(), DOWNLOAD_COLUMN).data(Qt.ItemDataRole.DisplayRole)
        actions = menu.actions()
        if item is None and len(actions) == 11:
            menu.insertAction(actions[2], self.pause_all_action)
        elif len(actions) == 11:
            menu.insertAction(actions[2], self.resume_all_action)
    
    def auto_trigger_menu_pause(self, menu: QMenu):
        try:
            selection_model = self.download_view.selectionModel()
            if not selection_model.hasSelection():
                QTimer.singleShot(10, self.plugin._process_next_download)
                return
            index = selection_model.currentIndex()
            item = index.sibling(index.row(), DOWNLOAD_COLUMN).data(Qt.ItemDataRole.DisplayRole)
            actions = menu.actions()
            if item is None and len(actions) == 11:
                pause_action = actions[1]
                pause_action.trigger()
        finally:
            menu.close()
            QTimer.singleShot(10, self.plugin._process_next_download)

    def auto_trigger_menu_resume(self, menu: QMenu):
        try:
            selection_model = self.download_view.selectionModel()
            if not selection_model.hasSelection():
                QTimer.singleShot(10, self.plugin._process_next_download)
                return
            index = selection_model.currentIndex()
            item = index.sibling(index.row(), DOWNLOAD_COLUMN).data(Qt.ItemDataRole.DisplayRole)
            actions = menu.actions()
            if isinstance(item, str) and len(actions) == 11:
                resume_action = actions[1]
                resume_action.trigger()
        finally:
            menu.close()
            QTimer.singleShot(10, self.plugin._process_next_download)
           
class PauseOrResumeAllDownloads(mobase.IPlugin):

    def __init__(self):
        super(PauseOrResumeAllDownloads, self).__init__()
        self._parentWidget = None
    
    def init(self, organiser = mobase.IOrganizer):
        self._organizer = organiser
        self.pending_files = []
        self.is_running = False
        self.is_pausing = False
        self.is_resuming = False
        self.refresh_button = None
        self.resume_button = QPushButton("Resume All")
        self.resume_button.adjustSize()
        self.resume_button.clicked.connect(self._resumeAllDownloads)
        self.pause_button = QPushButton("Pause All")
        self.pause_button.adjustSize()
        self.pause_button.clicked.connect(self._pauseAllDownloads)
        self.insert_actions_in_context_menus = self._organizer.pluginSetting(self.name(), "InsertActionsInContextMenus")
        self.insert_buttons_in_download_tab = self._organizer.pluginSetting(self.name(), "InsertButtonsInDownloadTab")
        self._organizer.onUserInterfaceInitialized(self._onUserInterfaceInitialized)
        return True

    def name(self) -> str:
        return "PauseOrResumeAllDownloads"
    
    def localizedName(self) -> str:
        return self.tr("PauseOrResumeAllDownloads")
    
    def author(self) -> str:
        return "MaskPlague"

    def description(self):
        return self.tr("Adds buttons to pause or resume all downloads.")
    
    def version(self) -> mobase.VersionInfo:
        return mobase.VersionInfo(1, 0, 0, mobase.ReleaseType.ALPHA)
    
    def settings(self):
        return [
            mobase.PluginSetting("InsertActionsInContextMenus", 
                                 'If "Pause All" and "Resume All" actions should be inserted in relevant context menus (changing requires restarting MO2).',
                                 False),
            mobase.PluginSetting("InsertButtonsInDownloadTab", 
                                 'If "Pause All" and "Resume All" buttons should be inserted at the top of the downloads tab (changing requires restarting MO2).', 
                                 True)
            ]
    
    def displayName(self):
        return self.tr("PauseOrResumeAllDownloads")
    
    def tooltip(self):
        return ""
    
    def icon(self):
        return QIcon()
    
    def display(self):
        return

    def tr(self, str):
        return QCoreApplication.translate("PauseOrResumeAllDownloads", str)
    
    def _log(self, string): #for debugging
        if DEBUG:
            print("PauseOrResumeAllDownloads log: " + string)

    def _onUserInterfaceInitialized(self, main_window: QMainWindow):
        self.main_window = main_window
        tabWidget = main_window.findChild(QTabWidget, "tabWidget")
        downloadTab = tabWidget.findChild(QWidget, "downloadTab")
        downloadView = downloadTab.findChild(QTreeView, "downloadView")
        if self.insert_buttons_in_download_tab:
            self.holder = downloadTab.findChild(QWidget, "refreshHolder")
            if not self.holder:
                self.refresh_button = downloadTab.findChild(QPushButton, "btnRefreshDownloads")
                self.widget_rep = QWidget()
                self.widget_rep.setObjectName("refreshHolder")
                downloadTab.layout().replaceWidget(self.refresh_button, self.widget_rep)
                layout = QHBoxLayout()
                self.widget_rep.setLayout(layout)
                layout.addWidget(self.refresh_button)
            else:
                layout = self.holder.layout()

            layout.addWidget(self.pause_button)
            layout.addWidget(self.resume_button)

        self.downloadView: QTreeView = downloadView
        self.selection_model = self.downloadView.selectionModel()
        self.event_filter = ContextMenuEventFilter(
            downloadView, 
            self
        )
        QApplication.instance().installEventFilter(self.event_filter)

    def _startRunning(self):
        self.resume_button.setEnabled(False)
        self.pause_button.setEnabled(False)
        self.is_running = True
        self.pending_files.clear()
        QApplication.restoreOverrideCursor()
        QApplication.setOverrideCursor(QCursor(WAIT_CURSOR))

    def _pauseAllDownloads(self):
        if self.is_running:
            return
        self._startRunning()
        self.is_pausing = True
        model = self.downloadView.model()
        rowCount = model.rowCount()
        rootIndex = self.downloadView.rootIndex()

        for row in range(0, rowCount):
            index = model.index(row, 0, rootIndex)
            item = index.sibling(index.row(), DOWNLOAD_COLUMN).data(Qt.ItemDataRole.DisplayRole)
            if item is None:
                file_name = index.sibling(index.row(), FILENAME_COLUMN).data(Qt.ItemDataRole.DisplayRole)
                if file_name:
                    self.pending_files.append(file_name)

        self._process_next_download()

    def _resumeAllDownloads(self):
        if self.is_running:
            return
        self._startRunning()
        self.is_resuming = True
        model = self.downloadView.model()
        rowCount = model.rowCount()
        rootIndex = self.downloadView.rootIndex()

        download_dir = self._organizer.downloadsPath()
        unfinished_downloads = []
        for file in os.listdir(download_dir):
            if file.endswith(".unfinished"):
                unfinished_downloads.append(file.removesuffix(".unfinished"))

        for row in range(0, rowCount):
            index = model.index(row, 0, rootIndex)
            item = index.sibling(row, DOWNLOAD_COLUMN).data(Qt.ItemDataRole.DisplayRole)
            file_name = index.sibling(row, FILENAME_COLUMN).data(Qt.ItemDataRole.DisplayRole)
            if item is not None and file_name in unfinished_downloads:
                self.pending_files.append(file_name)

        self._process_next_download()

    def _process_next_download(self):
        if not self.is_running:
            return
        if not self.pending_files:
            self.is_running = False
            self.is_pausing = False
            self.is_resuming = False
            self.resume_button.setEnabled(True)
            self.pause_button.setEnabled(True)
            self._log("Finished processing all downloads.")
            QApplication.restoreOverrideCursor()
            if hasattr(self, 'main_window') and self.main_window:
                self.main_window.activateWindow()
                self.main_window.raise_()
                self.downloadView.setFocus()
            return
        
        target_file = self.pending_files.pop(0)
        model = self.downloadView.model()
        rowCount = model.rowCount()
        rootIndex = self.downloadView.rootIndex()
        index = None
        for row in range(rowCount):
            idx = model.index(row, 0, rootIndex)
            name = idx.sibling(row, FILENAME_COLUMN).data(Qt.ItemDataRole.DisplayRole)
            if name == target_file:
                index = idx
                break

        if index is None or not index.isValid():
            self._log(f"Could not find {target_file} in view anymore! Skipping.")
            QTimer.singleShot(10, self._process_next_download)
            return

        self.selection_model.setCurrentIndex(index, SELECT_FLAG)
        self.downloadView.scrollTo(index)
        rect = self.downloadView.visualRect(index)
        center_pos = rect.center()
        self.downloadView.customContextMenuRequested.emit(center_pos)

def createPlugin():
    return PauseOrResumeAllDownloads()
