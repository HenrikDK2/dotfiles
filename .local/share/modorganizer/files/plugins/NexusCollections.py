import mobase
import json
import logging
import re
import urllib.request
from PyQt6.QtCore import *
from PyQt6.QtGui import *
from PyQt6.QtWidgets import *

class NexusCollections(mobase.IPluginTool):
    def __init__(self):
        super().__init__()
        self._organizer = None
        self._parent = None

    def __tr(self, str_):
        return QCoreApplication.translate(self.name(), str_)

    def init(self, organizer):
        self._organizer = organizer
        self._organizer.onUserInterfaceInitialized(self.onUserInterfaceInitializedCallback)
        return True

    def name(self):
        return "Nexus Collections Downloader"

    def author(self):
        return "Kojillama (patched by Drew + Eva)"

    def description(self):
        return self.__tr("Downloads collections from Nexus Mods in MO2")

    def version(self):
        return mobase.VersionInfo(1, 0, 0, 1)

    def isActive(self):
        return self._organizer.pluginSetting(self.name(), "enabled")

    def settings(self):
        return [mobase.PluginSetting("enabled", self.__tr("Enables the plugin"), True)]

    def displayName(self):
        return self.__tr("Download Nexus Collection")

    def tooltip(self):
        return self.__tr("")

    def icon(self):
        return QIcon()

    def setParentWidget(self, widget):
        self._parent = widget

    def display(self) -> None:
        self._dialogInitial.show()

    def onUserInterfaceInitializedCallback(self, main_window: "QMainWindow"):
        self._dialogInitial = self.dialogInitial(main_window)
        self._dialogLoading = self.dialogLoading(main_window)

    def queryNexus(self, payload):
        headers = {
            "User-Agent": "Mozilla/5.0",
            "Content-type": "application/json",
            "Accept": "application/json",
        }
        json_data = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request("https://api.nexusmods.com/v2/graphql", data=json_data, headers=headers)
        try:
            with urllib.request.urlopen(request) as response:
                content = response.read()
                resp = json.loads(content)
                logging.warning(resp)
                return resp.get("data")
        except urllib.error.HTTPError as e:
            logging.error(f"HTTPError: {e}")
            return None
        except urllib.error.URLError as e:
            logging.error(f"URLError: {e}")
            return None

    def getCollection(self):
        data = self.getCollectionFiles()
        if data and data["collectionRevision"]["modFiles"]:
            for mod in data["collectionRevision"]["modFiles"]:
                mod_id = int(mod["file"]["mod"]["modId"])
                file_id = int(mod["fileId"])
                self._organizer.downloadManager().startDownloadNexusFile(mod_id, file_id)

    def getCollectionRevisions(self):
        payload = {
            "query": "query CollectionRevisions ($domainName: String, $slug: String!) { collection (domainName: $domainName, slug: $slug) { revisions { adultContent, createdAt, discardedAt, id, latest, revisionNumber, revisionStatus, totalSize, collectionChangelog { description, id } } } }",
            "variables": {
                "domainName": self.gameId,
                "slug": self.collectionId
            },
            "operationName": "CollectionRevisions"
        }
        return self.queryNexus(payload)

    def getCollectionFiles(self):
        payload = {
            "query": "query CollectionRevisionMods ($revision: Int, $slug: String!, $viewAdultContent: Boolean) { collectionRevision (revision: $revision, slug: $slug, viewAdultContent: $viewAdultContent) { externalResources { id, name, resourceType, resourceUrl }, modFiles { fileId, optional, file { fileId, name, scanned, size, sizeInBytes, version, mod { adult, author, category, modId, name, pictureUrl, summary, version, game { domainName }, uploader { avatar, memberId, name } } } } } }",
            "variables": {
                "revision": self.collectionRevision,
                "slug": self.collectionId,
                "viewAdultContent": True
            },
            "operationName": "CollectionRevisionMods"
        }
        return self.queryNexus(payload)

    def dialogLoading(self, main_window: "QMainWindow") -> "QDialog":
        dialog = QDialog(main_window)
        dialog.setWindowTitle("Loading...")
        dialog.resize(200, 1)

        label = QLabel('Loading...')
        layout = QVBoxLayout()
        layout.addWidget(label)
        dialog.setLayout(layout)

        return dialog

    def dialogFiles(self, main_window: "QMainWindow") -> "QDialog":
        def next():
            for file in self.files["essential"]:
                mod_id = int(file["file"]["mod"]["modId"])
                file_id = int(file["fileId"])
                self._organizer.downloadManager().startDownloadNexusFile(mod_id, file_id)
            self._dialogFiles.close()

        self._dialogLoading.show()

        filesData = self.getCollectionFiles()
        self.files = {
            "essential": [],
            "optional": [],
            "external": [],
            "bundle": []
        }

        if filesData:
            for file in filesData["collectionRevision"]["modFiles"]:
                (self.files["optional"] if file["optional"] else self.files["essential"]).append(file)
            for file in filesData["collectionRevision"]["externalResources"]:
                (self.files["external"] if file["resourceUrl"] else self.files["bundle"]).append(file)

        dialog = QDialog(main_window)
        dialog.setWindowTitle("Collection Files")
        dialog.resize(500, 100)

        label = QLabel('This collection contains:')
        labelEssential = QLabel(f'   {len(self.files["essential"])} essential mod(s)')
        labelOptional = QLabel(f'   {len(self.files["optional"])} optional mod(s)')
        labelExternal = QLabel(f'   {len(self.files["external"])} external file(s)')
        labelBundle = QLabel(f'   {len(self.files["bundle"])} bundled file(s)')

        labelStatus = QLabel("\nTHE CURRENT VERSION OF THIS PLUGIN WILL ONLY DOWNLOAD ESSENTIAL MODS.")
        labelStatus.setStyleSheet("font-weight: bold; color: red")
        labelUpdate = QLabel('More functionality coming soon!')

        button = QPushButton('Download')
        button.clicked.connect(next)

        layout = QVBoxLayout()
        layout.addWidget(label)
        layout.addWidget(labelEssential)
        layout.addWidget(labelOptional)
        layout.addWidget(labelExternal)
        layout.addWidget(labelBundle)
        layout.addWidget(labelStatus)
        layout.addWidget(labelUpdate)
        layout.addWidget(button)
        dialog.setLayout(layout)

        self._dialogLoading.close()
        return dialog

    def dialogRevisions(self, main_window: "QMainWindow") -> "QDialog":
        def next():
            self.collectionRevision = int(self.revisionList.currentText().replace('Revision ', '').split(' (')[0])
            self._dialogRevisions.close()
            self._dialogFiles = self.dialogFiles(main_window)
            self._dialogFiles.show()

        self._dialogLoading.show()

        dialog = QDialog(main_window)
        dialog.setWindowTitle("Collection Revisions")
        dialog.resize(500, 100)

        label = QLabel('Select the collection revision you want to download.')
        self.revisionList = QComboBox()
        revisionData = self.getCollectionRevisions()
        if revisionData:
            for rev in revisionData["collection"]["revisions"]:
                revDate = rev["createdAt"].split("T")[0]
                self.revisionList.addItem(f"Revision {rev['revisionNumber']} ({revDate})")

        button = QPushButton('Next')
        button.clicked.connect(next)

        layout = QVBoxLayout()
        layout.addWidget(label)
        layout.addWidget(self.revisionList)
        layout.addWidget(button)
        dialog.setLayout(layout)

        self._dialogLoading.close()
        return dialog

    def dialogInitial(self, main_window: "QMainWindow") -> "QDialog":
        def next():
            nexusUrl = self.nexusUrl.text()
            pattern = r"nexusmods\.com\/games\/(.*?)\/collections\/(.*?)(?:\?.*)?$"
            match = re.search(pattern, nexusUrl)
            if match:
                self.gameId = match.group(1)
                self.collectionId = match.group(2)
                self._dialogInitial.close()
                self._dialogRevisions = self.dialogRevisions(main_window)
                self._dialogRevisions.show()

        dialog = QDialog(main_window)
        dialog.setWindowTitle("Insert Nexus Collection URL")
        dialog.resize(500, 100)

        label = QLabel('Paste the full URL of the Nexus collection you wish to download.\nYou MUST have Nexus Premium and be logged in for this to work!')
        self.nexusUrl = QLineEdit()

        button = QPushButton('Next')
        button.clicked.connect(next)

        layout = QVBoxLayout()
        layout.addWidget(label)
        layout.addWidget(self.nexusUrl)
        layout.addWidget(button)
        dialog.setLayout(layout)

        return dialog

def createPlugin():
    return NexusCollections()
