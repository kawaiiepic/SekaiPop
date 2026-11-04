"""Render the real cyberdeck and exercise its controls with Qt mouse events."""
import os
from pathlib import Path
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
from PySide6.QtCore import QUrl, QPoint, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest

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
component = QQmlComponent(view.engine())
component.setData(qml.encode(), QUrl.fromLocalFile(str(folder / 'DeckTest.qml')))
obj = component.create()
assert obj, [e.toString() for e in component.errors()]
view.setContent(QUrl(), component, obj)
view.resize(1100, 670)
view.show()
QTest.qWait(80)
def descendants(item):
    for child in item.childItems():
        yield child
        yield from descendants(child)
def button(text):
    return next(x for x in descendants(obj) if x.property('text') == text and x.metaObject().indexOfSignal('clicked()') >= 0 and x.isVisible())
def click(text):
    b = button(text)
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
click('APPS')
assert obj.property('lastRoute') == 'apps'
click('Q'); click('W'); click('⌫'); click('ENTER')
assert obj.property('lastSearch') == 'q'
click('NOTIFICATIONS')
assert obj.property('notificationPage') is True
click('DISMISS')
assert obj.property('dismissed') == 'n1'
click('DASHBOARD')
assert obj.property('notificationPage') is False
image = view.grabWindow()
assert not image.isNull()
image.save('/tmp/sekaipop-cyberdeck.png')
click('CLOSE ×')
assert obj.property('closed') is True
print('Cyberdeck: rendered, real toggle clicks, routing, keyboard search, notifications and close passed')
view.close()
