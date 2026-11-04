"""Render the real cyberdeck and exercise its controls with Qt mouse events."""
import os
import sys
from pathlib import Path
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
THREE_D = '--3d' in sys.argv or '--viewport' in sys.argv
if not THREE_D: os.environ.setdefault('QT_QUICK_BACKEND', 'software')
from PySide6.QtCore import QUrl, QPoint, Qt, QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest

# Check the integration against the real source API too: the pure UI mock
# cannot catch unknown properties assigned to a Quickshell service.
import re
base = Path(__file__).resolve().parents[2]
panel = (base / 'modules/sekai/quickPanel/QuickPanel.qml').read_text()
resource = (base / 'services/ResourceSource.qml').read_text()
binding = re.search(r'ResourceSource\s*\{[^}]*id:\s*deckResources;([^}]+)', panel)[1]
for name in re.findall(r'(\w+)\s*:', binding):
    assert re.search(r'property\s+\w+\s+' + name + r'\b', resource), name + ' is not a ResourceSource property'

app = QGuiApplication([])
view = QQuickView()
folder = Path(__file__).resolve().parents[2] / 'modules/sekai/quickPanel'
qml = '''import QtQuick
import "''' + QUrl.fromLocalFile(str(folder)).toString() + '''"
CyberdeckFace {
 id: root
 property string lastRoute: ""
 property string lastSearch: ""
 property bool closed: false
 property string dismissed: ""
 onRouteRequested: route => lastRoute = route
 onSearchRequested: query => lastSearch = query
 onCloseRequested: closed = true
 onDismissRequested: key => dismissed = key
 clockText: "21:48"; dateText: "Tuesday / Nov 03"
 source: QtObject {
  property string userName: "mia"
  property string hostName: "umbriel"
  property string networkDetail: "Home network"
  property bool networkOn: true
  property bool bluetoothOn: false
  property bool notificationsOn: true
  property bool nightLightOn: false
  property real speakerVolume: 72
  property real brightness: 58
  function toggleNetwork() { networkOn = !networkOn }
  function toggleBluetooth() { bluetoothOn = !bluetoothOn }
  function toggleNotifications() { notificationsOn = !notificationsOn }
  function toggleNightLight() { nightLightOn = !nightLightOn }
  function setSpeakerVolume(v) { speakerVolume = v }
  function setBrightness(v) { brightness = v }
 }
 resources: QtObject { property real cpuPercent: 16; property real memPercent: 60; property string memUsedLabel: "4.8"; property string memTotalLabel: "8.0" }
 notifications: [{key:"n1", summary:"Discord", body:"Ready when you are."}]
}
'''
from PySide6.QtQml import QQmlComponent
if THREE_D:
    qml = qml.replace('CyberdeckFace {', 'CyberdeckViewport {' if '--viewport' in sys.argv else 'CyberdeckScene {', 1)
component = QQmlComponent(view.engine())
component.setData(qml.encode(), QUrl.fromLocalFile(str(folder / 'DeckTest.qml')))
obj = component.create()
assert obj, [e.toString() for e in component.errors()]
view.setContent(QUrl(), component, obj)
view.resize(1240 if THREE_D else 1100, 820 if THREE_D else 670)
view.show()
QTest.qWait(800 if THREE_D else 80)
scene = obj.property("sceneItem") if "--viewport" in sys.argv else obj
if THREE_D:
    assert scene and scene.property("modelReady"), scene.property("modelError") if scene else "scene failed to load"
ui = scene.property("faceItem") if THREE_D else obj
def descendants(item):
    for child in item.childItems():
        yield child
        yield from descendants(child)
def button(text):
    return next(x for x in descendants(ui) if x.property('text') == text and x.metaObject().indexOfSignal('clicked()') >= 0 and x.isVisible())
def click(text):
    b = button(text)
    if THREE_D:
        local = b.mapToItem(ui, b.boundingRect().center())
        projected = scene.screenPoint(local.x(), local.y())
        point = QPoint(round(projected.x()), round(projected.y()))
    else:
        point = b.mapToScene(b.boundingRect().center()).toPoint()
    QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, point)
    app.processEvents()
    QTest.qWait(30)
click('Bluetooth')
assert obj.property('source').property('bluetoothOn') is True
click('Quiet')
assert obj.property('source').property('notificationsOn') is False
click('Night light')
assert obj.property('source').property('nightLightOn') is True
# Slider drag must use the same projected coordinates, not its flat bounding box.
slider = next(x for x in descendants(ui) if x.property('label') == 'VOLUME')
def slider_point(fraction):
    local = slider.mapToItem(ui, slider.boundingRect().topLeft())
    x, y = local.x() + slider.width() * fraction, local.y() + 30
    if THREE_D:
        point = scene.screenPoint(x, y)
        return QPoint(round(point.x()), round(point.y()))
    return QPoint(round(x), round(y))
QTest.mousePress(view, Qt.LeftButton, Qt.NoModifier, slider_point(.25))
QTest.mouseMove(view, slider_point(.8), 30)
QTest.mouseRelease(view, Qt.LeftButton, Qt.NoModifier, slider_point(.8))
assert abs(obj.property('source').property('speakerVolume') - 80) <= 2
click('APPS')
assert obj.property('lastRoute') == 'apps'
click('Q'); click('W'); click('⌫'); click('ENTER')
assert obj.property('lastSearch') == 'q'
click('NOTIFICATIONS')
assert ui.property('notificationPage') is True
click('DISMISS')
assert obj.property('dismissed') == 'n1'
click('DASHBOARD')
assert ui.property('notificationPage') is False
image = view.grabWindow()
assert not image.isNull()
image.save('/tmp/sekaipop-cyberdeck3d.png' if THREE_D else '/tmp/sekaipop-cyberdeck.png')
if '--viewport' in sys.argv:
    obj.setProperty('active', False)
    QTest.qWait(60)
    assert obj.property('sceneItem') is None, 'closed deck releases its 3D scene'
    obj.setProperty('active', True)
    QTest.qWait(350)
    scene = obj.property('sceneItem')
    assert scene and scene.property('modelReady'), 'model reloads on reopen'
    ui = scene.property('faceItem')
    click('Bluetooth')
    assert obj.property('source').property('bluetoothOn') is False
click('CLOSE ×')
assert obj.property('closed') is True
print('Cyberdeck: rendered, real toggle clicks, routing, keyboard search, notifications and close passed')
view.close()
