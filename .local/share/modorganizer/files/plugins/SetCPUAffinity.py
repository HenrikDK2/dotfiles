# coding=utf-8

import fileinput
import multiprocessing
from typing import List, Sequence, Union

import mobase

try:
    import PyQt5.QtGui as QtGui
    import PyQt5.QtWidgets as QtWidgets
    from PyQt5.QtCore import QCoreApplication
    StandardButton = QtWidgets.QMessageBox
except:
    import PyQt6.QtGui as QtGui
    import PyQt6.QtWidgets as QtWidgets
    from PyQt6.QtCore import QCoreApplication
    QIcon = QtGui.QIcon
    QWidget = QtWidgets.QWidget
    QMessageBox = QtWidgets.QMessageBox
    StandardButton = QtWidgets.QMessageBox.StandardButton


class SetCPUAffinity(mobase.IPluginTool):
    NAME = "SetCPUAffinity"
    DISPLAY_NAME = "Set CPU Affinity"
    DESCRIPTION = "Automatically calculates and sets the CPU affinity for Skyrim Priority SE AE - skse plugin by Boring3."
    TOOLTIP = "Sets CPU affinity in SKSE\\Plugins\\PriorityMod.toml."


    def __init__(self):
        super().__init__()
        self.__organizer: Union[mobase.IOrganizer, None] = None
        self.__config_path: str = ''

    def init(self, organizer: mobase.IOrganizer):
        self.__organizer = organizer
        return True

    def name(self) -> str:
        return self.NAME

    def author(self) -> str:
        return "MaskedRPGFan"

    def description(self) -> str:
        return self.__tr(self.DESCRIPTION)

    def version(self) -> mobase.VersionInfo:
        return mobase.VersionInfo(1, 2, 0)

    def isActive(self) -> bool:
        return self.__organizer.pluginSetting(self.name(), "enabled") is True

    def settings(self) -> List[mobase.PluginSetting]:
        return [mobase.PluginSetting("enabled", self.__tr("Enable this plugin"), True)]

    def displayName(self) -> str:
        return self.__tr(self.DISPLAY_NAME)

    def tooltip(self) -> str:
        return self.__tr(self.TOOLTIP)

    def icon(self) -> QIcon:
        return QIcon()

    def setParentWidget(self, widget: QWidget) -> None:
        self.__parentWidget = widget

    def __findTomlConfig(self) -> str:
        grassPluginPath = "SKSE/Plugins/"
        grassPlugin = "PriorityMod.toml"
        result: Sequence[str] = self.__organizer.findFiles(grassPluginPath, grassPlugin)
        return result[0] if len(result) > 0 else ''

    def display(self) -> None:
        self.__config_path = self.__findTomlConfig()
        if self.__config_path == '':
            QMessageBox.critical(self.__parentWidget,
                                 self.__tr('PriorityMod.toml is missing'),
                                 self.__tr("<a href='https://www.nexusmods.com/skyrimspecialedition/mods/50129'>"
                                           "Skyrim Priority SE AE - skse plugin</a> mod not found or enabled. "
                                           "Please install and enable the mod and refresh MO2."))
            return
        current_affinity: str = self.__getCurrentAffinity()

        if current_affinity == '0':
            affinity: str = self.__calculateAffinity()
            question: str = self.__tr('Current CPU affinity is not set (0).\nYou have {0} logical processors.\nDo you want to change CPU affinity to: {1}?')
            response: QMessageBox = QMessageBox.question(self.__parentWidget, self.__tr('CPU Affinity not set (0)'),
                                                         question.format(multiprocessing.cpu_count(), affinity),
                                                         StandardButton.Ok | StandardButton.No, StandardButton.Ok)
            if response == StandardButton.Ok:
                self.__setAffinity(affinity)
                QMessageBox.information(self.__parentWidget, self.__tr('Success'), self.__tr('Done! Your CPU affinity is now {0}.').format(affinity))
        elif current_affinity != '':
            question: str = self.__tr('Current CPU affinity is set to {0}.\nDo you want to disable it by setting the value to 0?')
            response: QMessageBox = QMessageBox.question(self.__parentWidget, self.__tr('CPU Affinity is {0}').format(current_affinity),
                                                         question.format(current_affinity),
                                                         StandardButton.Ok | StandardButton.No, StandardButton.Ok)
            if response == StandardButton.Ok:
                self.__setAffinity('0')
                QMessageBox.information(self.__parentWidget, self.__tr('Success'), self.__tr('Done! Your CPU affinity is now 0.'))

    def __getCurrentAffinity(self) -> str:
        if self.__config_path == '':
            return ''

        results: List[str] = [line for line in open(self.__config_path) if line.startswith("affinity")]
        return '' if len(results) == 0 else results[0].partition('=')[2].strip()

    def __calculateAffinity(self) -> str:
        value:str = f'{int("".join([("1" if i != 1 and i != 3 else "0") for i in reversed(range(multiprocessing.cpu_count()))]), 2):x}'.upper()
        return "0x" + f'{value:0>16}'

    def __setAffinity(self, affinity: str = '0') -> None:
        if self.__config_path == '':
            return
        found: bool = False
        for line in fileinput.input(self.__config_path, inplace=True):
            if not found and line.startswith("affinity"):
                print(f'affinity = {affinity}\n', end='')
                found = True
            else:
                print(f'{line}', end='')

    def __tr(self, str):
        return QCoreApplication.translate(self.NAME, str)


def createPlugin() -> mobase.IPlugin:
    return SetCPUAffinity()
