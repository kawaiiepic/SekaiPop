import QtQuick

// Keep Quick 3D optional for Default and older installations. The scene is
// loaded by URL, so a missing QML module cannot make QuickPanel unavailable.
Item {
    id: root
    readonly property Item sceneItem: model.item
    property bool active: true
    required property var source
    property var media: null
    property var resources: null
    property var notifications: []
    property string clockText: "00:00"
    property string dateText: ""
    signal routeRequested(string route)
    signal searchRequested(string query)
    signal closeRequested()
    signal dismissRequested(string key)
    width: 1240; height: 820

    function bindFace(item) {
        item.source = Qt.binding(() => root.source)
        item.media = Qt.binding(() => root.media)
        item.resources = Qt.binding(() => root.resources)
        item.notifications = Qt.binding(() => root.notifications)
        item.clockText = Qt.binding(() => root.clockText)
        item.dateText = Qt.binding(() => root.dateText)
    }
    Loader {
        id: model
        anchors.fill: parent
        active: root.active
        function loadScene() {
            if (active && source.toString() === "")
                setSource("CyberdeckScene.qml", { source: Qt.binding(() => root.source) })
        }
        Component.onCompleted: loadScene()
        onActiveChanged: loadScene()
        onLoaded: root.bindFace(item)
    }
    Loader {
        id: fallback
        active: root.active && model.status === Loader.Error
        x: 70; y: 65
        sourceComponent: Component { CyberdeckFace { source: root.source } }
        onLoaded: root.bindFace(item)
    }
    Connections {
        target: model.item || fallback.item
        function onRouteRequested(route) { root.routeRequested(route) }
        function onSearchRequested(query) { root.searchRequested(query) }
        function onCloseRequested() { root.closeRequested() }
        function onDismissRequested(key) { root.dismissRequested(key) }
    }
    Text {
        visible: model.status === Loader.Error
        anchors.horizontalCenter: parent.horizontalCenter
        y: 26
        text: "3D cyberdeck requires Qt Quick 3D and its AssetUtils QML module"
        color: "#d397bd"; font.family: "monospace"; font.pixelSize: 13
    }
}
