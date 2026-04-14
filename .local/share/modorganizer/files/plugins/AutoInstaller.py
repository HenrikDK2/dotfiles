#Written by MaskPlauge
import mobase
import time
import queue

try:
    from PyQt6.QtCore import QCoreApplication
    from PyQt6.QtGui import QIcon
except:
    from PyQt5.QtCore import QCoreApplication
    from PyQt5.QtGui import QIcon

class AutoInstaller(mobase.IPluginTool):

    def __init__(self):
        super(AutoInstaller, self).__init__()
        self._parentWidget = None
    
    def init(self, organiser = mobase.IOrganizer):
        self.debug = False
        self.num = 0
        self.finished = True
        self._organizer = organiser
        self.download_manager: mobase.IDownloadManager = self._organizer.downloadManager()
        self._icoPath = self._organizer.getPluginDataPath().replace("data", "AutoInstaller")
        self._queue = queue.Queue()
        self.handler = None
        self.download_manager.onDownloadComplete(lambda idNum: self._install(idNum))
        return True

    def name(self) -> str:
        return "AutoInstaller"
    
    def localizedName(self) -> str:
        return self.tr("AutoInstaller")
    
    def author(self) -> str:
        return "MaskPlague"

    def description(self):
        return self.tr("Automatically installs downloaded mods into current profile's modlist.")
    
    def version(self) -> mobase.VersionInfo:
        return mobase.VersionInfo(1, 0, 1, mobase.ReleaseType.ALPHA)
    
    def settings(self):
        return [
            mobase.PluginSetting("enableInstall", self.tr("Enable or Disable auto installation of downloaded mods."), True),
            ]
    
    def displayName(self):
        return self.tr("AutoInstaller")
    
    def tooltip(self):
        return self.tr("Toggles AutoInstaller")
    
    def icon(self):
        if bool(self._organizer.pluginSetting(self.name(), "enableInstall")):
            return QIcon(self._icoPath + "/green.ico")
        else:
            return QIcon(self._icoPath + "/red.ico")
    
    def display(self):
        if bool(self._organizer.pluginSetting(self.name(), "enableInstall")):
            self._organizer.setPluginSetting(self.name(), "enableInstall", False)
            while not self._queue.empty():
                self._queue.get()
        else:
            self._organizer.setPluginSetting(self.name(), "enableInstall", True)
        return

    def tr(self, str):
        return QCoreApplication.translate("AutoInstaller", str)
    
    def _log(self, string): #for debugging
        if self.debug:
            print("AutoInstaller log" + str(self.num) + ": " + string)
            self.num += 1

    def _install(self, idNum: int):
        if bool(self._organizer.pluginSetting(self.name(), "enableInstall")):
            path = self.download_manager.downloadPath(idNum)
            self._queue.put(path)
        
        if self.finished and bool(self._organizer.pluginSetting(self.name(), "enableInstall")) and not self._queue.empty():
            self._installQueue()

    def _installQueue(self):
        self.finished = False
        while not self._queue.empty():
            path = self._queue.get()
            self.handler = self._organizer.installMod(path)
            if self.handler != None:
                time.sleep(0.2)
            self._installQueue()
        self.finished = True

def createPlugin():
    return AutoInstaller()
