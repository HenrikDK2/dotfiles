# -*- coding: utf-8 -*-
"""
FOMOD Choice Logger - Completely Self-Contained
================================================
Tracks FOMOD installation choices and displays them in an auto-launching web interface.
No external files needed - everything is embedded in this plugin.

Features:
- Automatically detects FOMOD installations
- Deduces choices by comparing installed files to FOMOD XML
- Stores data in SQLite database
- Auto-launches web browser on MO2 startup
- Real-time updates (3-second refresh)
- Search and filter functionality
- One entry per mod (updates on reinstall, removes on uninstall)

Installation: Just drop this file in plugins folder. That's it.
"""

import mobase
import os
import json
import re
import zipfile
import xml.etree.ElementTree as ET
import webbrowser
import http.server
import socketserver
import threading
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional, Set
from collections import defaultdict


class FomodLogger(mobase.IPluginDiagnose, mobase.IPluginTool):
    """Self-contained plugin to track and display FOMOD installation choices."""
    
    def __init__(self):
        mobase.IPluginDiagnose.__init__(self)
        mobase.IPluginTool.__init__(self)
        self._organizer: Optional[mobase.IOrganizer] = None
        self._data_path: Optional[Path] = None
        self._server_started = False
        
    def init(self, organizer: mobase.IOrganizer) -> bool:
        """Initialize the plugin and start web server."""
        self._organizer = organizer
        
        # Check for FOMOD Plus conflict
        self._check_fomod_plus_conflict()
        
        # Handle DLL installation safely
        self._install_dll_safely()
        
        # Set up JSON data path
        base_path = Path(self._organizer.basePath())
        self._data_path = base_path / "fomod_data.json"
        
        # Create empty data file ONLY if it truly doesn't exist
        # CRITICAL: Never overwrite existing data!
        if not self._data_path.exists():
            try:
                with open(self._data_path, 'w', encoding='utf-8') as f:
                    json.dump({'mods': [], 'cross_patches': []}, f, indent=2)
            except:
                pass  # If can't create, C++ DLL will handle it
        
        # Connect to mod events - ONLY for uninstall tracking
        # (C++ DLL now handles FOMOD choice logging on install)
        try:
            mod_list = self._organizer.modList()
            # mod_list.onModInstalled(self._on_mod_installed)  # DISABLED - C++ handles this
            mod_list.onModRemoved(self._on_mod_removed)
        except Exception as e:
            pass  # Ignore if event connection fails
        
        # Start web server
        self._start_web_server(open_browser=False)
        
        # Auto-open browser if setting is enabled
        auto_open = self._organizer.pluginSetting(self.name(), "auto_open_browser")
        if auto_open:
            import time
            time.sleep(0.5)
            webbrowser.open("http://127.0.0.1:8080")
        
        return True
    
    def _install_dll_safely(self):
        """
        Safely install our custom FOMOD DLL with automatic backup and restore.
        
        This replaces MO2's installer_fomod.dll with our version that logs choices.
        On first run, backs up the original. On uninstall, restores it automatically.
        """
        import shutil
        
        try:
            plugins_path = Path(self._organizer.pluginsPath())
            base_path = Path(self._organizer.basePath())
            
            # Our custom DLL (stored alongside Python plugin with unique name)
            custom_dll = plugins_path / "installer_fomod_logger.dll"
            
            # MO2's actual DLL (the one it loads)
            active_dll = plugins_path / "installer_fomod.dll"
            
            # Backup of original MO2 DLL
            backup_dll = plugins_path / "installer_fomod_original.dll"
            
            # First run: Back up original MO2 DLL if not already backed up
            if not backup_dll.exists() and active_dll.exists():
                # Only backup if it's NOT our version (check file size)
                # Our UPX-packed version is ~154-158KB, original is usually larger
                active_size = active_dll.stat().st_size
                
                # If there's a custom DLL, check if active is different
                if custom_dll.exists():
                    custom_size = custom_dll.stat().st_size
                    # If active is larger than custom, it's probably the original
                    if active_size > custom_size * 1.1:  # 10% margin
                        shutil.copy2(active_dll, backup_dll)
                else:
                    # No custom DLL yet, so active must be original
                    shutil.copy2(active_dll, backup_dll)
            
            # Install our custom DLL if it exists and differs from active
            if custom_dll.exists():
                # Check if we need to swap (compare file sizes as quick check)
                if not active_dll.exists() or active_dll.stat().st_size != custom_dll.stat().st_size:
                    shutil.copy2(custom_dll, active_dll)
            
        except Exception as e:
            # Don't break plugin if DLL management fails
            # User might need to manually place DLL
            pass
    
    def _restore_original_dll(self):
        """Restore original MO2 DLL on plugin uninstall."""
        import shutil
        
        try:
            plugins_path = Path(self._organizer.pluginsPath())
            
            active_dll = plugins_path / "installer_fomod.dll"
            backup_dll = plugins_path / "installer_fomod_original.dll"
            
            # Restore original if backup exists
            if backup_dll.exists() and active_dll.exists():
                shutil.copy2(backup_dll, active_dll)
                # Clean up our custom DLL
                custom_dll = plugins_path / "installer_fomod_logger.dll"
                if custom_dll.exists():
                    custom_dll.unlink()
                
        except Exception as e:
            pass
    
    def _check_fomod_plus_conflict(self):
        """Check if FOMOD Plus is installed and warn user."""
        try:
            plugins_path = Path(self._organizer.pluginsPath())
            
            # Check for FOMOD Plus files
            fomod_plus_files = [
                'fomod_plus.py',
                'installerfomod_plus.dll',
                'FOMOD Plus.py'
            ]
            
            detected = []
            for file in fomod_plus_files:
                if (plugins_path / file).exists():
                    detected.append(file)
            
            if detected:
                msg = (
                    "⚠️ FOMOD Plus Conflict Detected!\n\n"
                    f"Found: {', '.join(detected)}\n\n"
                    "FOMOD Plus and FOMOD Choice Logger both replace MO2's FOMOD installer DLL. "
                    "Only one can work at a time.\n\n"
                    "Current status: FOMOD Choice Logger is loaded and will auto-manage the DLL.\n\n"
                    "Choose one:\n"
                    "• Keep FOMOD Choice Logger: Remove FOMOD Plus\n"
                    "• Keep FOMOD Plus: Disable FOMOD Choice Logger\n\n"
                    "Note: Original MO2 DLL is automatically backed up as 'installer_fomod_original.dll'"
                )
                
                # Show warning dialog
                from PyQt6.QtWidgets import QMessageBox
                msgBox = QMessageBox()
                msgBox.setIcon(QMessageBox.Icon.Warning)
                msgBox.setWindowTitle("Plugin Conflict Warning")
                msgBox.setText(msg)
                msgBox.exec()
                
        except Exception as e:
            pass  # Don't break plugin if check fails
    
    def name(self) -> str:
        return "FOMOD Tracker"
    
    def author(self) -> str:
        return "Custom Plugin"
    
    def description(self) -> str:
        return "Tracks FOMOD installation choices with web-based viewer. Completely self-contained."
    
    def version(self) -> mobase.VersionInfo:
        return mobase.VersionInfo(2, 0, 0)
    
    def settings(self) -> List[mobase.PluginSetting]:
        return [
            mobase.PluginSetting(
                "auto_open_browser",
                "Automatically open on startup",
                True
            )
        ]
    
    # IPluginDiagnose interface (required but unused)
    def activeProblems(self) -> List[int]:
        return []
    
    def shortDescription(self, key: int) -> str:
        return ""
    
    def fullDescription(self, key: int) -> str:
        return ""
    
    def hasGuidedFix(self, key: int) -> bool:
        return False
    
    def startGuidedFix(self, key: int) -> None:
        pass
    
    # IPluginTool interface (for Tools menu)
    def displayName(self) -> str:
        return "FOMOD Tracker"
    
    def tooltip(self) -> str:
        return "Open or refresh the FOMOD choice tracker web interface"
    
    def icon(self):
        # Return empty QIcon (no custom icon)
        try:
            from PyQt6.QtGui import QIcon
            return QIcon()
        except:
            return None
    
    def setParentWidget(self, widget):
        pass  # Not needed for simple browser launch
    
    def display(self) -> None:
        """Called when user clicks the Tools menu item."""
        try:
            # Ensure server is started (won't restart if already running)
            self._start_web_server(open_browser=False)
            # Open in web browser
            webbrowser.open("http://127.0.0.1:8080")
        except Exception as e:    
            pass
    # ==================== Data Management ====================
    
    def _load_data(self) -> List[Dict]:
        """Load all FOMOD data from JSON file."""
        try:
            with open(self._data_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                # Handle both old format (array) and new format (object with mods key)
                if isinstance(data, dict) and 'mods' in data:
                    return data['mods']
                return data if isinstance(data, list) else []
        except:
            return []
    
    def _save_data(self, data: List[Dict]) -> None:
        """Save all FOMOD data to JSON file with proper structure."""
        # CRITICAL: Must maintain the {mods, cross_patches} structure!
        output = {
            'mods': data,
            'cross_patches': []  # Cross-patches are computed, not saved
        }
        with open(self._data_path, 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
    
    def _update_data(self, mod_name: str, mod_version: str, steps: List[Dict], selected_options: set) -> None:
        """Update JSON data with FOMOD installation (UPSERT logic)."""
        data = self._load_data()
        
        # Build options list
        options = []
        for step in steps:
            step_name = step['name']
            for group in step['groups']:
                group_name = group['name']
                for option in group['options']:
                    option_name = option['name']
                    is_selected = option_name in selected_options
                    
                    options.append({
                        'step': step_name,
                        'group': group_name,
                        'option': option_name,
                        'selected': is_selected
                    })
        
        # Check if mod already exists
        existing_index = None
        for i, entry in enumerate(data):
            if entry['mod_name'] == mod_name:
                existing_index = i
                break
        
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        new_entry = {
            'mod_name': mod_name,
            'version': mod_version,
            'timestamp': timestamp,
            'options': options
        }
        
        if existing_index is not None:
            # Update existing
            data[existing_index] = new_entry
        else:
            # Add new (prepend for recent-first order)
            data.insert(0, new_entry)
        
        self._save_data(data)
    
    def _remove_from_data(self, mod_name: str) -> None:
        """Remove mod from JSON data."""
        data = self._load_data()
        data = [entry for entry in data if entry['mod_name'] != mod_name]
        self._save_data(data)
    
    # ==================== Event Handlers ====================
    
    def _on_mod_installed(self, mod: mobase.IModInterface) -> None:
        """Called when a mod is installed."""
        try:
            debug_file = Path(self._organizer.basePath()) / "fomod_debug.txt"
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"\n=== {datetime.now()} ===\n")
                f.write(f"Event fired! Mod: {mod.name()}\n")
                
                # Get source archive from mod directly
                try:
                    mod_path = Path(mod.absolutePath())
                    f.write(f"Mod path: {mod_path}\n")
                except Exception as e:
                    f.write(f"Error getting mod path: {e}\n")
            
            mod_name = mod.name()
            installation_data = self._deduce_fomod_choices(mod_name, mod)
            
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"Installation data: {installation_data}\n")
            
            if installation_data and installation_data.get('has_fomod'):
                self._update_data(
                    mod_name,
                    installation_data.get('version', 'Unknown'),
                    installation_data.get('steps', []),
                    installation_data.get('selected_options', set())
                )
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"✅ Data updated successfully!\n")
            else:
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"No FOMOD detected\n")
        except Exception as e:
            debug_file = Path(self._organizer.basePath()) / "fomod_debug.txt"
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"ERROR in _on_mod_installed: {e}\n")
                import traceback
                f.write(traceback.format_exc())
    
    def _on_mod_removed(self, mod_name: str) -> None:
        """Called when a mod is uninstalled."""
        try:
            self._remove_from_data(mod_name)
        except Exception as e:    
            pass
    # ==================== FOMOD Detection & Parsing ====================
    
    def _deduce_fomod_choices(self, mod_name: str, mod: mobase.IModInterface) -> Optional[Dict[str, Any]]:
        """Deduce FOMOD choices by comparing installed files against FOMOD XML."""
        debug_file = Path(self._organizer.basePath()) / "fomod_debug.txt"
        
        try:
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"Starting deduce for: {mod_name}\n")
            
            # Get archive from meta.ini
            mod_path = Path(mod.absolutePath())
            meta_file = mod_path / "meta.ini"
            
            downloads_path = Path(self._organizer.downloadsPath())
            archive_file = None
            
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"Meta file: {meta_file}, exists: {meta_file.exists()}\n")
            
            if meta_file.exists():
                import configparser
                config = configparser.ConfigParser()
                config.read(meta_file, encoding='utf-8')
                if 'General' in config and 'installationFile' in config['General']:
                    install_file = config['General']['installationFile']
                    if install_file:
                        archive_file = downloads_path / install_file
                        with open(debug_file, 'a', encoding='utf-8') as f:
                            f.write(f"Found installationFile: {install_file}\n")
                            f.write(f"Archive path: {archive_file}, exists: {archive_file.exists()}\n")
            
            # Fallback to recent access
            if not archive_file or not archive_file.exists():
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"Trying fallback (recent access)...\n")
                archive_file = self._find_matching_archive(mod_name, downloads_path)
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"Fallback result: {archive_file}\n")
            
            if not archive_file or not archive_file.exists():
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"❌ No archive found!\n")
                return None
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"No matching archive found!\n")
                return None
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"No matching archive found!\n")
                return None
            
            # Parse FOMOD from archive
            fomod_data = self._parse_fomod_from_archive(archive_file)
            
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"FOMOD data: has_fomod={fomod_data.get('has_fomod')}, steps={len(fomod_data.get('steps', []))}\n")
            
            if not fomod_data or not fomod_data.get('has_fomod'):
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"No FOMOD in archive\n")
                return None
            
            # Get installed files
            mod_path = Path(self._organizer.modsPath()) / mod_name
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"Mod path: {mod_path}, exists: {mod_path.exists()}\n")
            
            installed_files = self._get_installed_files_set(mod_path)
            
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"Installed files count: {len(installed_files)}\n")
                if installed_files:
                    f.write(f"Sample files: {list(installed_files)[:5]}\n")
            
            # Match files to options
            selected_options = self._match_files_to_options(fomod_data, installed_files)
            
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"Selected options: {selected_options}\n")
            
            return {
                'has_fomod': True,
                'version': fomod_data.get('version', 'Unknown'),
                'steps': fomod_data.get('steps', []),
                'selected_options': selected_options
            }
            
        except Exception as e:
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"Exception in deduce: {e}\n")
                import traceback
                f.write(traceback.format_exc())
            return None
    
    def _find_matching_archive(self, mod_name: str, downloads_path: Path) -> Optional[Path]:
        """Find the download archive - use most recently accessed since user just installed from it."""
        import time
        
        candidates = []
        current_time = time.time()
        
        # Find all archives modified/accessed in last 60 seconds
        for ext in ['*.zip', '*.7z', '*.rar']:
            for archive_file in downloads_path.glob(ext):
                # Check both modification and access time
                mtime = archive_file.stat().st_mtime
                atime = archive_file.stat().st_atime
                recent_time = max(mtime, atime)
                
                # If accessed in last 60 seconds, it's likely the one we just installed
                if (current_time - recent_time) < 60:
                    candidates.append((archive_file, recent_time))
        
        if not candidates:
            # Fallback: try name matching
            mod_words = set(word.lower().rstrip("'s") for word in re.split(r'[_\s\-()]+', mod_name) if len(word) > 2)
            
            best_match = None
            best_score = 0
            
            for ext in ['*.zip', '*.7z', '*.rar']:
                for archive_file in downloads_path.glob(ext):
                    archive_words = set(word.lower().rstrip("'s") for word in re.split(r'[_\s\-()]+', archive_file.stem) if len(word) > 2)
                    score = len(mod_words & archive_words)
                    
                    if score > best_score:
                        best_score = score
                        best_match = archive_file
            
            return best_match if best_score > 0 else None
        
        # Return most recently accessed archive
        candidates.sort(key=lambda x: x[1], reverse=True)
        return candidates[0][0]
    
    def _parse_fomod_from_archive(self, archive_path: Path) -> Dict[str, Any]:
        """Parse FOMOD ModuleConfig.xml from archive."""
        result = {'has_fomod': False, 'version': 'Unknown', 'steps': []}
        
        try:
            with zipfile.ZipFile(archive_path, 'r') as zf:
                config_files = [name for name in zf.namelist() 
                               if name.lower().endswith('fomod/moduleconfig.xml')]
                
                if not config_files:
                    return result
                
                with zf.open(config_files[0]) as xml_file:
                    xml_content = xml_file.read()
                    result = self._parse_fomod_xml(xml_content)
            
        except Exception as e:        
            pass
        return result
    
    def _parse_fomod_xml(self, xml_content: bytes) -> Dict[str, Any]:
        """Parse FOMOD XML content."""
        info = {'has_fomod': False, 'version': 'Unknown', 'steps': []}
        debug_file = Path(self._organizer.basePath()) / "fomod_debug.txt"
        
        try:
            root = ET.fromstring(xml_content)
            info['has_fomod'] = True
            
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"XML root tag: {root.tag}\n")
                f.write(f"XML children: {[c.tag for c in root]}\n")
            
            # Find namespace
            ns = {'fomod': 'http://qconsulting.ca/fo3/ModConfig5.0'}
            if root.tag.startswith('{'):
                ns_uri = root.tag[1:root.tag.index('}')]
                ns = {'fomod': ns_uri}
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"Detected namespace: {ns_uri}\n")
            
            # Get version
            version_elem = root.find('.//fomod:moduleVersion', ns)
            if version_elem is not None and version_elem.text:
                info['version'] = version_elem.text
            
            # Parse install steps - try with and without namespace
            install_steps = root.find('.//fomod:installSteps', ns)
            
            # If not found with namespace, try without
            if install_steps is None:
                install_steps = root.find('.//installSteps')
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"Trying without namespace: {install_steps}\n")
            
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"installSteps element: {install_steps}\n")
            
            if install_steps is not None:
                # Try with namespace first
                steps = install_steps.findall('.//fomod:installStep', ns)
                
                # Fallback to no namespace
                if not steps:
                    steps = install_steps.findall('.//installStep')
                
                with open(debug_file, 'a', encoding='utf-8') as f:
                    f.write(f"Found {len(steps)} steps\n")
                
                for idx, step in enumerate(steps):
                    step_name = step.get('name', f'Step {idx + 1}')
                    step_info = {'name': step_name, 'groups': []}
                    
                    # Try with namespace first
                    groups = step.findall('.//fomod:group', ns)
                    if not groups:
                        groups = step.findall('.//group')
                    
                    for group in groups:
                        group_name = group.get('name', 'Default')
                        group_info = {'name': group_name, 'options': []}
                        
                        # Try with namespace first
                        plugins = group.findall('.//fomod:plugin', ns)
                        if not plugins:
                            plugins = group.findall('.//plugin')
                        
                        for plugin in plugins:
                            plugin_name = plugin.get('name', 'Unknown')
                            files = []
                            
                            # Get file elements (try both)
                            file_elems = plugin.findall('.//fomod:file', ns)
                            if not file_elems:
                                file_elems = plugin.findall('.//file')
                            
                            for file_elem in file_elems:
                                source = file_elem.get('source', '')
                                if source:
                                    files.append({'source': source})
                            
                            # Get folder elements (try both)
                            folder_elems = plugin.findall('.//fomod:folder', ns)
                            if not folder_elems:
                                folder_elems = plugin.findall('.//folder')
                            
                            for folder_elem in folder_elems:
                                source = folder_elem.get('source', '')
                                if source:
                                    files.append({'source': source, 'is_folder': True})
                            
                            group_info['options'].append({
                                'name': plugin_name,
                                'files': files
                            })
                        
                        step_info['groups'].append(group_info)
                    
                    info['steps'].append(step_info)
        
        except Exception as e:
            with open(debug_file, 'a', encoding='utf-8') as f:
                f.write(f"ERROR parsing XML: {e}\n")
                import traceback
                f.write(traceback.format_exc())
        
        return info
    
    def _get_installed_files_set(self, mod_path: Path) -> set:
        """Get set of normalized installed file paths."""
        files = set()
        
        if not mod_path.exists():
            return files
        
        for file_path in mod_path.rglob('*'):
            if file_path.is_file():
                rel_path = file_path.relative_to(mod_path)
                normalized = str(rel_path).lower().replace('\\', '/')
                files.add(normalized)
        
        return files
    
    def _match_files_to_options(self, fomod_data: Dict, installed_files: set) -> set:
        """Match installed files to FOMOD options using smart heuristics."""
        selected_options = set()
        debug_file = Path(self._organizer.basePath()) / "fomod_debug.txt"
        
        for step in fomod_data.get('steps', []):
            for group in step['groups']:
                group_options = group['options']
                
                # For each option, calculate a specificity score
                option_scores = []
                
                for option in group_options:
                    option_name = option['name']
                    option_files = option.get('files', [])
                    
                    if not option_files:
                        continue
                    
                    # Score based on matched files
                    matches = []
                    for file_info in option_files:
                        source = file_info.get('source', '').lower().replace('\\', '/')
                        if not source:
                            continue
                        
                        # Look for exact matches or folder matches
                        for installed_file in installed_files:
                            # Check if the source path is in the installed file path
                            if source in installed_file or installed_file.startswith(source + '/'):
                                matches.append(source)
                                break
                    
                    if matches:
                        # Calculate specificity: prefer unique/specific file names
                        specificity = sum(len(m) for m in matches) / len(option_files)
                        option_scores.append({
                            'name': option_name,
                            'matches': len(matches),
                            'total_files': len(option_files),
                            'specificity': specificity,
                            'matched_files': matches
                        })
                
                # Select option(s) with best matches
                if option_scores:
                    # Sort by number of matches, then by specificity
                    option_scores.sort(key=lambda x: (x['matches'], x['specificity']), reverse=True)
                    
                    # For groups with multiple matches, take ones with high match rate
                    best_match_count = option_scores[0]['matches']
                    for score in option_scores:
                        # If this option matched most of its files, select it
                        match_rate = score['matches'] / score['total_files']
                        if score['matches'] >= best_match_count * 0.8 and match_rate > 0.5:
                            selected_options.add(score['name'])
                            
                            with open(debug_file, 'a', encoding='utf-8') as f:
                                f.write(f"Selected '{score['name']}': {score['matches']}/{score['total_files']} files, spec={score['specificity']:.2f}\n")
                                f.write(f"  Matched: {score['matched_files']}\n")
        
        return selected_options
    
    # ==================== Web Server & Interface ====================
    
    def _start_web_server(self, open_browser: bool = None) -> None:
        """Start HTTP server and optionally open browser."""
        if self._server_started:
            return
        
        # Check setting for auto-open behavior if not explicitly specified
        if open_browser is None:
            open_browser = self._organizer.pluginSetting(self.name(), "auto_open_browser")
        
        try:
            # Check if port is available
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('127.0.0.1', 8080))
            sock.close()
            
            if result == 0:
                # Port already in use - open browser if requested
                if open_browser:
                    webbrowser.open('http://127.0.0.1:8080')
                return
            
            # Start server in background thread
            def run_server():
                handler = self._create_request_handler()
                # Bind to 127.0.0.1 to avoid Windows Firewall popup
                httpd = socketserver.TCPServer(("127.0.0.1", 8080), handler)
                httpd.allow_reuse_address = True
                httpd.serve_forever()
            
            thread = threading.Thread(target=run_server, daemon=True)
            thread.start()
            
            self._server_started = True
            
            # Open browser after short delay if requested
            if open_browser:
                import time
                time.sleep(0.5)
                webbrowser.open('http://127.0.0.1:8080')
            
        except Exception as e:    
            pass
    def _create_request_handler(self):
        """Create HTTP request handler class with embedded HTML."""
        plugin_self = self
        
        class FomodRequestHandler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == '/' or self.path == '/index.html' or self.path == '':
                    self.send_response(200)
                    self.send_header('Content-type', 'text/html; charset=utf-8')
                    self.end_headers()
                    self.wfile.write(plugin_self._get_html().encode('utf-8'))
                elif self.path.startswith('/data.json'):
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json; charset=utf-8')
                    self.end_headers()
                    self.wfile.write(plugin_self._get_json_data().encode('utf-8'))
                else:
                    self.send_response(404)
                    self.send_header('Content-type', 'text/html')
                    self.end_headers()
                    self.wfile.write(b'<h1>404 Not Found</h1>')
            
            def log_message(self, format, *args):
                pass  # Suppress server logs
        
        return FomodRequestHandler
    
    def _get_json_data(self) -> str:
        """Generate JSON data with cross-FOMOD patch analysis."""
        data = self._load_data()
        
        # Analyze cross-FOMOD patches
        patches = self._analyze_cross_patches(data)
        
        result = {
            'mods': data,
            'cross_patches': patches
        }
        
        return json.dumps(result, indent=2)
    
    def _get_theme_data(self) -> str:
        """Extract theme colors from MO2's active stylesheet."""
        try:
            # Read MO2's ModOrganizer.ini to get active style
            base_path = Path(self._organizer.basePath())
            ini_file = base_path / "ModOrganizer.ini"
            
            style_name = ""
            if ini_file.exists():
                import configparser
                config = configparser.ConfigParser()
                config.read(ini_file, encoding='utf-8')
                
                if 'Settings' in config:
                    style_name = config['Settings'].get('style', '').strip()
                    # Remove .qss extension if present
                    if style_name.endswith('.qss'):
                        style_name = style_name[:-4]            
            # Default theme (for empty/no style)
            theme = {
                'primary': '#667eea',
                'secondary': '#764ba2',
                'is_dark': False
            }
            
            # If no style set, MO2 uses default Qt theme (light)
            if not style_name:                return json.dumps(theme)
            
            # Find corresponding .qss file
            stylesheets_path = base_path / "stylesheets"
            qss_file = None
            
            # Try exact match
            test_path = stylesheets_path / f"{style_name}.qss"
            if test_path.exists():
                qss_file = test_path
            else:
                # Try case-insensitive search
                for item in stylesheets_path.rglob("*.qss"):
                    if item.stem.lower() == style_name.lower():
                        qss_file = item
                        break            
            if qss_file and qss_file.exists():
                # Parse QSS file for colors
                content = qss_file.read_text(encoding='utf-8', errors='ignore')
                
                # Extract accent colors (selection, border, link, highlight)
                accent_pattern = r'(?:selection-background-color|border-color|qproperty-linkColor):\s*(#[0-9a-fA-F]{6})'
                accent_colors = re.findall(accent_pattern, content)
                
                # Extract background colors - look at start of file and common widgets
                bg_match = re.search(r'(?:\*|QWidget|QAbstractScrollArea)\s*\{[^}]*?(?:background-color|background):\s*(#[0-9a-fA-F]{6})', content, re.DOTALL)
                bg_color = bg_match.group(1) if bg_match else None
                
                # Extract text color - look at start of file and common widgets
                text_match = re.search(r'(?:\*|QWidget|QAbstractScrollArea)\s*\{[^}]*?\bcolor:\s*(#[0-9a-fA-F]{6})', content, re.DOTALL)
                text_color = text_match.group(1) if text_match else None
                
                # Find most common non-gray accent color
                color_counts = {}
                for color in accent_colors:
                    color_lower = color.lower()
                    # Skip grays and very dark/light colors
                    if color_lower not in ['#2d2d30', '#333337', '#3f3f46', '#1b1b1c', '#f1f1f1', '#dddddd', '#000000', '#ffffff', '#1e1e1e', '#252526', '#efefef', '#e0e0e0']:
                        color_counts[color_lower] = color_counts.get(color_lower, 0) + 1
                
                if color_counts:
                    # Get most frequent accent color
                    primary = max(color_counts, key=color_counts.get)
                    theme['primary'] = primary
                    theme['secondary'] = primary
                
                # Add background and text colors
                if bg_color:
                    theme['background'] = bg_color
                if text_color:
                    theme['text'] = text_color
                
                # Detect if dark theme
                is_dark = any(keyword in style_name.lower() for keyword in ['dark', 'night', 'black', 'mocha', 'dracula'])
                if bg_color and not is_dark:
                    # Check background brightness
                    r = int(bg_color[1:3], 16)
                    g = int(bg_color[3:5], 16)
                    b = int(bg_color[5:7], 16)
                    brightness = (r + g + b) / 3
                    is_dark = brightness < 128                
                theme['is_dark'] = is_dark
            
            return json.dumps(theme)
        except Exception as e:
            pass
            # Fallback to default
            return json.dumps({'primary': '#667eea', 'secondary': '#764ba2', 'is_dark': False})
    
    def _analyze_cross_patches(self, data: List[Dict]) -> List[Dict]:
        """Find options that appear in multiple FOMODs - shows ALL shared options."""
        option_mentions = defaultdict(list)  # {normalized_key: [(fomod_name, original_text, group, selected)]}
        
        def normalize_option(text: str) -> str:
            """Normalize option text by removing version numbers and noise words."""
            # Remove version numbers in various formats
            normalized = re.sub(r'v?\d+\.\d+\.?\d*\.?\d*\+?', '', text, flags=re.IGNORECASE)
            normalized = re.sub(r'\bv\d+\b', '', normalized, flags=re.IGNORECASE)
            
            # Remove parenthetical version info if it contains numbers
            normalized = re.sub(r'\([^)]*\d+[^)]*\)', '', normalized)
            
            # Remove ALL remaining parentheses and quotes
            normalized = re.sub(r'[()"\']', '', normalized)
            
            # Remove SSE/SE prefix if present
            normalized = re.sub(r'\bSSE\b', '', normalized, flags=re.IGNORECASE)
            normalized = re.sub(r'\bSE\b', '', normalized, flags=re.IGNORECASE)
            
            # Clean up extra whitespace
            normalized = re.sub(r'\s+', ' ', normalized)
            normalized = normalized.strip(' -_()[]"\':,')
            
            # If we stripped too much, return original
            if len(normalized) < 3:
                return text.strip()
            
            return normalized
        
        for entry in data:
            fomod_name = entry['mod_name']
            for option in entry['options']:
                option_text = option['option']
                group_name = option.get('group', '')
                selected = option['selected']
                
                # Normalize and track
                normalized_key = normalize_option(option_text)
                
                option_mentions[normalized_key].append({
                    'fomod': fomod_name,
                    'original_text': option_text,
                    'group': group_name,
                    'selected': selected
                })
        
        # Find options that appear in 2+ FOMODs
        cross_patches = []
        for normalized_key, mentions in option_mentions.items():
            # Group by FOMOD to avoid counting same option multiple times in one FOMOD
            unique_fomods = set(mention['fomod'] for mention in mentions)
            
            if len(unique_fomods) >= 2:
                # Determine if this option was selected anywhere
                selected_anywhere = any(mention['selected'] for mention in mentions)
                
                cross_patches.append({
                    'option': normalized_key,
                    'mods': [
                        {
                            'name': mention['fomod'],
                            'selected': mention['selected'],
                            'original_text': mention['original_text']
                        } for mention in mentions
                    ],
                    'selected_anywhere': selected_anywhere
                })
        
        # Sort by number of mods (most common first)
        cross_patches.sort(key=lambda x: len(x['mods']), reverse=True)
        
        return cross_patches
    
    def _get_html(self) -> str:
        """Return embedded HTML interface."""
        return '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>FOMOD Installation Tracker</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        :root {
            --blood-red: #8B0000;
            --crimson: #DC143C;
            --dark-bg: #0a0a0a;
            --card-bg: #1a1a1a;
            --border: #2a2a2a;
            --text-primary: #e8e8e8;
            --text-secondary: #a0a0a0;
            --shadow: rgba(139, 0, 0, 0.3);
            --accent-glow: rgba(220, 20, 60, 0.2);
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: var(--dark-bg);
            color: var(--text-primary);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: var(--card-bg);
            border-radius: 12px;
            box-shadow: 0 20px 60px var(--shadow), 0 0 40px var(--accent-glow);
            overflow: hidden;
            display: flex;
            gap: 0;
            align-items: flex-start;
            border: 1px solid var(--blood-red);
        }
        .main-content {
            flex: 1;
            min-width: 0;
        }
        .sidebar {
            width: 350px;
            flex-shrink: 0;
            position: sticky;
            top: 0;
            align-self: flex-start;
        }
        .header {
            background: linear-gradient(135deg, #0a0a0a 0%, var(--blood-red) 100%);
            color: white;
            padding: 30px;
            text-align: center;
            border-bottom: 2px solid var(--crimson);
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { opacity: 0.9; font-size: 1.1em; }
        .stats {
            display: flex;
            justify-content: center;
            gap: 30px;
            margin-top: 20px;
        }
        .stat {
            background: rgba(139, 0, 0, 0.3);
            padding: 15px 30px;
            border-radius: 8px;
            border: 1px solid var(--blood-red);
        }
        .stat-value { font-size: 2em; font-weight: bold; }
        .stat-label { font-size: 0.9em; opacity: 0.9; }
        .controls {
            padding: 20px 30px;
            background: var(--card-bg);
            border-bottom: 2px solid var(--border);
            display: flex;
            gap: 15px;
            align-items: center;
        }
        .search-box {
            flex: 1;
            padding: 12px 20px;
            border: 2px solid var(--blood-red);
            border-radius: 8px;
            font-size: 1em;
            background: var(--dark-bg);
            color: var(--text-primary);
        }
        .search-box:focus {
            outline: none;
            border-color: var(--crimson);
            box-shadow: 0 0 10px var(--accent-glow);
        }
        .filter-btn {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            background: var(--blood-red);
            color: white !important;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.3s;
        }
        .filter-btn:hover { 
            background: var(--crimson);
            box-shadow: 0 0 15px var(--accent-glow);
        }
        .filter-btn.active { 
            opacity: 0.9;
        }
        select.filter-btn {
            color: white !important;
        }
        select.filter-btn option {
            background: #2a2a2a;
            color: white;
        }
        .content {
            padding: 30px;
            max-height: calc(100vh - 400px);
            overflow-y: auto;
        }
        .mod-card {
            background: var(--card-bg);
            border: 2px solid var(--border);
            border-radius: 12px;
            margin-bottom: 20px;
            overflow: hidden;
            transition: all 0.3s;
            box-shadow: 0 4px 6px var(--shadow);
        }
        .mod-card:hover {
            border-color: var(--blood-red);
            box-shadow: 0 8px 16px var(--shadow), 0 0 20px var(--accent-glow);
        }
        .mod-header {
            background: linear-gradient(135deg, var(--card-bg) 0%, rgba(139, 0, 0, 0.2) 100%);
            padding: 20px;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 2px solid var(--blood-red);
        }
        .mod-title {
            font-size: 1.3em;
            font-weight: 600;
            color: var(--text-primary);
        }
        .mod-meta {
            color: var(--text-secondary);
            font-size: 0.9em;
            margin-top: 5px;
        }
        .hide-btn {
            padding: 5px 12px;
            background: rgba(220, 38, 38, 0.2);
            border: 1px solid rgba(220, 38, 38, 0.5);
            color: #dc2626;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.85em;
            transition: all 0.2s;
            margin-left: auto;
            margin-right: 10px;
        }
        .hide-btn:hover {
            background: rgba(220, 38, 38, 0.3);
            border-color: #dc2626;
        }
        .show-hidden-section {
            margin-bottom: 20px;
            padding: 15px;
            background: rgba(100, 100, 100, 0.2);
            border: 1px solid rgba(100, 100, 100, 0.4);
            border-radius: 8px;
        }
        .show-hidden-btn {
            padding: 8px 16px;
            background: rgba(100, 100, 100, 0.3);
            border: 1px solid rgba(100, 100, 100, 0.5);
            color: var(--text-primary);
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.9em;
            transition: all 0.2s;
        }
        .show-hidden-btn:hover {
            background: rgba(100, 100, 100, 0.5);
        }
        .show-hidden-btn.active {
            background: rgba(102, 126, 234, 0.3);
            border-color: #667eea;
            color: #667eea;
        }
        .hidden-mod {
            opacity: 0.6;
            border-color: rgba(100, 100, 100, 0.5) !important;
        }
        .hidden-mod .hide-btn {
            background: rgba(34, 197, 94, 0.2);
            border-color: rgba(34, 197, 94, 0.5);
            color: #22c55e;
        }
        .hidden-mod .hide-btn:hover {
            background: rgba(34, 197, 94, 0.3);
            border-color: #22c55e;
        }
        .toggle-icon {
            font-size: 1.5em;
            color: #667eea;
            transition: transform 0.3s ease;
        }
        .mod-card.collapsed .toggle-icon { transform: rotate(-90deg); }
        .mod-body {
            padding: 20px;
            max-height: 5000px;
            overflow: hidden;
            transition: max-height 0.4s ease, padding 0.3s ease, opacity 0.3s ease;
            opacity: 1;
        }
        .mod-card.collapsed .mod-body { 
            max-height: 0;
            padding: 0 20px;
            opacity: 0;
        }
        .step {
            margin-bottom: 25px;
            border-left: 4px solid var(--blood-red);
            padding-left: 15px;
        }
        .step-title {
            font-size: 1.1em;
            font-weight: 600;
            color: var(--text-primary);
            margin-bottom: 10px;
        }
        .group {
            margin-bottom: 15px;
        }
        .group-title {
            font-weight: 600;
            color: var(--text-primary);
            margin-bottom: 8px;
            font-size: 1em;
        }
        .option {
            padding: 8px 12px;
            margin: 4px 0;
            border-radius: 6px;
            display: flex;
            align-items: center;
            gap: 10px;
            transition: all 0.2s;
        }
        .option.selected {
            background: rgba(34, 197, 94, 0.2);
            border-left: 3px solid #22c55e;
            color: var(--text-primary);
        }
        .option.not-selected {
            background: transparent;
            border-left: 3px solid var(--border);
            color: var(--text-secondary);
            opacity: 0.6;
        }
        .option.not-selected span:last-child {
            text-decoration: line-through;
        }
        .option-icon {
            font-weight: bold;
            font-size: 1.2em;
            min-width: 20px;
        }
        .option.selected .option-icon { color: #22c55e; }
        .option.not-selected .option-icon { color: var(--text-secondary); }
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: #6c757d;
        }
        .empty-state-icon { font-size: 4em; margin-bottom: 20px; opacity: 0.3; }
        ::-webkit-scrollbar { width: 12px; }
        ::-webkit-scrollbar-track { background: var(--dark-bg); }
        ::-webkit-scrollbar-thumb { background: var(--blood-red); border-radius: 6px; }
        .cross-patches {
            background: var(--card-bg);
            border-radius: 8px;
            border: 2px solid var(--blood-red);
            overflow: hidden;
            box-shadow: 0 4px 6px var(--shadow);
        }
        .cross-patches-header {
            padding: 15px;
            background: linear-gradient(135deg, var(--blood-red) 0%, var(--crimson) 100%);
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            user-select: none;
        }
        .cross-patches-header:hover {
            background: linear-gradient(135deg, var(--crimson) 0%, var(--blood-red) 100%);
        }
        .cross-patches-header h2 {
            color: white;
            margin: 0;
            font-size: 1.2em;
        }
        .cross-patches-toggle {
            font-size: 1.5em;
            color: white;
            transition: transform 0.3s ease;
        }
        .cross-patches.collapsed .cross-patches-toggle {
            transform: rotate(180deg);
        }
        .cross-patches-content {
            padding: 15px;
            max-height: calc(100vh - 200px);
            overflow-y: auto;
            transition: max-height 0.3s ease, padding 0.3s ease;
            background: var(--card-bg);
        }
        .cross-patches.collapsed .cross-patches-content {
            max-height: 0;
            padding: 0 15px;
            overflow: hidden;
        }
        .cross-patches-list {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        .patch-item {
            background: var(--dark-bg);
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid var(--crimson);
            border: 1px solid var(--border);
        }
        .patch-item.hidden-patch {
            opacity: 0.6;
            border-color: rgba(100, 100, 100, 0.5);
        }
        .hide-btn-small {
            padding: 3px 8px;
            background: rgba(220, 38, 38, 0.2);
            border: 1px solid rgba(220, 38, 38, 0.5);
            color: #dc2626;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.75em;
            transition: all 0.2s;
        }
        .hide-btn-small:hover {
            background: rgba(220, 38, 38, 0.3);
            border-color: #dc2626;
        }
        .hidden-patch .hide-btn-small {
            background: rgba(34, 197, 94, 0.2);
            border-color: rgba(34, 197, 94, 0.5);
            color: #22c55e;
        }
        .hidden-patch .hide-btn-small:hover {
            background: rgba(34, 197, 94, 0.3);
            border-color: #22c55e;
        }
        .patch-mod-name {
            font-weight: 600;
            color: var(--crimson);
            font-size: 1.1em;
            margin-bottom: 8px;
        }
        .patch-count {
            color: var(--text-secondary);
            font-size: 0.9em;
            margin-bottom: 10px;
        }
        .patch-fomod {
            font-size: 0.85em;
            color: var(--text-secondary);
            margin: 4px 0;
            padding-left: 10px;
            border-left: 2px solid var(--border);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="main-content">
            <div class="header">
                <h1><img src="data:image/png;base64,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" alt="MO2" style="height: 1.2em; vertical-align: middle; margin-right: 15px;">FOMOD Installation Tracker</h1>
                <p>Track your FOMOD installation choices with real-time updates</p>
                <div class="stats">
                    <div class="stat">
                        <div class="stat-value" id="totalMods">0</div>
                        <div class="stat-label">Total FOMODs</div>
                    </div>
                </div>
            </div>
            
            <div class="controls">
                <input type="text" class="search-box" id="searchBox" placeholder="🔍 Search mods...">
                <select class="filter-btn" id="sortSelect" onchange="handleSort()">
                    <option value="date-new">Newest First</option>
                    <option value="date-old">Oldest First</option>
                    <option value="name-az">Name A-Z</option>
                    <option value="name-za">Name Z-A</option>
                </select>
                <button class="filter-btn" onclick="toggleQuickView()" id="quickViewBtn">Quick View: OFF</button>
                <button class="filter-btn" onclick="toggleShowHidden()" id="show-hidden-btn">Show Hidden Mods</button>
                <button class="filter-btn" onclick="toggleAll()">Collapse All</button>
            </div>
            
            <div id="hidden-count-indicator" style="margin-top: 10px; padding: 10px; background: rgba(100, 100, 100, 0.2); border-radius: 6px; display: none; color: var(--text-secondary); font-size: 0.9em;">
                <span id="hidden-count-text"></span>
            </div>
            
            <div class="content" id="content"></div>
        </div>
        
        <div class="sidebar" id="sidebar">
            <div class="cross-patches" id="crossPatches" style="display: none;">
                <div class="cross-patches-header" onclick="toggleSidebar()">
                    <h2>🔗 Cross-Patches</h2>
                    <span class="cross-patches-toggle">▼</span>
                </div>
                <div class="cross-patches-content">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                        <button class="show-hidden-btn" onclick="toggleShowHiddenCrossPatches(event)" id="show-hidden-crosspatches-btn">Show Hidden</button>
                        <div id="cross-patch-hidden-count" style="display: none; color: var(--text-secondary); font-size: 0.85em;"></div>
                    </div>
                    <p style="color: var(--text-secondary); margin-bottom: 15px; font-size: 0.9em;">Shared options across FOMODs:</p>
                    <div class="cross-patches-list" id="crossPatchesList"></div>
                </div>
            </div>
        </div>
    </div>

    <script>
        let allData = [];
        let crossPatches = [];
        let expandedMods = new Set();
        let quickViewMode = false;
        let currentSort = 'date-new';
        let currentSearchTerm = '';
        let mo2Theme = null;
        let showHidden = false;
        
        // Load hidden mods from localStorage
        function getHiddenMods() {
            try {
                return new Set(JSON.parse(localStorage.getItem('hiddenMods') || '[]'));
            } catch (e) {
                return new Set();
            }
        }
        
        function saveHiddenMods(hiddenMods) {
            localStorage.setItem('hiddenMods', JSON.stringify([...hiddenMods]));
        }
        
        let hiddenMods = getHiddenMods();
        
        // Load hidden cross-patches from localStorage
        function getHiddenCrossPatches() {
            try {
                return new Set(JSON.parse(localStorage.getItem('hiddenCrossPatches') || '[]'));
            } catch (e) {
                return new Set();
            }
        }
        
        function saveHiddenCrossPatches(hiddenPatches) {
            localStorage.setItem('hiddenCrossPatches', JSON.stringify([...hiddenPatches]));
        }
        
        let hiddenCrossPatches = getHiddenCrossPatches();
        let showHiddenCrossPatches = false;
        
        // Load MO2 theme colors
        async function loadTheme() {
            try {                const response = await fetch('/theme.json?nocache=' + Date.now());
                mo2Theme = await response.json();                applyTheme(mo2Theme);
            } catch (error) {
                console.error('[Theme] Error loading theme:', error);
            }
        }
        
        function applyTheme(theme) {            const root = document.documentElement;
            const body = document.body;
            
            const primary = theme.primary || '#667eea';
            const secondary = theme.secondary || '#764ba2';
            const background = theme.background || '#f0f0f0';
            const text = theme.text || '#212529';            
            // Set CSS variables for gradient and colors
            root.style.setProperty('--bg-gradient-start', primary);
            root.style.setProperty('--bg-gradient-end', secondary);
            root.style.setProperty('--text-primary', text);
            
            // Override dark-mode variables with theme colors
            if (theme.is_dark) {
                root.style.setProperty('--border-color', primary);
                root.style.setProperty('--text-secondary', text);
            }
            
            // Set body background to match MO2
            body.style.backgroundColor = background;
            body.style.color = text;
            
            // Set card background slightly lighter/darker than body
            let cardBg;
            if (theme.is_dark) {
                // For dark themes, make cards slightly lighter
                const r = Math.min(255, parseInt(background.substring(1, 3), 16) + 15);
                const g = Math.min(255, parseInt(background.substring(3, 5), 16) + 15);
                const b = Math.min(255, parseInt(background.substring(5, 7), 16) + 15);
                cardBg = `#${r.toString(16).padStart(2,'0')}${g.toString(16).padStart(2,'0')}${b.toString(16).padStart(2,'0')}`;            } else {
                // For light themes, use white cards
                cardBg = '#ffffff';
            }
            root.style.setProperty('--card-bg', cardBg);
            
            // Apply accent color to buttons
            const buttons = document.querySelectorAll('.filter-btn');
            buttons.forEach(btn => {
                btn.style.backgroundColor = primary;
                btn.style.borderColor = primary;
            });
            
            // Apply accent to step borders
            const steps = document.querySelectorAll('.step');
            steps.forEach(step => {
                step.style.borderLeftColor = primary;
            });
            
            // Auto-apply dark mode CSS variables if MO2 theme is dark
            if (theme.is_dark) {                body.classList.add('dark-mode');
            } else {                body.classList.remove('dark-mode');
            }        }
        
        function toggleQuickView() {
            quickViewMode = !quickViewMode;
            document.getElementById('quickViewBtn').textContent = 'Quick View: ' + (quickViewMode ? 'ON' : 'OFF');
            renderData(getSortedData());
        }
        
        function toggleAll() {
            const allCollapsed = document.querySelectorAll('.mod-card.collapsed').length === document.querySelectorAll('.mod-card').length;
            document.querySelectorAll('.mod-card').forEach(card => {
                if (allCollapsed) {
                    card.classList.remove('collapsed');
                } else {
                    card.classList.add('collapsed');
                }
            });
        }
        
        function handleSort() {
            currentSort = document.getElementById('sortSelect').value;
            renderData(getSortedData());
        }
        
        function getSortedData() {
            const sorted = [...allData];
            switch(currentSort) {
                case 'date-new':
                    return sorted.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
                case 'date-old':
                    return sorted.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
                case 'name-az':
                    return sorted.sort((a, b) => a.mod_name.localeCompare(b.mod_name));
                case 'name-za':
                    return sorted.sort((a, b) => b.mod_name.localeCompare(a.mod_name));
                default:
                    return sorted;
            }
        }
        
        let lastDataHash = '';
        let isAnimating = false;
        
        async function loadData() {
            // Skip if user is actively interacting (animating)
            if (isAnimating) {
                return;
            }
            
            try {
                // Aggressive cache busting
                const timestamp = Date.now();
                const response = await fetch('/data.json?nocache=' + timestamp, {
                    cache: 'no-store',
                    headers: {
                        'Cache-Control': 'no-cache',
                        'Pragma': 'no-cache'
                    }
                });
                const jsonData = await response.json();
                
                // Only re-render if data actually changed
                const dataHash = JSON.stringify(jsonData);
                if (dataHash === lastDataHash) {
                    return; // No changes, skip re-render
                }
                lastDataHash = dataHash;
                
                allData = jsonData.mods || jsonData;  // Handle both old and new format
                crossPatches = jsonData.cross_patches || [];
                renderData(getSortedData());
                renderCrossPatches(crossPatches);
                updateStats();
            } catch (error) {
                console.error('Error loading data:', error);
            }
        }
        
        function toggleSidebar() {
            const crossPatches = document.getElementById('crossPatches');
            crossPatches.classList.toggle('collapsed');
        }
        
        function renderCrossPatches(patches) {
            const container = document.getElementById('crossPatches');
            const list = document.getElementById('crossPatchesList');
            
            if (!patches || patches.length === 0) {
                container.style.display = 'none';
                return;
            }
            
            container.style.display = 'block';
            
            // Filter hidden patches
            const visiblePatches = patches.filter(patch => {
                const isHidden = hiddenCrossPatches.has(patch.option);
                return showHiddenCrossPatches || !isHidden;
            });
            
            // Show hidden count
            const hiddenCount = patches.filter(p => hiddenCrossPatches.has(p.option)).length;
            const countIndicator = document.getElementById('cross-patch-hidden-count');
            if (hiddenCount > 0) {
                countIndicator.style.display = 'block';
                countIndicator.textContent = `${hiddenCount} hidden`;
            } else {
                countIndicator.style.display = 'none';
            }
            
            list.innerHTML = visiblePatches.map(patch => {
                // Only show indicators if this option was selected somewhere
                const showIndicators = patch.selected_anywhere;
                const isHidden = hiddenCrossPatches.has(patch.option);
                
                return `
                    <div class="patch-item ${isHidden ? 'hidden-patch' : ''}">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <div class="patch-mod-name">${patch.option}</div>
                            <button class="hide-btn-small" onclick="toggleHideCrossPatch('${patch.option.replace(/'/g, "\\'")}', event)">
                                ${isHidden ? 'Unhide' : 'Hide'}
                            </button>
                        </div>
                        <div class="patch-count">Found in ${patch.mods.length} mods</div>
                        ${patch.mods.map(m => `
                            <div class="patch-fomod">
                                ${showIndicators ? (m.selected ? '<span style="color: #00ff00;">✓</span>' : '<span style="color: #ff4444;">✗</span>') : '•'} 
                                <strong>${m.name}</strong>
                            </div>
                        `).join('')}
                    </div>
                `;
            }).join('');
        }
        
        function renderData(data) {
            const content = document.getElementById('content');
            
            // Update hidden count indicator
            updateHiddenCount(data);
            
            if (data.length === 0) {
                content.innerHTML = `
                    <div class="empty-state">
                        <div class="empty-state-icon">📦</div>
                        <h2>No FOMOD installations yet</h2>
                        <p>Install a mod with FOMOD installer to see it here!</p>
                    </div>
                `;
                return;
            }
            
            content.innerHTML = data
                .filter(mod => {
                    // Filter hidden mods unless showHidden is true
                    const isHidden = hiddenMods.has(mod.mod_name);
                    return showHidden || !isHidden;
                })
                .map(mod => {
                const stepGroups = {};
                mod.options.forEach(opt => {
                    if (!stepGroups[opt.step]) stepGroups[opt.step] = {};
                    if (!stepGroups[opt.step][opt.group]) stepGroups[opt.step][opt.group] = [];
                    stepGroups[opt.step][opt.group].push(opt);
                });
                
                const stepsHtml = Object.keys(stepGroups).map(step => `
                    <div class="step">
                        <div class="step-title">${step}</div>
                        ${Object.keys(stepGroups[step]).map(group => `
                            <div class="group">
                                <div class="group-title">${group}</div>
                                ${stepGroups[step][group]
                                    .filter(opt => !quickViewMode || opt.selected)
                                    .map(opt => `
                                    <div class="option ${opt.selected ? 'selected' : 'not-selected'}">
                                        <span class="option-icon">${opt.selected ? '✓' : '○'}</span>
                                        <span>${highlightText(opt.option, currentSearchTerm)}</span>
                                    </div>
                                `).join('')}
                            </div>
                        `).join('')}
                    </div>
                `).join('');
                
                // Check if this mod was previously expanded
                const isExpanded = expandedMods.has(mod.mod_name);
                const isHidden = hiddenMods.has(mod.mod_name);
                
                return `
                    <div class="mod-card ${isExpanded ? '' : 'collapsed'} ${isHidden ? 'hidden-mod' : ''}" data-mod-name="${mod.mod_name}">
                        <div class="mod-header" onclick="toggleMod(this, event)">
                            <div>
                                <div class="mod-title">${highlightText(mod.mod_name, currentSearchTerm)}</div>
                                <div class="mod-meta">
                                    Installed: ${mod.timestamp}
                                </div>
                            </div>
                            <button class="hide-btn" onclick="toggleHideMod('${mod.mod_name.replace(/'/g, "\\'")}', event)">
                                ${isHidden ? 'Unhide' : 'Hide'}
                            </button>
                            <span class="toggle-icon">▼</span>
                        </div>
                        <div class="mod-body">
                            ${stepsHtml}
                        </div>
                    </div>
                `;
            }).join('');
        }
        
        function toggleMod(header, event) {
            // Prevent event bubbling and double-firing
            if (event) {
                event.stopPropagation();
                event.preventDefault();
            }
            
            // Block auto-refresh during animation
            isAnimating = true;
            setTimeout(() => { isAnimating = false; }, 500);
            
            const card = header.parentElement;
            const modName = card.getAttribute('data-mod-name');
            
            // Smooth toggle with animation
            card.classList.toggle('collapsed');
            
            // Track expanded state
            if (card.classList.contains('collapsed')) {
                expandedMods.delete(modName);
            } else {
                expandedMods.add(modName);
            }
        }
        
        function toggleHideMod(modName, event) {
            // Prevent event bubbling
            if (event) {
                event.stopPropagation();
                event.preventDefault();
            }
            
            if (hiddenMods.has(modName)) {
                hiddenMods.delete(modName);
            } else {
                hiddenMods.add(modName);
            }
            
            saveHiddenMods(hiddenMods);
            renderData(getSortedData());
            updateStats();
        }
        
        function toggleShowHidden() {
            showHidden = !showHidden;
            const btn = document.getElementById('show-hidden-btn');
            if (btn) {
                btn.textContent = showHidden ? 'Hide Hidden Mods' : 'Show Hidden Mods';
                btn.classList.toggle('active', showHidden);
            }
            renderData(getSortedData());
            updateStats();
        }
        
        function toggleHideCrossPatch(patchName, event) {
            if (event) {
                event.stopPropagation();
                event.preventDefault();
            }
            
            if (hiddenCrossPatches.has(patchName)) {
                hiddenCrossPatches.delete(patchName);
            } else {
                hiddenCrossPatches.add(patchName);
            }
            
            saveHiddenCrossPatches(hiddenCrossPatches);
            renderCrossPatches(crossPatches);
        }
        
        function toggleShowHiddenCrossPatches(event) {
            if (event) {
                event.stopPropagation();
                event.preventDefault();
            }
            
            showHiddenCrossPatches = !showHiddenCrossPatches;
            const btn = document.getElementById('show-hidden-crosspatches-btn');
            if (btn) {
                btn.textContent = showHiddenCrossPatches ? 'Hide Hidden' : 'Show Hidden';
                btn.classList.toggle('active', showHiddenCrossPatches);
            }
            renderCrossPatches(crossPatches);
        }
        
        function updateHiddenCount(data) {
            const indicator = document.getElementById('hidden-count-indicator');
            const text = document.getElementById('hidden-count-text');
            
            if (!indicator || !text) return;
            
            const hiddenCount = data.filter(mod => hiddenMods.has(mod.mod_name)).length;
            
            if (hiddenCount > 0) {
                indicator.style.display = 'block';
                text.textContent = `${hiddenCount} mod${hiddenCount === 1 ? '' : 's'} hidden`;
            } else {
                indicator.style.display = 'none';
            }
        }
        
        function updateStats() {
            document.getElementById('totalMods').textContent = allData.length;
        }
        
        function highlightText(text, searchTerm) {
            if (!searchTerm) return text;
            
            const regex = new RegExp(`(${searchTerm.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&')})`, 'gi');
            return text.replace(regex, '<mark style="background-color: #ffd700; color: #000; padding: 2px 4px; border-radius: 3px; font-weight: bold;">$1</mark>');
        }
        
        document.getElementById('searchBox').addEventListener('input', (e) => {
            currentSearchTerm = e.target.value.toLowerCase();
            const filtered = allData.filter(mod => 
                mod.mod_name.toLowerCase().includes(currentSearchTerm) ||
                mod.options.some(opt => opt.option.toLowerCase().includes(currentSearchTerm))
            );
            renderData(getSortedData().filter(mod => filtered.includes(mod)));
        });
        
        // Load theme and data immediately
        loadTheme();
        loadData();
        
        // Auto-refresh every 3 seconds
        setInterval(loadData, 3000);
    </script>
</body>
</html>'''


def createPlugin() -> mobase.IPlugin:
    """Required function to create the plugin instance."""
    return FomodLogger()
