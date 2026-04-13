#Written by MaskPlague
import mobase
import os
import locale

try:
    from PyQt6.QtCore import QCoreApplication, QTimer, QRegularExpression, QObject, QEvent
    from PyQt6.QtGui import QIcon, QShortcut, QAction
    from PyQt6.QtWidgets import QFileDialog, QMessageBox, QApplication, QPushButton, QDialog, QMenu
except ImportError:
    from PyQt5.QtCore import QCoreApplication, QTimer, QRegularExpression, QObject, QEvent
    from PyQt5.QtGui import QIcon, QShortcut, QAction
    from PyQt5.QtWidgets import QFileDialog, QMessageBox, QApplication, QPushButton, QDialog, QMenu

DEFAULT_PREFIX = ""
DEFAULT_SUFFIX = ""
DEFAULT_SHORTCUT = "Ctrl+Shift+M"

class InstallButtonReplacer(QObject):

    def __init__(self, imm):
        super().__init__()
        self.next = False
        self.obtained = False
        self.menu: QMenu = None
        self.action = QAction("Install Mod(s)")
        self.action.triggered.connect(imm.display)

    def eventFilter(self, obj: QObject, event: QEvent) -> bool:
        if not self.obtained:
            if event.type() == QEvent.Type.MouseButtonPress and obj.objectName() == "listOptionsBtn":
                self.next = True
            elif self.next and isinstance(obj, QMenu):
                self.next = False
                self.obtained = True
                self.menu = obj
        elif event.type() == QEvent.Type.Show and obj == self.menu:
            self.menu.removeAction(self.menu.actions()[0])
            self.menu.insertAction(self.menu.actions()[0], self.action)
        return False
    
class IMMExtensionGetter(mobase.IPluginInstallerSimple):

    def __init__(self):
        super().__init__()
        return

    def init(self, organizer: mobase.IOrganizer) -> bool:
        self.__organizer = organizer
        self.__organizer.onUserInterfaceInitialized(self.__onUserInterfaceInitialized)
        return True
    
    def name(self) -> str:
        return "IMM: Extension Getter"
    
    def author(self) -> str:
        return "MaskPlague"
        
    def description(self) -> str:
        return self.__tr("This is not an installer and instead serves as a way for Install Multiple Mods to retrieve installable file extensions.")

    def version(self) -> mobase.VersionInfo:
        return mobase.VersionInfo(0, 0, 1, mobase.ReleaseType.FINAL)

    def settings(self) -> list[mobase.PluginSetting]:
        return [mobase.PluginSetting("Extensions", "Storage for installable extensions", "")]
        
    def install(self, mod_name, game_name, archive_name, version, nexus_id):
        return mobase.InstallResult.NOT_ATTEMPTED
    
    def is_archive_supported(self, tree: mobase.IFileTree) -> bool:
        return False
    
    def is_archive_supported(self, archive_name: str) -> bool:
        return False
    
    def supportedExtensions(self) -> set[str]:
        return set()
    
    def __tr(self, txt: str) -> str:
        return QApplication.translate(self.name(), txt)
        
    def __onUserInterfaceInitialized(self, mainWindow) -> None:
        print("*."+" *.".join(self._manager().getSupportedExtensions()))
        self.__organizer.setPluginSetting(self.name(), "Extensions", "*."+" *.".join(self._manager().getSupportedExtensions()))

    def priority(self):
        return 0


class InstallMultipleMods(mobase.IPluginTool):

    def __init__(self):
        super(InstallMultipleMods, self).__init__()
        self._parentWidget = None
    
    def init(self, organiser: mobase.IOrganizer):
        self._organizer = organiser
        self.app:QApplication = QApplication.instance()

        self._init_state()
        
        self._load_settings()
        
        self._setup_timers()
        
        self._compile_regex()

        self.shortcut = QShortcut(None)
        self.shortcut.activated.connect(self.display)
        self._organizer.onUserInterfaceInitialized(self._set_shortcut_parent)
        self._organizer.onUserInterfaceInitialized(self._setup_filter)
        self._organizer.onPluginSettingChanged(self.settings_update)
        return True

    def _init_state(self):
        self.num = 0
        self._queue_size = 0
        self._installing = False
        self.name_suggestion = ""
        self.IMM_closed = False
        self.timers_stopped = False
        self._modList = []
        self._queue = []
        self._fomods = []

    def _load_settings(self):
        self.replace_normal_button = self._get_setting("ReplaceInstallButton", False)
        self.name_prefix = self._get_setting("NamePrefix", DEFAULT_PREFIX)
        self.name_suffix = self._get_setting("NameSuffix", DEFAULT_SUFFIX)
        self.auto_install = self._get_setting("AutoQuickInstall", False)
        self.push_fomods_to_back = self._get_setting("PushFOMODsBack", True)
        self.use_file_name = self._get_setting("UseFileName", True)
        self.only_use_file_name = self._get_setting("OnlyUseFileName", False)
        self.shortcut_text = self._get_setting("Shortcut", DEFAULT_SHORTCUT)
        self.downloadLocation = self._get_setting("LastPath", "downloads")

        self._queue = self._get_list_setting("Queue")
        self._fomods = self._get_list_setting("Fomods")

    def _setup_timers(self):
        self.timer = self._create_timer(200, self.timeout)
        self.fmod_check_timer = self._create_timer(100, self.check_for_fomods)
        self.auto_install_timer = self._create_timer(100, self.auto_install_quick_install)

    def _compile_regex(self):
        self.complex_regex = QRegularExpression(
            r"(^([a-zA-Z0-9_'\"\-.() ]*?)([-_ ][VvRr]+[0-9]+(?:(?:[\.][0-9]+){0,2}|(?:[_][0-9]+){0,2}|(?:[-.][0-9]+){0,2})?[ab]?)??-([1-9][0-9]+)?-.*?\.(zip|rar|7z))"
        )
        self.simple_regex = QRegularExpression(r"(^[^a-zA-Z]*([a-zA-Z_ ]+))")

    def _get_setting(self, name, default=None):
        value = self._organizer.pluginSetting(self.name(), name)
        return value if value is not None else default

    def _get_list_setting(self, setting_name):
        list_str = self._get_setting(setting_name, "")
        if not list_str:
            return []
        return [mod for mod in list_str.split("|||") if mod]

    def _create_timer(self, interval, callback):
        timer = QTimer()
        timer.setInterval(interval)
        timer.timeout.connect(callback)
        timer.stop()
        return timer

    def _setup_filter(self, parent):
        if self.replace_normal_button:
            self.replacer = InstallButtonReplacer(self)
            QApplication.instance().installEventFilter(self.replacer)

    def name(self) -> str:
        return "Install Mod(s)"
    
    def localizedName(self) -> str:
        return self.tr("Install Mod(s)")
    
    def author(self) -> str:
        return "MaskPlague"

    def description(self):
        return self.tr("Allows manual selection of multiple archives for seqeuential installation.")
    
    def version(self) -> mobase.VersionInfo:
        return mobase.VersionInfo(0, 1, 5, mobase.ReleaseType.FINAL)
    
    def settings(self):
        return [
            mobase.PluginSetting("ReplaceInstallButton", 
                                  self.tr("Replace the normal \"Install Mod...\" button in the list options drop down. (Requires MO2 restart after toggle.)"), 
                                  False),
            mobase.PluginSetting("LastPath", self.tr("Last opened path for installing."), "downloads"),
            mobase.PluginSetting("NamePrefix", self.tr("Prefix added to the beginning of mod names"), DEFAULT_PREFIX),
            mobase.PluginSetting("NameSuffix", self.tr("Suffix added to the end of mod names"), DEFAULT_SUFFIX),
            mobase.PluginSetting("AutoQuickInstall", self.tr("Automatically Install Non-FOMOD mods"), False),
            mobase.PluginSetting("PushFOMODsBack", 
                                  self.tr("When a FOMOD is encountered with AutoQuickInstall active, push the mod to the back of the queue"),
                                  True),
            mobase.PluginSetting("UseFileName", self.tr("Use the file name as the suggestion when a file is not from Nexus"), True),
            mobase.PluginSetting("OnlyUseFileName", self.tr("Only use the file name as the suggestion"), False),
            mobase.PluginSetting("Shortcut", self.tr("Shortcut to install multiple mods"), DEFAULT_SHORTCUT),
            mobase.PluginSetting("Queue", self.tr("Holder for the install queue (NOT A SETTING)"), ""),
            mobase.PluginSetting("Fomods", self.tr("Holder for fomods (NOT A SETTING)"), "")
            ]
    
    def displayName(self):
        locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')
        return self.tr(f"Install Mod(s)\t({self.shortcut_text})")
    
    def tooltip(self):
        return self.tr("")
    
    def icon(self):
        return QIcon()
    
    def display(self):
        if len(self._queue) != 0:
            result = QMessageBox.question(None, "Resume?", "Would you like to resume from the previous install session?")
            if result == QMessageBox.StandardButton.Yes:
                self.try_installing_mods()
                return
            else:
                self._fomods.clear()
                self._queue.clear()
                self._organizer.setPluginSetting(self.name(), "Queue", '')
                self._organizer.setPluginSetting(self.name(), "Fomods", '')
        filter = "Mod Archives (" + self._organizer.pluginSetting("IMM: Extension Getter", "Extensions") + ")" 
        self._queue = QFileDialog.getOpenFileNames(
            self._parentWidget,
            "Open File",
            self.downloadLocation,
            filter,
        )[0]
        if len(self._queue) > 0:
            pathGet = self._queue[0]
            self.downloadLocation = os.path.split(os.path.abspath(pathGet))[0]
            self._organizer.setPluginSetting(self.name(), "LastPath", self.downloadLocation)
        self.try_installing_mods()
        return

    def tr(self, str):
        return QCoreApplication.translate("Install Mod(s)", str)
    
    def _set_shortcut_parent(self, parent):
        self.shortcut.setParent(parent)
        self.shortcut.setKey(self.shortcut_text)

    def settings_update(self, plugin, setting_changed, _3, new_val):
        if plugin == self.name():
            if setting_changed == "NamePrefix":
                self.name_prefix = new_val
            elif setting_changed == "NameSuffix":
                self.name_suffix = new_val
            elif setting_changed == "AutoQuickInstall":
                self.auto_install = new_val
            elif setting_changed == "PushFOMODsBack":
                self.push_fomods_to_back = new_val
            elif setting_changed == "UseFileName":
                self.use_file_name = new_val
            elif setting_changed == "OnlyUseFileName":
                self.only_use_file_name = new_val
            elif setting_changed == "Shortcut":
                self.shortcut.setKey(new_val)
                self.shortcut_text = new_val

    def try_installing_mods(self):
        if not self._installing:
            self._installing = True
            self.timer.start()
            self._queue_size = len(self._queue)
            self.num = 0
            self._make_messageBox()
        return
    
    def _make_messageBox(self):
        self.messageBox = QMessageBox()
        self.messageBox.setWindowTitle("Install Multiple Mods")
        self._update_messageBox_text()
        def continue_installing():
            self.timer.start()
            self.messageBox.show()

        def exit():
            self.timer.stop()
            self.auto_install_timer.stop()
            self.fmod_check_timer.stop()
            self._installing = False
            self.messageBox.hide()

        def cancel():
            self._queue.clear()
            self._organizer.setPluginSetting(self.name(), "Queue",  '')
            self._organizer.setPluginSetting(self.name(), "Fomods", '')
            exit()

        def clicked():
            button = self.messageBox.clickedButton()
            role = self.messageBox.buttonRole(button)
            if role == QMessageBox.ButtonRole.AcceptRole:
                continue_installing()
            elif role == QMessageBox.ButtonRole.ApplyRole:
                cancel()
            elif role == QMessageBox.ButtonRole.RejectRole:
                exit()

        self.continueBtn = self.messageBox.addButton("Continue", QMessageBox.ButtonRole.AcceptRole)
        self.messageBox.addButton("Pause/Exit", QMessageBox.ButtonRole.RejectRole)
        self.messageBox.addButton("Clear/Cancel", QMessageBox.ButtonRole.ApplyRole)
        self.messageBox.buttonClicked.connect(clicked)
        self.messageBox.setDefaultButton(self.continueBtn)
        self.messageBox.show()
    
    def _update_messageBox_text(self):
        self.messageBox.setText(f"Installing {self.num}/{self._queue_size}\n"+
                                "In this Window (accessible after cancelling an install): "+
                                "\n - Continue to resume."+
                                "\n - Pause/Exit to exit and resume another time."+
                                "\n      (If MO2 froze, select this and restart)"+
                                "\n - Clear/Cancel to clear the queue and exit.")
        
    def check_for_fomods(self):
        self.fmod_check_timer.stop()
        
        target_widget = None
        is_regular_fomod = False

        for widget in self.app.topLevelWidgets():
            if widget.windowTitle() != self.name_suggestion:
                continue

            # Regular FOMOD installer
            if widget.objectName() == "FomodInstallerDialog":
                target_widget = widget
                is_regular_fomod = True
                break
            
            # FomodPlusPlus, QDialog with mod name as title, has no object name :/
            if isinstance(widget, QDialog):
                target_widget = widget
                is_regular_fomod = False
                break

        if target_widget:
            should_close = (
                self.auto_install 
                and self.push_fomods_to_back
                and self.name_suggestion not in self._fomods
                and len(self._fomods) < len(self._queue)
                and self._queue_size > 1
            )
            
            if should_close:
                self.IMM_closed = True
                self._click_cancel_button(target_widget, is_regular_fomod)
            elif not is_regular_fomod:
                self.messageBox.hide()
            return

        for window in self.app.topLevelWindows():
            if window.objectName() == "FomodInstallerWindowClassWindow":
                self.messageBox.hide()
                return
            
        if not self.timers_stopped:
            self.fmod_check_timer.start()

    def _click_cancel_button(self, widget:QDialog, is_standard:bool):
        try:
            if is_standard:
                cancel_btn = widget.findChild(QPushButton, "cancelBtn")
                if cancel_btn:
                    cancel_btn.click()
            else:
                # FomodPlusPlus, last button should be cancel
                buttons = widget.findChildren(QPushButton)
                if buttons:
                    buttons[-1].click()
        except Exception:
            pass

    def auto_install_quick_install(self):
        self.auto_install_timer.stop()
        found = False
        for widget in self.app.topLevelWidgets():
            if widget.objectName() == "SimpleInstallDialog":
                okBtn = widget.findChild(QPushButton, "okBtn")
                if okBtn:
                    found = True
                    okBtn.click()
                break

        if not found and self.auto_install and not self.timers_stopped:
            self.auto_install_timer.start()

    def timeout(self):
        self.timer.stop()
        if not self._installing or not self._queue:
            self._finish_installation()
            return

        path = self._queue[0]
        base_name = self._get_mod_name(os.path.basename(path))
        self.name_suggestion = f"{self.name_prefix}{base_name}{self.name_suffix}"
        
        self.num += 1
        self._save_queue() 
        self._update_ui_state(processing=True)

        # Start check timers (Fomod timer is necessary since messageBox doesn't go behind fomodPlusPlus)
        self.fmod_check_timer.start()
        if self.auto_install:
            self.auto_install_timer.start()
        self.timers_stopped = False

        handler = self._organizer.installMod(path, name_suggestion=self.name_suggestion)

        self.timers_stopped = True
        self.fmod_check_timer.stop()
        self.auto_install_timer.stop()
        self.continueBtn.setEnabled(False)

        if handler is not None:
            self._handle_install_success()
        elif self.IMM_closed:
            self._handle_fomod_cycle()
        else:
            self._handle_install_cancelled(path)
        
        self._make_messageBox()

    def _get_mod_name(self, file_name: str):
        if self.only_use_file_name:
            return os.path.splitext(file_name)[0]
        complex_match = self.complex_regex.match(file_name)
        simple_match = self.simple_regex.match(file_name)
        if complex_match.hasMatch():
            return complex_match.captured(2)
        elif self.use_file_name:
            return os.path.splitext(file_name)[0]
        elif simple_match.hasMatch():
            return simple_match.captured(1)
        else:
            return file_name

    def _handle_install_success(self):
        self._queue.pop(0)
        self._save_queue()
        
        # Clean up FOMOD list if this mod was previously flagged
        if self.name_suggestion in self._fomods:
            self._fomods.remove(self.name_suggestion)
            self._save_fomods()

        # Continue to next mod
        self.timer.start()

    def _handle_fomod_cycle(self):
        self.IMM_closed = False # Reset flag
        
        # Mark as FOMOD so we know next time
        if self.name_suggestion not in self._fomods:
            self._fomods.append(self.name_suggestion)
            self._save_fomods()

        # Move current mod to the back of the queue
        current_mod = self._queue.pop(0)
        self._queue.append(current_mod)
        self._save_queue()

        self.num -= 1 # Correct count since we didn't finish this one
        self.timer.start()

    def _handle_install_cancelled(self, path):
        ret = QMessageBox.question(
            None, 
            "Install Multiple Mods: Remove from Queue?",
            f"Would you like to remove {os.path.basename(path)} from the install queue?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )

        if ret == QMessageBox.StandardButton.Yes:
            self._queue.pop(0)
            self._save_queue()
            
            if self.name_suggestion in self._fomods:
                self._fomods.remove(self.name_suggestion)
                self._save_fomods()
            self.timer.start() 
        else:
            self.num -= 1

    def _finish_installation(self):
        self._installing = False
        self.num = 0
        if self.messageBox:
            self.messageBox.hide()
        self.fmod_check_timer.stop()
        self.auto_install_timer.stop()

    def _update_ui_state(self, processing=True):
        if self.messageBox:
            self._update_messageBox_text()
        self.continueBtn.setEnabled(not processing)

    def _save_queue(self):
        self._organizer.setPluginSetting(self.name(), "Queue", '|||'.join(self._queue))

    def _save_fomods(self):
        self._organizer.setPluginSetting(self.name(), "Fomods", '|||'.join(self._fomods))

def createPlugins():
    return [InstallMultipleMods(), IMMExtensionGetter()]