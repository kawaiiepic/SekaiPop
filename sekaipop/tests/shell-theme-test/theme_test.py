"""Live QML binding checks; run with PySide6 and QT_QPA_PLATFORM=offscreen."""
import os
from pathlib import Path
import re
import tempfile
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine

base = Path(__file__).resolve().parents[2]
app = QGuiApplication([])
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    services = root / 'qs/services'
    common = root / 'qs/modules/common'
    services.mkdir(parents=True)
    common.mkdir(parents=True)
    services.joinpath('qmldir').write_text('module qs.services\nsingleton SettingsService 1.0 SettingsService.qml\nsingleton ThemeService 1.0 ThemeService.qml\nsingleton GameModeService 1.0 GameModeService.qml\n')
    services.joinpath('SettingsService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property string skin: "default"
 function get(key) { return key === "appearance.shellTheme" ? skin : "outline" }
 function flag(key) { return false }
}
''')
    services.joinpath('GameModeService.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool enabled: false }')
    source = (base / 'services/ThemeService.qml').read_text()
    palette = re.search(r'id: "vs".*?c: (\{[^\n]+?\}) \}', source)[1]
    services.joinpath('ThemeService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property bool dark: false
 property bool darker: false
 property string mode: "light"
 property var palette: (''' + palette + ''')
 property var baseGroups: [{c: palette}]
}
''')
    common.joinpath('qmldir').write_text('module qs.modules.common\nsingleton ShellStyle 1.0 ShellStyle.qml\nThemeSet 1.0 ThemeSet.qml\nsingleton ScrapbookTheme 1.0 ScrapbookTheme.qml\n')
    for name in ['ShellStyle.qml', 'ThemeSet.qml', 'ScrapbookTheme.qml']:
        common.joinpath(name).write_text((base / 'modules/common' / name).read_text())
    engine = QQmlEngine()
    engine.addImportPath(str(root))
    component = QQmlComponent(engine)
    component.setData(b'''import QtQuick
import qs.services
import qs.modules.common
QtObject {
 property ThemeSet theme: ThemeSet {}
 property ThemeSet screenTheme: ThemeSet { pal: Object.assign({}, ThemeService.palette, {A: "#ff0000"}) }
 property string accent: theme.accentCyan.toString()
 property string screenAccent: screenTheme.accentCyan.toString()
 property string paper: ScrapbookTheme.page.toString()
 property string font: theme.fontFamily
 property bool dark: theme.dark
 property real radius: theme.radiusOuter
 function select(value) { SettingsService.skin = value }
}
''', QUrl())
    obj = component.create()
    assert obj is not None, [e.toString() for e in component.errors()]
    def snapshot():
        return tuple(obj.property(k) for k in ['accent','screenAccent','paper','font','dark','radius'])
    original = snapshot()
    assert original[0] != original[1], 'per-monitor palettes remain independent'
    obj.select('cyberpunk')
    app.processEvents()
    cyber = snapshot()
    assert cyber[:2] == ('#d397bd', '#d397bd'), cyber
    assert cyber[2:] == ('#19202e', 'monospace', True, 5.0), cyber
    obj.select('default')
    app.processEvents()
    assert snapshot() == original, 'disabling restores all original bindings'
    obj.select('unknown')
    app.processEvents()
    assert snapshot() == original, 'unknown skin falls back to Default'
    print('Shell theme: live palette, per-monitor override, paper, font, mode, geometry and disable passed')
