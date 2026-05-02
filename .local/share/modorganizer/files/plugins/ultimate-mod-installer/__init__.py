import mobase
import os
import site

site.addsitedir(os.path.join(os.path.dirname(__file__), "lib"))

from .ultimate_mod_installer import UMIPlugin

def createPlugin() -> mobase.IPlugin:
    return UMIPlugin()