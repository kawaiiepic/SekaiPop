import QtQuick

Item {
    id: control
    property string label: ""
    property real value: 0
    property color accent: "#d592bc"
    signal moved(real value)
    implicitHeight: 54
    Text { text: control.label; color: "#a4adbd"; font.family: "monospace"; font.pixelSize: 11 }
    Text { anchors.right: parent.right; text: Math.round(control.value) + "%"; color: "#c5cbd6"; font.family: "monospace"; font.pixelSize: 11 }
    Rectangle {
        x: 0; y: 28; width: parent.width; height: 4; radius: 2; color: "#303541"
        Rectangle { width: parent.width * Math.max(0, Math.min(1, control.value / 100)); height: 4; radius: 2; color: control.accent }
        Rectangle { x: (parent.width - width) * Math.max(0, Math.min(1, control.value / 100)); y: -4; width: 12; height: 12; radius: 6; color: control.accent }
    }
    MouseArea {
        anchors.fill: parent
        anchors.topMargin: 18
        function updateValue(mouse) { control.moved(Math.round(100 * Math.max(0, Math.min(1, mouse.x / width)))) }
        onPressed: mouse => updateValue(mouse)
        onPositionChanged: mouse => { if (pressed) updateValue(mouse) }
    }
}
