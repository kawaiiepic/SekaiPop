import QtQuick

Rectangle {
    id: key
    property string text: ""
    property bool selected: false
    signal clicked()
    implicitWidth: 100
    implicitHeight: 38
    radius: 4
    color: area.pressed ? "#433044" : selected ? "#302333" : area.containsMouse ? "#20232d" : "#14171e"
    border.color: selected ? "#cf8fb8" : "#3b404d"
    border.width: 1
    Text {
        anchors.centerIn: parent
        text: key.text
        color: key.enabled ? (key.selected ? "#edb3d5" : "#c5cbd6") : "#626975"
        font.family: "monospace"
        font.pixelSize: 12
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: key.clicked() }
}
